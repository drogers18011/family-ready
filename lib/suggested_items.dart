import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'amazon_affiliate_config.dart';
import 'field_surfaces.dart';
import 'personal_packlist_repository.dart';
import 'suggested_catalog.dart';

class SuggestedItemsPanel extends StatefulWidget {
  const SuggestedItemsPanel({super.key, required this.onOpenPack});

  final VoidCallback onOpenPack;

  @override
  State<SuggestedItemsPanel> createState() => _SuggestedItemsPanelState();
}

class _SuggestedItemsPanelState extends State<SuggestedItemsPanel> {
  final _search = TextEditingController();
  PersonalPacklistSnapshot? _snapshot;
  bool _loading = true;
  bool _working = false;
  String _category = 'All';
  String? _error;

  bool get _blocked =>
      _loading || _working || _snapshot == null || _snapshot?.loadError != null;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  TextTheme get _type => Theme.of(context).textTheme;
  ShoppingSurface get _surface {
    if (kIsWeb) return ShoppingSurface.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ShoppingSurface.ios,
      TargetPlatform.android => ShoppingSurface.android,
      _ => ShoppingSurface.other,
    };
  }

  AmazonShoppingLink? _link(SuggestedItem item) => amazonLinkSettings.linkFor(
    item,
    surface: _surface,
    webOrigin: kIsWeb ? Uri.base.origin : null,
  );

  @override
  void initState() {
    super.initState();
    personalPacklistStore.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    personalPacklistStore.removeListener(_onChanged);
    _search.dispose();
    super.dispose();
  }

  void _onChanged(PersonalPacklistSnapshot value) {
    if (mounted) setState(() => _snapshot = value);
  }

  Future<void> _load({bool retry = false}) async {
    if (_working) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await personalPacklistStore.load(retry: retry);
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your pack could not be loaded.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  PersonalPackItem? _existing(SuggestedItem suggestion) {
    for (final item in _snapshot?.document.items ?? <PersonalPackItem>[]) {
      if (item.sourceSuggestionId == suggestion.id) return item;
    }
    return null;
  }

  Future<void> _retrySave() async {
    if (_blocked) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final snapshot = await personalPacklistStore.retrySave();
      if (mounted) setState(() => _snapshot = snapshot);
      if (!snapshot.dirty && snapshot.loadError == null) {
        _message('Your pack is saved.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Saving could not be retried.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _add(
    SuggestedItem suggestion, {
    bool confirmedOwned = false,
    bool shop = false,
  }) async {
    if (_blocked) return;
    final link = shop ? _link(suggestion) : null;
    if (shop && link == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final result = await personalPacklistStore.addSuggestedItem(
        suggestionId: suggestion.id,
        name: suggestion.name,
        quantity: '1',
        notes: suggestion.note,
        confirmedOwned: confirmedOwned,
      );
      if (!mounted) return;
      setState(() => _snapshot = result.snapshot);
      if (result.snapshot.dirty || result.snapshot.saveError != null) {
        _message('The change is not saved yet. Retry saving or copy My pack.');
        return;
      }
      if (shop && link != null) {
        // Save first. A separate explicit button supplies a fresh browser user
        // gesture after storage finishes, and opens outside Black Box.
        await _offerAmazon(suggestion, result, link);
      } else {
        _message(
          confirmedOwned
              ? '${result.item.name} marked owned in My pack.'
              : result.added
              ? '${result.item.name} added to My pack; not marked owned.'
              : '${result.item.name} is already in My pack.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The item could not be added. Open My pack '
              'to review its saved data, or retry loading.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _offerAmazon(
    SuggestedItem suggestion,
    SuggestedPackResult result,
    AmazonShoppingLink link,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('Saved to My pack'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.item.name, style: _type.titleMedium),
            const SizedBox(height: 12),
            Text(
              result.added
                  ? 'Added as not marked owned. Mark it owned when you have it '
                        'available, then mark it packed when it is in your kit.'
                  : 'This item is already in My pack. Your item details and '
                        'existing Owned and Packed marks have been kept.',
            ),
            const SizedBox(height: 12),
            Text(
              suggestion.isSearch
                  ? 'The next button opens Amazon.com search results online '
                        'for ${suggestion.example.toLowerCase()}.'
                  : 'The next button opens ${suggestion.example} on '
                        'Amazon.com online. Check the product details there.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Black Box cannot confirm an Amazon purchase. '
              'You can mark an item owned wherever you buy it.',
            ),
            if (link.isAffiliate) ...[
              const SizedBox(height: 12),
              const Text(
                'Paid link. Black Box may earn a commission '
                'from qualifying purchases.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Stay here'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(dialogContext);
            _openAmazon(link);
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(
            suggestion.isSearch ? 'Open Amazon search' : 'Open Amazon',
          ),
        ),
      ],
    ),
  );

  Future<void> _openAmazon(AmazonShoppingLink link) async {
    try {
      // Do not await a connectivity check or storage read before launchUrl.
      // This method is called directly from the explicit dialog button.
      final opened = await launchUrl(
        link.uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        setState(
          () => _error =
              'Amazon could not open. Your pack is saved. '
              'Check your connection and browser settings, then try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Amazon could not open. Your pack is saved. '
              'Check your connection and try again.',
        );
      }
    }
  }

  Widget _notice(String message, {List<Widget> actions = const []}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(liveRegion: true, child: Text(message)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      );

  Widget _card(SuggestedItem suggestion) {
    final existing = _existing(suggestion);
    final link = _link(suggestion);
    final status = existing == null
        ? 'Not in My pack'
        : existing.packed
        ? 'Owned · packed'
        : existing.owned
        ? 'Owned · not packed'
        : 'In My pack · not marked owned';
    return FieldPanel(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.category.toUpperCase(),
              style: _type.labelMedium?.copyWith(color: _colors.primary),
            ),
            const SizedBox(height: 10),
            Text(suggestion.name, style: _type.titleLarge),
            const SizedBox(height: 10),
            Text(suggestion.note, style: _type.bodyMedium),
            const SizedBox(height: 12),
            Text(
              '${suggestion.isSearch ? 'Search' : 'Example'}: '
              '${suggestion.example}',
              style: _type.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              _loading
                  ? 'Loading My pack status…'
                  : _snapshot?.loadError != null
                  ? 'My pack status unavailable'
                  : '${_snapshot?.dirty == true ? 'Unsaved · ' : ''}$status',
              style: _type.labelMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _blocked || existing != null
                      ? null
                      : () => _add(suggestion),
                  icon: Icon(existing == null ? Icons.add : Icons.check),
                  label: Text(
                    existing == null ? 'Add to My pack' : 'In My pack',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _blocked || existing?.owned == true
                      ? null
                      : () => _add(suggestion, confirmedOwned: true),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    existing?.owned == true ? 'Owned' : 'I have this',
                  ),
                ),
              ],
            ),
            if (link != null) ...[
              const SizedBox(height: 12),
              if (link.isAffiliate) ...[
                const Text(
                  'Paid link. Black Box may earn a commission '
                  'from qualifying purchases.',
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _blocked ? null : () => _add(suggestion, shop: true),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  existing == null ? 'Add & shop on Amazon' : 'Shop on Amazon',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                suggestion.isSearch
                    ? 'Opens search results · internet required'
                    : 'Opens example product · internet required',
                style: _type.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = suggestedItems
        .where(
          (item) =>
              (_category == 'All' || item.category == _category) &&
              '${item.name} ${item.category} ${item.example} ${item.note}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final hasAffiliate = suggestedItems.any(
      (item) => _link(item)?.isAffiliate == true,
    );
    final snapshot = _snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldSectionHeading(
          title: 'Suggested items',
          eyebrow: 'Supply catalog',
          subtitle:
              'Build your kit a little at a time. Save an item to My pack, '
              'mark it owned when you have it, then mark it packed.',
        ),
        const SizedBox(height: 10),
        Text(
          'Six starter ideas, not a complete emergency kit. Choose what '
          'fits your household. Items from any store work with My pack.',
          style: _type.bodySmall,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _working ? null : widget.onOpenPack,
            icon: const Icon(Icons.checklist_rounded),
            label: const Text('Open My pack'),
          ),
        ),
        const SizedBox(height: 16),
        if (hasAffiliate)
          _notice('As an Amazon Associate I earn from qualifying purchases.'),
        if (!amazonLinkSettings.canShop(_surface))
          _notice(
            'Amazon shopping links are not enabled in this build. '
            'You can still add items and mark anything you already own.',
          ),
        if (_loading || _working) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(_loading ? 'Loading My pack…' : 'Saving My pack…'),
          ),
          const SizedBox(height: 16),
        ],
        if (_error != null)
          _notice(
            _error!,
            actions: [
              OutlinedButton(
                onPressed: _loading || _working
                    ? null
                    : () => _load(retry: true),
                child: const Text('Retry loading'),
              ),
            ],
          ),
        if (snapshot?.loadError != null)
          _notice(
            snapshot!.loadError!,
            actions: [
              OutlinedButton(
                onPressed: _loading || _working
                    ? null
                    : () => _load(retry: true),
                child: const Text('Retry loading'),
              ),
              TextButton(
                onPressed: widget.onOpenPack,
                child: const Text('Open My pack'),
              ),
            ],
          ),
        if (snapshot?.saveError != null)
          _notice(
            snapshot!.saveError!,
            actions: [
              OutlinedButton(
                onPressed: _blocked ? null : _retrySave,
                child: const Text('Retry saving'),
              ),
              TextButton(
                onPressed: _working ? null : widget.onOpenPack,
                child: const Text('Open My pack to copy'),
              ),
            ],
          ),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Find a suggested item',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in [
              'All',
              ...suggestedItems.map((item) => item.category).toSet(),
            ])
              ChoiceChip(
                label: Text(category),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          const Text(
            'No suggested items match. Try another search or category.',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Stack at phone widths or with enlarged text. No fixed card height.
            final columns =
                constraints.maxWidth >= 780 &&
                    MediaQuery.textScalerOf(context).scale(16) <= 20
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in visible)
                  SizedBox(width: width, child: _card(item)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Product details, price, availability, and suitability must be '
          'checked on Amazon. Opening a link never marks an item owned '
          'or packed.',
          style: _type.bodySmall,
        ),
      ],
    );
  }
}
