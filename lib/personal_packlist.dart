import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'personal_packlist_models.dart';

/// The shared store outlives a tab's widget. Pending writes finish before a
/// returning tab loads; failed drafts survive tab changes within this app.
final _personalPreferences = SharedPreferencesAsync();
final _personalStore = PersonalPacklistStore(
  read: _personalPreferences.getString,
  write: _personalPreferences.setString,
);
int _personalIdCounter = 0;

class PersonalPacklistPanel extends StatefulWidget {
  const PersonalPacklistPanel({super.key});

  @override
  State<PersonalPacklistPanel> createState() => _PersonalPacklistPanelState();
}

class _PersonalPacklistPanelState extends State<PersonalPacklistPanel> {
  PersonalPacklistSnapshot? _snapshot;
  bool _loading = true;
  bool _saving = false;
  String _filter = 'All';
  String? _operationError;

  bool get _blocked => _loading || _saving || _snapshot?.loadError != null;
  String get _location => kIsWeb ? 'this browser' : 'this device';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool retry = false}) async {
    if (_saving) return;
    setState(() {
      _loading = true;
      _operationError = null;
    });
    try {
      final loaded = await _personalStore.load(retry: retry);
      if (mounted) setState(() => _snapshot = loaded);
    } catch (_) {
      if (mounted) {
        setState(
          () => _operationError = 'The personal checklist could not load.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(PersonalPacklist next) async {
    if (_blocked || _snapshot == null) return;
    setState(() {
      _saving = true;
      _operationError = null;
    });
    try {
      final saved = await _personalStore.save(next);
      if (mounted) setState(() => _snapshot = saved);
    } catch (_) {
      if (mounted) {
        setState(() {
          _operationError =
              'The checklist could not be changed. Retry loading it.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retrySave() async {
    if (_blocked) return;
    setState(() => _saving = true);
    try {
      final saved = await _personalStore.retrySave();
      if (mounted) setState(() => _snapshot = saved);
    } catch (_) {
      if (mounted) {
        setState(() => _operationError = 'Saving could not be retried.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy(String text, String description) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$description copied. Paste it into a safe place.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text('Copy $description'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automatic copying was unavailable. Select and copy the text below.',
                ),
                const SizedBox(height: 16),
                SelectableText(text),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _edit([PersonalPackItem? existing]) async {
    if (_blocked || _snapshot == null) return;
    final document = _snapshot!.document;
    if (existing == null && document.items.length >= maxPersonalPackItems)
      return;
    final edited = await _editPersonalItem(
      context,
      id:
          existing?.id ??
          'pack_${DateTime.now().microsecondsSinceEpoch}_${_personalIdCounter++}',
      existing: existing,
    );
    if (!mounted || edited == null || _blocked) return;
    final current = _snapshot!.document;
    await _save(
      current.withItems([
        for (final item in current.items)
          if (item.id == edited.id) edited else item,
        if (existing == null) edited,
      ]),
    );
  }

  Future<void> _remove(PersonalPackItem item) async {
    if (_blocked || _snapshot == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Remove personal item?'),
        content: Text('Remove "${item.name}" from your personal packing list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep item'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || remove != true || _blocked) return;
    final current = _snapshot!.document;
    await _save(
      current.withItems(current.items.where((entry) => entry.id != item.id)),
    );
  }

  Future<void> _setPacked(PersonalPackItem item, bool packed) async {
    if (_blocked || _snapshot == null) return;
    final current = _snapshot!.document;
    await _save(
      current.withItems([
        for (final entry in current.items)
          if (entry.id == item.id) entry.copyWith(packed: packed) else entry,
      ]),
    );
  }

  Widget _notice(String text, {List<Widget> actions = const []}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _item(PersonalPackItem item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Semantics(
                label: '${item.name}, packed',
                child: Checkbox(
                  value: item.packed,
                  onChanged: _blocked
                      ? null
                      : (value) => _setPacked(item, value ?? false),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.titleMedium),
                    if (item.quantity.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text('Quantity: ${item.quantity}'),
                    ],
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(item.notes, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.packed ? 'Packed' : 'To pack',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: item.packed
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: PopupMenuButton<String>(
                enabled: !_blocked,
                tooltip: 'Actions for ${item.name}',
                onSelected: (action) {
                  if (action == 'edit') _edit(item);
                  if (action == 'remove') _remove(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit item')),
                  PopupMenuItem(value: 'remove', child: Text('Remove item')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final snapshot = _snapshot;
    final document = snapshot?.document;
    final items =
        document?.items.where((item) {
          if (_filter == 'To pack') return !item.packed;
          if (_filter == 'Packed') return item.packed;
          return true;
        }).toList() ??
        <PersonalPackItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('My packing list', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Your own checklist, free to use. These items and check marks are '
          'kept on $_location, separate from the group plan.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        if (_loading || _saving) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _loading ? 'Loading your checklist…' : 'Saving your checklist…',
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_operationError != null)
          _notice(
            _operationError!,
            actions: [
              OutlinedButton(
                onPressed: _saving || _loading
                    ? null
                    : () => _load(retry: true),
                child: const Text('Retry loading'),
              ),
            ],
          ),
        if (snapshot != null && snapshot.loadError != null)
          _notice(
            snapshot.loadError!,
            actions: [
              OutlinedButton(
                onPressed: _loading ? null : () => _load(retry: true),
                child: const Text('Retry loading'),
              ),
              if (snapshot.rawStored != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      _copy(snapshot.rawStored!, 'Saved checklist data'),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy saved data'),
                ),
            ],
          ),
        if (snapshot != null && snapshot.saveError != null)
          _notice(
            snapshot.saveError!,
            actions: [
              OutlinedButton(
                onPressed: _blocked ? null : _retrySave,
                child: const Text('Retry saving'),
              ),
            ],
          ),
        if (document != null &&
            snapshot != null &&
            snapshot.loadError == null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              '${document.packedCount} of ${document.items.length} items packed',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.dirty
                ? 'Changes not saved'
                : document.savedAt == null
                ? 'Add your first personal item.'
                : 'Saved on $_location',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed:
                    _blocked || document.items.length >= maxPersonalPackItems
                    ? null
                    : () => _edit(),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.add),
                label: const Text('Add personal item'),
              ),
              OutlinedButton.icon(
                onPressed: document.items.isEmpty
                    ? null
                    : () => _copy(
                        document.readableText(unsavedChanges: snapshot.dirty),
                        'Packing list',
                      ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy list text'),
              ),
            ],
          ),
          if (document.items.length >= maxPersonalPackItems) ...[
            const SizedBox(height: 10),
            const Text(
              'Your personal checklist has reached its 500-item limit.',
            ),
          ],
          const SizedBox(height: 18),
          if (document.items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in const ['All', 'To pack', 'Packed'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Text(
                document.items.isEmpty
                    ? 'Add the things you personally need to take. '
                          'You can change this list without editing the group plan.'
                    : 'No items match this filter.',
              ),
            )
          else
            ...items.map(_item),
          const SizedBox(height: 18),
          Text(
            'Group plan backups do not include this personal list. '
            'Use Copy list text to keep a separate readable copy. '
            'Removing the app or clearing its storage can remove the saved list.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}

Future<PersonalPackItem?> _editPersonalItem(
  BuildContext context, {
  required String id,
  PersonalPackItem? existing,
}) {
  final form = GlobalKey<FormState>();
  var name = existing?.name ?? '';
  var quantity = existing?.quantity ?? '';
  var notes = existing?.notes ?? '';
  return showDialog<PersonalPackItem>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(
        existing == null ? 'Add personal item' : 'Edit personal item',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                autofocus: true,
                maxLength: 140,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Item name'),
                onChanged: (value) => name = value,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty)
                    return 'Enter an item name.';
                  if (value!.length > 140) return 'Shorten this item name.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: quantity,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'For example, 2 pairs or 1 bottle',
                ),
                onChanged: (value) => quantity = value,
                validator: (value) =>
                    (value ?? '').length > 80 ? 'Shorten this quantity.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: notes,
                maxLength: 1200,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => notes = value,
                validator: (value) =>
                    (value ?? '').length > 1200 ? 'Shorten these notes.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(
              dialogContext,
              PersonalPackItem(
                id: id,
                name: name.trim(),
                quantity: quantity.trim(),
                notes: notes.trim(),
                packed: existing?.packed ?? false,
              ),
            );
          },
          child: const Text('Save item'),
        ),
      ],
    ),
  );
}
