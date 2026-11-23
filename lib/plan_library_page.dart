import 'package:material_ui/material_ui.dart';

import 'field_surfaces.dart';
import 'plan_library_store.dart';

enum PlanLibraryActionKind {
  create,
  duplicate,
  select,
  archive,
  unarchive,
  importBackup,
}

/// A request for the owning screen to execute after this page closes.
/// The library page itself never changes plans or stored data.
class PlanLibraryAction {
  const PlanLibraryAction({required this.kind, this.planId, this.name});

  final PlanLibraryActionKind kind;
  final String? planId;
  final String? name;
}

class PlanLibraryPage extends StatefulWidget {
  const PlanLibraryPage({
    super.key,
    required this.items,
    required this.activeId,
  });

  final List<PlanLibraryItem> items;
  final String activeId;

  @override
  State<PlanLibraryPage> createState() => _PlanLibraryPageState();
}

class _PlanLibraryPageState extends State<PlanLibraryPage> {
  final _search = TextEditingController();
  bool _archived = false;
  bool _dialogOpen = false;
  bool _leaving = false;

  bool get _blocked => _dialogOpen || _leaving;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _finish([PlanLibraryAction? action]) {
    if (!mounted || _blocked) return;
    _leaving = true;
    Navigator.of(context).pop<PlanLibraryAction>(action);
  }

