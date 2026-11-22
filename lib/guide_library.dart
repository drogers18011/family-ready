import 'package:material_ui/material_ui.dart';

import 'guide_files.dart';

/// Personal PDFs and videos kept separately from the shared-plan prototype.
class GuideLibraryPage extends StatefulWidget {
  const GuideLibraryPage({super.key});

  @override
  State<GuideLibraryPage> createState() => _GuideLibraryPageState();
}

class _GuideLibraryPageState extends State<GuideLibraryPage> {
  final _repository = createGuideRepository();
  final _search = TextEditingController();
  GuideLibrary? _library;
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _activity;
  double? _progress;
  GuideKind? _filter;

  ColorScheme get _colors => Theme.of(context).colorScheme;
  TextTheme get _type => Theme.of(context).textTheme;
  String get _where => _repository.isBrowser ? 'this browser' : 'this device';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _size(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  String _date(DateTime time) {
    final date = time.toLocal();
    return '${date.month}/${date.day}/${date.year}';
  }

  String _problem(Object error) {
    if (error is GuideException) return error.message;
    return 'The file operation could not finish. Keep your original file and '
        'check that storage is available before trying again.';
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshContents() async {
    final library = await _repository.load();
    if (mounted) setState(() => _library = library);
  }

  Future<void> _load() async {
    if (_working) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _refreshContents();
    } catch (error) {
      if (mounted) setState(() => _error = _problem(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    if (_working || _loading) return;
    setState(() {
      _working = true;
      _error = null;
      _activity = 'Choose a PDF or video';
      _progress = null;
    });
    var committed = false;
    try {
      final source = await pickGuideSource();
      if (source == null || !mounted) return;
      setState(() => _activity = 'Saving ${source.name}');
      await _repository.importFile(
        source,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress.clamp(0.0, 1.0).toDouble());
          }
        },
      );
      committed = true;
      await _refreshContents();
      _message('Guide saved to $_where. Open it to check the file.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = committed
              ? 'The guide was saved, but the list could not refresh. '
                    'Use Refresh before importing it again.'
              : _problem(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _activity = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _open(GuideRecord record) async {
    if (_working || _loading) return;
    setState(() {
      _working = true;
      _error = null;
      _activity = 'Checking saved copy';
    });
    PreparedGuide? prepared;
    try {
      prepared = await _repository.prepareOpen(record);
      if (!mounted) return;
      if (prepared.opensBrowserTab) {
        // Preparation has finished. The dialog's explicit button supplies the
        // fresh user gesture needed to open a local Blob in a new browser tab.
        final ready = prepared;
        setState(() => _activity = null);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Open saved guide'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title, style: _type.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'This opens the saved file in a new browser tab. '
                    'Your browser may offer a download if it cannot preview it.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await ready.open();
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) {
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted) setState(() => _error = _problem(error));
                  }
                },
                child: const Text('Open saved file'),
              ),
            ],
          ),
        );
      } else {
        await prepared.open();
      }
    } catch (error) {
      if (mounted) setState(() => _error = _problem(error));
    } finally {
      // A launched browser guide owns its URL until document unload. Disposing
      // an unused handle releases it without interrupting an opened video.
      prepared?.dispose();
      if (mounted) {
        setState(() {
          _working = false;
          _activity = null;
        });
      }
    }
  }

  Future<void> _rename(GuideRecord record) async {
    if (_working || _loading) return;
    final controller = TextEditingController(text: record.title);
    String? title;
    try {
      title = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Name this guide'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Guide title'),
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Save title'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    final newTitle = title;
    if (newTitle == null || !mounted) return;
    await _mutate(() => _repository.rename(record, newTitle), 'Guide renamed.');
  }

  Future<void> _remove(GuideRecord record) async {
    if (_working || _loading) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved guide?'),
        content: Text(
          'Remove "${record.title}" from Black Box on $_where? '
          'The original file you imported is kept. '
          'You will need that original to add it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep guide'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove copy'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await _mutate(() => _repository.remove(record), 'Saved copy removed.');
  }

  Future<void> _mutate(Future<void> Function() action, String success) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
      _activity = 'Updating saved guides';
    });
    var committed = false;
    try {
      await action();
      committed = true;
      await _refreshContents();
      _message(success);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = committed
              ? 'The change was saved, but the list could not refresh. '
                    'Use Refresh to reload it.'
              : _problem(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _activity = null;
        });
      }
    }
  }

  Widget _notice(String text, {bool error = false}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error ? _colors.errorContainer : _colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _colors.outlineVariant),
    ),
    child: Text(
      text,
      style: _type.bodyMedium?.copyWith(
        color: error ? _colors.onErrorContainer : _colors.onSurface,
      ),
    ),
  );

  Widget _guideCard(GuideEntry entry) {
    final guide = entry.record;
    final pdf = guide.kind == GuideKind.pdf;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  pdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.video_library_outlined,
                  color: _colors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guide.title, style: _type.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '${pdf ? 'PDF' : 'Video'} · ${_size(guide.bytes)} · '
                        'Added ${_date(guide.addedAt)}',
                        style: _type.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !_working && !_loading,
                  tooltip: 'Guide actions',
                  onSelected: (action) {
                    if (action == 'rename') _rename(guide);
                    if (action == 'remove') _remove(guide);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'remove', child: Text('Remove copy')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(guide.originalName, style: _type.bodySmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.available
                      ? Icons.download_done_outlined
                      : Icons.error_outline,
                  color: entry.available ? _colors.primary : _colors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.available
                        ? (_repository.isBrowser
                              ? 'Saved in this browser'
                              : 'Saved on this device')
                        : entry.problem ?? 'Saved file is unavailable.',
                    style: _type.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: !entry.available || _working || _loading
                  ? null
                  : () => _open(guide),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(
                pdf ? Icons.menu_book_outlined : Icons.play_arrow_outlined,
              ),
              label: Text(pdf ? 'Open PDF' : 'Open video'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _library?.entries ?? <GuideEntry>[];
    final query = _search.text.trim().toLowerCase();
    final visible = entries.where((entry) {
      final record = entry.record;
      if (_filter != null && record.kind != _filter) return false;
      return query.isEmpty ||
          '${record.title} ${record.originalName}'.toLowerCase().contains(
            query,
          );
    }).toList();
    final saved = entries.where((entry) => entry.available).toList();
    final bytes = saved.fold<int>(0, (sum, entry) => sum + entry.record.bytes);
    return PopScope(
      canPop: !_working,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offline guides'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _working ? null : () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              onPressed: _working || _loading ? null : _load,
              tooltip: 'Refresh saved guides',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your field library', style: _type.headlineMedium),
                    const SizedBox(height: 10),
                    Text(
                      'Import PDFs and videos so the file itself is kept on '
                      '$_where. These personal guides are separate from the '
                      'shared plan.',
                      style: _type.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    _notice(
                      _repository.isBrowser
                          ? 'Browser preview: saved files can be removed when '
                                'browser data is cleared or storage is reclaimed. '
                                'Keep the originals. The launcher must be running '
                                'to reopen this preview.'
                          : 'Files are copied into Black Box on this device. '
                                'Keep your originals as a backup. Open each guide '
                                'and test it in airplane mode before relying on it.',
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _working || _loading || _library == null
                              ? null
                              : _import,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Import PDF or video'),
                        ),
                        Text('${saved.length} saved · ${_size(bytes)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PDF, MP4, MOV, or M4V · Up to '
                      '${_size(_repository.maxImportBytes)} per file. '
                      'Cloud files need to finish downloading before import.',
                      style: _type.bodySmall,
                    ),
                    const SizedBox(height: 22),
                    if (_loading) const LinearProgressIndicator(),
                    if (_working && _activity != null) ...[
                      Semantics(liveRegion: true, child: Text(_activity!)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 18),
                    ],
                    if (_error != null) _notice(_error!, error: true),
                    for (final warning in _library?.warnings ?? <String>[])
                      _notice(warning),
                    if (!_loading) ...[
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Search guides',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _filter == null,
                            onSelected: (_) => setState(() => _filter = null),
                          ),
                          ChoiceChip(
                            label: const Text('PDFs'),
                            selected: _filter == GuideKind.pdf,
                            onSelected: (_) =>
                                setState(() => _filter = GuideKind.pdf),
                          ),
                          ChoiceChip(
                            label: const Text('Videos'),
                            selected: _filter == GuideKind.video,
                            onSelected: (_) =>
                                setState(() => _filter = GuideKind.video),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_library == null)
                        _notice(
                          'Saved guides could not be checked. Use Refresh to try again.',
                        ),
                      if (_library != null && visible.isEmpty)
                        _notice(
                          entries.isEmpty
                              ? 'No guides saved yet. Import a PDF or video '
                                    'to start your field library.'
                              : 'No guides match this search or filter.',
                        ),
                      ...visible.map(_guideCard),
                      const SizedBox(height: 10),
                      Text(
                        'Opening a saved file uses the device or browser viewer. '
                        'Video playback depends on its format. Guides are not '
                        'included in the group-plan JSON backup and are not '
                        'uploaded to a cloud account.',
                        style: _type.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 24),
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
