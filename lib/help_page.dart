import 'package:material_ui/material_ui.dart';

import 'field_surfaces.dart';
import 'help_content.dart';

/// Bundled app instructions. Opening a topic or reading the tour never edits
/// the plan, inventory, guides, permissions, or any readiness state.
class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key, this.initialTopicId});

  final String? initialTopicId;

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _search = TextEditingController();
  String? _expandedId;
  bool _tourOpen = false;
  bool _leaving = false;

  bool get _blocked => _tourOpen || _leaving;

  @override
  void initState() {
    super.initState();
    _expandedId = widget.initialTopicId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _finish([HelpDestination? destination]) {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop<HelpDestination>(destination);
  }

  Future<void> _openTour() async {
    if (_blocked) return;
    setState(() => _tourOpen = true);
    try {
      final destination = await Navigator.of(context).push<HelpDestination>(
        MaterialPageRoute<HelpDestination>(
          builder: (_) => const QuickTourPage(),
        ),
      );
      if (mounted && destination != null) _finish(destination);
    } finally {
      if (mounted) setState(() => _tourOpen = false);
    }
  }

  List<HelpTopic> _visibleTopics() {
    final words = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    final topics = helpTopics.where((topic) {
      final text =
          '${topic.title} ${topic.summary} '
                  '${topic.steps.join(' ')} ${topic.note ?? ''}'
              .toLowerCase();
      return words.every(text.contains);
    }).toList();
    // A contextual Help link opens its requested topic at the top without
    // scrolling past unrelated instructions. Searching still covers all topics.
    if (_search.text.trim().isEmpty && widget.initialTopicId != null) {
      final initial = topics.indexWhere(
        (topic) => topic.id == widget.initialTopicId,
      );
      if (initial > 0) topics.insert(0, topics.removeAt(initial));
    }
    return topics;
  }

  Widget _topicCard(HelpTopic topic) {
    final theme = Theme.of(context);
    final expanded = _expandedId == topic.id;
    return FieldPanel(
      key: ValueKey(topic.id),
      margin: const EdgeInsets.only(bottom: 16),
      prominent: expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: expanded,
            child: TextButton(
              onPressed: _blocked
                  ? null
                  : () => setState(() {
                      _expandedId = expanded ? null : topic.id;
                    }),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_destinationIcon(topic.destination), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(topic.title, style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: 8),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(topic.summary, style: theme.textTheme.bodyMedium),
          if (expanded) ...[
            const SizedBox(height: 20),
            _NumberedInstructions(steps: topic.steps),
            if (topic.note != null) ...[
              const SizedBox(height: 4),
              _HelpNote(text: topic.note!),
            ],
            if (topic.destination != null && topic.actionLabel != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _blocked ? null : () => _finish(topic.destination),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(topic.actionLabel!),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visibleTopics();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _helpToolbarHeight(context),
        title: const Text(
          'Help & tutorial',
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
              constraints: const BoxConstraints(maxWidth: 850),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldSectionHeading(
                      title: 'How to use Black Box',
                      eyebrow: 'Field handbook',
                      subtitle:
                          'Start with a quick tour, or find the task '
                          'you want help with. These instructions are '
                          'included in the app.',
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _blocked ? null : _openTour,
                          icon: const Icon(Icons.play_arrow_outlined),
                          label: const Text('Quick tour'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _blocked
                              ? null
                              : () => _finish(HelpDestination.appearance),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Appearance'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Search instructions',
                        hintText: 'Try offline, packed, map, or backup',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(_search.clear),
                                tooltip: 'Clear help search',
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${visible.length} help '
                        '${visible.length == 1 ? 'topic' : 'topics'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      FieldPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No instructions match that search. '
                              'Try a shorter word, or show all topics.',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => setState(_search.clear),
                              child: const Text('Show all topics'),
                            ),
                          ],
                        ),
                      ),
                    for (final topic in visible) _topicCard(topic),
                    const SizedBox(height: 8),
                    Text(
                      'Reading the tour does not change your plan or mark '
                      'your supplies ready. You can reopen Help from the '
                      'question-mark button.',
                      style: theme.textTheme.bodySmall,
                    ),
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

class QuickTourPage extends StatefulWidget {
  const QuickTourPage({super.key});

  @override
  State<QuickTourPage> createState() => _QuickTourPageState();
}

class _QuickTourPageState extends State<QuickTourPage> {
  int _step = 0;
  bool _leaving = false;

  void _finish([HelpDestination? destination]) {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop<HelpDestination>(destination);
  }

  void _move(int direction) {
    if (_leaving) return;
    final next = _step + direction;
    if (next >= 0 && next < quickTour.length) setState(() => _step = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = quickTour[_step];
    final last = _step == quickTour.length - 1;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _helpToolbarHeight(context),
        title: const Text(
          'Quick tour',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _leaving ? null : () => _finish(),
          tooltip: 'Close tour',
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: _leaving ? null : () => _finish(),
            child: const Text('Skip'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FieldBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  // Changing steps starts the next chapter at its top.
                  key: ValueKey(_step),
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Step ${_step + 1} of ${quickTour.length}',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (_step + 1) / quickTour.length,
                            minHeight: 5,
                            semanticsLabel: 'Current tutorial step',
                            semanticsValue:
                                '${_step + 1} of ${quickTour.length}',
                          ),
                          const SizedBox(height: 24),
                          FieldPanel(
                            prominent: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ExcludeSemantics(
                                    child: Icon(
                                      _destinationIcon(topic.destination),
                                      size: 32,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FieldSectionHeading(
                                  title: topic.title,
                                  subtitle: topic.summary,
                                ),
                                const SizedBox(height: 24),
                                _NumberedInstructions(steps: topic.steps),
                                if (topic.note != null) ...[
                                  const SizedBox(height: 4),
                                  _HelpNote(text: topic.note!),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Go at your own pace. You can skip this tour '
                            'and reopen it from Help.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _leaving || _step == 0
                              ? null
                              : () => _move(-1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                        if (last) ...[
                          OutlinedButton(
                            onPressed: _leaving ? null : () => _finish(),
                            child: const Text('Done'),
                          ),
                          FilledButton.icon(
                            onPressed: _leaving
                                ? null
                                : () => _finish(HelpDestination.plan),
                            icon: const Icon(Icons.place_outlined),
                            label: const Text('Open Plan'),
                          ),
                        ] else
                          FilledButton.icon(
                            onPressed: _leaving ? null : () => _move(1),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The app's padded action buttons and heading font need extra toolbar height
// when the reader increases the device text size.
double _helpToolbarHeight(BuildContext context) {
  final type = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  final titleHeight =
      scaler.scale(type.titleLarge?.fontSize ?? 22) *
          (type.titleLarge?.height ?? 1.2) +
      16;
  final actionHeight =
      scaler.scale(type.labelLarge?.fontSize ?? 14) *
          (type.labelLarge?.height ?? 1.25) +
      24;
  return [56.0, titleHeight, actionHeight].reduce((a, b) => a > b ? a : b);
}

class _NumberedInstructions extends StatelessWidget {
  const _NumberedInstructions({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 1}.', style: theme.textTheme.bodyLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(steps[index], style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HelpNote extends StatelessWidget {
  const _HelpNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

IconData _destinationIcon(HelpDestination? destination) =>
    switch (destination) {
      HelpDestination.home => Icons.home_outlined,
      HelpDestination.plan => Icons.place_outlined,
      HelpDestination.map => Icons.map_outlined,
      HelpDestination.sharedKit => Icons.checklist_rounded,
      HelpDestination.personalPack => Icons.inventory_2_outlined,
      HelpDestination.suggested => Icons.shopping_bag_outlined,
      HelpDestination.group => Icons.people_outline,
      HelpDestination.guides => Icons.menu_book_outlined,
      HelpDestination.appearance => Icons.tune_rounded,
      null => Icons.help_outline,
    };