  Future<void> _namePlan([PlanLibraryItem? source]) async {
    if (_blocked) return;
    setState(() => _dialogOpen = true);
    String? name;
    try {
      name = await showDialog<String>(
        context: context,
        builder: (_) => _PlanNameDialog(source: source),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (!mounted || name == null) return;
    _finish(
      PlanLibraryAction(
        kind: source == null
            ? PlanLibraryActionKind.create
            : PlanLibraryActionKind.duplicate,
        planId: source?.entry.id,
        name: name,
      ),
    );
  }

  Future<void> _archivePlan(PlanLibraryItem item) async {
    if (_blocked || item.entry.id == widget.activeId) return;
    setState(() => _dialogOpen = true);
    bool confirmed = false;
    try {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: const Text('Archive this plan?'),
              content: Text(
                'Move “${item.displayName}” into Archived? '
                'Its saved data stays on this device. '
                'You can restore it to active plans later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Archive plan'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (!mounted || !confirmed) return;
    _finish(
      PlanLibraryAction(
        kind: PlanLibraryActionKind.archive,
        planId: item.entry.id,
      ),
    );
  }

  List<PlanLibraryItem> _visibleItems() {
    final words = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    final result = widget.items.where((item) {
      final name = '${item.displayName} ${item.entry.name}'.toLowerCase();
      return item.entry.archived == _archived && words.every(name.contains);
    }).toList();
    final current = result.indexWhere(
      (item) => item.entry.id == widget.activeId,
    );
    if (current > 0) result.insert(0, result.removeAt(current));
    return result;
  }

  Widget _planCard(PlanLibraryItem item) {
    final theme = Theme.of(context);
    final plan = item.plan;
    final current = item.entry.id == widget.activeId;
    final available = plan != null;
    final places = plan == null
        ? 0
        : (plan.primary.isSet ? 1 : 0) + (plan.backup.isSet ? 1 : 0);
    return FieldPanel(
      key: ValueKey(item.entry.id),
      margin: const EdgeInsets.only(bottom: 16),
      prominent: current,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current || item.entry.archived || item.isSample) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (current)
                  const Chip(
                    avatar: Icon(Icons.check_circle_outline, size: 18),
                    label: Text('Current plan'),
                  ),
                if (item.entry.archived)
                  const Chip(
                    avatar: Icon(Icons.archive_outlined, size: 18),
                    label: Text('Archived'),
                  ),
                if (item.isSample) const Chip(label: Text('Example plan')),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Semantics(
            header: true,
            child: Text(item.displayName, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 10),
          if (plan != null) ...[
            Text(
              '${_count(plan.members.length, 'person', 'people')} · '
              '${_count(places, 'meeting place', 'meeting places')} · '
              '${_count(plan.supplies.length, 'supply', 'supplies')}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              plan.savedAt == null
                  ? 'No successful save recorded yet.'
                  : 'Saved locally: ${_dateTime(plan.savedAt!)}',
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            Text(
              'Plan unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.error ?? 'The saved contents could not be read.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This entry has been kept. Opening or duplicating it is '
              'unavailable. Import a backup as a separate plan if you have one.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (item.isSample) ...[
            const SizedBox(height: 8),
            Text(
              'Review the example people and supplies before using this plan.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (available && !item.entry.archived)
                FilledButton.icon(
                  onPressed: _blocked
                      ? null
                      : () => current
                            ? _finish()
                            : _finish(
                                PlanLibraryAction(
                                  kind: PlanLibraryActionKind.select,
                                  planId: item.entry.id,
                                ),
                              ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(current ? 'Return to plan' : 'Open plan'),
                ),
              if (available)
                OutlinedButton.icon(
                  onPressed: _blocked ? null : () => _namePlan(item),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicate'),
                ),
              if (item.entry.archived)
                OutlinedButton.icon(
                  onPressed: _blocked
                      ? null
                      : () => _finish(
                          PlanLibraryAction(
                            kind: PlanLibraryActionKind.unarchive,
                            planId: item.entry.id,
                          ),
                        ),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restore to active plans'),
                )
              else if (!current)
                OutlinedButton.icon(
                  onPressed: _blocked ? null : () => _archivePlan(item),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive'),
                ),
            ],
          ),
          if (current) ...[
            const SizedBox(height: 12),
            Text(
              'Switch to another plan before archiving this one.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visibleItems();
    final activeCount = widget.items
        .where((item) => !item.entry.archived)
        .length;
    final archivedCount = widget.items.length - activeCount;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _toolbarHeight(context),
        title: const Text(
          'Your plans',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _blocked ? null : () => _finish(),
          tooltip: 'Back to Black Box',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: FieldBackdrop(
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldSectionHeading(
                      eyebrow: 'Plan library',
                      title: 'A plan for each group',
                      subtitle:
                          'Keep family, friends, and travel plans organized '
                          'without mixing their details.',
                    ),
                    const SizedBox(height: 20),
                    FieldPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved locally',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Each plan has its own people, meeting places, '
                            'instructions, and shared kit. My pack and '
                            'Offline guides stay available across all plans.',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'These plans stay on this device. Online '
                            'invitations and syncing are not available yet.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _blocked ? null : () => _namePlan(),
                          icon: const Icon(Icons.add),
                          label: const Text('New plan'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _blocked
                              ? null
                              : () => _finish(
                                  const PlanLibraryAction(
                                    kind: PlanLibraryActionKind.importBackup,
                                  ),
                                ),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Import backup'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Import adds a separate plan after you review it. '
                      'A group backup contains one plan, not the entire library '
                      'or your personal pack and guide files.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Search plans',
                        hintText: 'Search by plan name',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(_search.clear),
                                tooltip: 'Clear plan search',
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          label: Text('Active ($activeCount)'),
                          selected: !_archived,
                          onSelected: _blocked
                              ? null
                              : (_) => setState(() => _archived = false),
                        ),
                        ChoiceChip(
                          label: Text('Archived ($archivedCount)'),
                          selected: _archived,
                          onSelected: _blocked
                              ? null
                              : (_) => setState(() => _archived = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_count(visible.length, 'plan', 'plans')} shown',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      FieldPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _search.text.trim().isNotEmpty
                                  ? 'No plans match that search in '
                                        '${_archived ? 'Archived' : 'Active'}.'
                                  : _archived
                                  ? 'No archived plans. You can move older '
                                        'plans here and bring them back later.'
                                  : 'No active plans to show. Create a new '
                                        'plan or restore one from Archived.',
                            ),
                            if (_search.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => setState(_search.clear),
                                child: const Text('Clear search'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    for (final item in visible) _planCard(item),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanNameDialog extends StatefulWidget {
  const _PlanNameDialog({this.source});

  final PlanLibraryItem? source;

  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final sourceName = widget.source?.displayName ?? '';
    _name = TextEditingController(
      text: sourceName.isEmpty
          ? ''
          : sourceName.length <= 73
          ? '$sourceName — copy'
          : sourceName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_leaving || !(_form.currentState?.validate() ?? false)) return;
    _leaving = true;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final duplicate = widget.source != null;
    return AlertDialog(
      scrollable: true,
      title: Text(duplicate ? 'Duplicate plan' : 'Create a plan'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              duplicate
                  ? 'Copy the people, meeting places, instructions, and '
                        'supplies from “${widget.source!.displayName}”. '
                        'Shared-kit Packed checks start clear in the copy. '
                        'The original plan stays unchanged.'
                  : 'Start with You, empty meeting places, and an empty '
                        'shared kit. Add the people and supplies for this plan.',
            ),
            const SizedBox(height: 12),
            Text(
              'Your personal pack and saved guides stay available across '
              'plans and are not copied.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Plan name',
                hintText: 'For example, Family at home',
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Enter a name for this plan.';
                if (name.length > 80) return 'Use 80 characters or fewer.';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_leaving) return;
            _leaving = true;
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(duplicate ? 'Create copy' : 'Create plan'),
        ),
      ],
    );
  }
}

String _count(int value, String singular, String plural) =>
    '$value ${value == 1 ? singular : plural}';

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

double _toolbarHeight(BuildContext context) {
  final title = Theme.of(context).textTheme.titleLarge;
  final height =
      MediaQuery.textScalerOf(context).scale(title?.fontSize ?? 22) *
          (title?.height ?? 1.2) +
      16;
  return height > 56 ? height : 56;
}
