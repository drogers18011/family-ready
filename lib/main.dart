import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'black_box_theme.dart';
import 'field_surfaces.dart';
import 'guide_library.dart';
import 'help_content.dart';
import 'help_page.dart';
import 'personal_packlist.dart';
import 'plan_dialogs.dart';
import 'plan_files.dart';
import 'plan_models.dart';
import 'plan_map.dart';
import 'plan_store.dart';
import 'suggested_items.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'Barlow': 'assets/fonts/Barlow-OFL.txt',
      'Barlow Condensed': 'assets/fonts/BarlowCondensed-OFL.txt',
      'IBM Plex Mono': 'assets/fonts/IBMPlexMono-OFL.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
  runApp(const FamilyReadyApp());
}

class FamilyReadyApp extends StatefulWidget {
  const FamilyReadyApp({super.key});

  @override
  State<FamilyReadyApp> createState() => _FamilyReadyAppState();
}

class _FamilyReadyAppState extends State<FamilyReadyApp> {
  static const _appearanceKey = 'black_box.appearance.v1';
  final _preferences = SharedPreferencesAsync();
  BlackBoxStyle _style = BlackBoxStyle.terminal;
  int _appearanceRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final revision = _appearanceRevision;
    try {
      final stored = await _preferences.getString(_appearanceKey);
      if (!mounted || revision != _appearanceRevision) return;
      setState(() {
        // Field Terminal is the selected design. Older appearances open dark.
        _style = stored == BlackBoxStyle.terminalLight.name
            ? BlackBoxStyle.terminalLight
            : BlackBoxStyle.terminal;
      });
    } catch (_) {
      // Appearance is optional; a preference failure must not block the plan.
    }
  }

  Future<bool> _changeAppearance(BlackBoxStyle style) async {
    _appearanceRevision++;
    setState(() => _style = style);
    try {
      await _preferences.setString(_appearanceKey, style.name);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Black Box',
    debugShowCheckedModeBanner: false,
    theme: buildBlackBoxTheme(_style),
    themeAnimationDuration: Duration.zero,
    builder: (context, child) {
      // Flutter's temporary bridge supplies legacy theme/localization context.
      // Remove it after dependencies finish migrating to material_ui.
      // ignore: deprecated_member_use
      return MaterialUiCompatibilityBridge(
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: PlanHome(style: _style, onStyleChanged: _changeAppearance),
  );
}

class PlanHome extends StatefulWidget {
  const PlanHome({
    super.key,
    required this.style,
    required this.onStyleChanged,
  });

  final BlackBoxStyle style;
  final Future<bool> Function(BlackBoxStyle) onStyleChanged;

  @override
  State<PlanHome> createState() => _PlanHomeState();
}

class _PlanHomeState extends State<PlanHome> {
  // Keep the original key and origin so existing plans survive the update.
  static const _storageKey = PlanStore.currentKey;
  static const _previousKey = PlanStore.previousKey;
  static const _recoveryKey = PlanStore.recoveryKey;
  static const _helpPromptKey = 'black_box.help_intro_dismissed.v1';
  final _storage = SharedPreferencesAsync();
  late final _store = PlanStore(
    write: _storage.setString,
    remove: _storage.remove,
  );
  GroupPlan _plan = GroupPlan.sample();
  bool _loading = true;
  bool _saving = false;
  bool _fileBusy = false;
  bool _hasPrevious = false;
  bool _hasRecovery = false;
  bool _appearanceBusy = false;
  bool _guidesOpen = false;
  bool _helpOpen = false;
  bool _showHelpPrompt = false;
  int _helpPromptRevision = 0;
  int _kitSection = 0;
  String? _migrationSnapshot;
  final _search = TextEditingController();
  String _supplyFilter = 'All';
  String _categoryFilter = '';
  String _memberFilter = '';
  bool get _busy => _saving || _fileBusy;
  bool _dirty = false;
  String? _loadError;
  String? _writeError;
  String? _rawSavedData;
  static const _homeTab = 0;
  static const _planTab = 1;
  static const _mapTab = 2;
  static const _kitTab = 3;
  static const _groupTab = 4;
  int _tab = _homeTab;
  int _idCounter = 0;
  static const _labels = ['Home', 'Plan', 'Map', 'Kit', 'Group'];
  static const _icons = [
    Icons.home_outlined,
    Icons.place_outlined,
    Icons.map_outlined,
    Icons.checklist_rounded,
    Icons.people_outline,
  ];

  bool get _terminal => widget.style != BlackBoxStyle.aviation;
  bool get _light => widget.style == BlackBoxStyle.terminalLight;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  TextTheme get _type => Theme.of(context).textTheme;
  String get _storageLocation => kIsWeb ? 'this browser' : 'this device';
  bool get _canExportFiles =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHelpPreference();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _loadError = null;
      _rawSavedData = null;
    });
    try {
      final previous = await _storage.getString(_previousKey);
      final recovery = await _storage.getString(_recoveryKey);
      if (!mounted) return;
      setState(() {
        _hasPrevious = previous != null;
        _hasRecovery = recovery != null;
      });
      final raw = await _storage.getString(_storageKey);
      _rawSavedData = raw;
      final decoded = raw == null ? null : jsonDecode(raw);
      final plan = raw == null
          ? GroupPlan.sample()
          : GroupPlan.fromJson(decoded);
      _migrationSnapshot = decoded is Map && decoded['version'] == 1
          ? raw
          : null;
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _hasPrevious = previous != null;
        _dirty = false;
        _writeError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'Black Box could not read the plan saved on $_storageLocation. '
            'Nothing has been overwritten. You can retry, or copy the stored '
            'data if it is available.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change(VoidCallback change) async {
    if (_busy || _loading || _loadError != null || !mounted) return;
    setState(() {
      change();
      _dirty = true;
    });
    await _save();
  }

  Future<void> _save() async {
    if (_busy || _loading || _loadError != null) return;
    setState(() {
      _saving = true;
      _writeError = null;
    });
    final savedAt = DateTime.now().toUtc();
    try {
      // Preserve the exact old record before the first version-2 write.
      if (_migrationSnapshot != null) {
        await _storage.setString(_previousKey, _migrationSnapshot!);
        _migrationSnapshot = null;
        _hasPrevious = true;
      }
      // Edits are blocked until this write completes, keeping writes ordered.
      final encoded = jsonEncode(_plan.toJson(savedAt));
      await _storage.setString(_storageKey, encoded);
      _rawSavedData = encoded;
      if (!mounted) return;
      setState(() {
        _plan.savedAt = savedAt;
        _dirty = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dirty = true;
        _writeError =
            'Changes are only in this open app. Saving failed; '
            'retry or copy your plan before closing.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  String _personName(String? id) {
    for (final member in _plan.members) {
      if (member.id == id) return member.name;
    }
    return 'Unassigned';
  }

  String _date(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} at $hour:$minute';
  }

  String get _saveStatus {
    if (_fileBusy) return 'Working with a file…';
    if (_saving) return 'Saving on $_storageLocation…';
    if (_dirty) return 'Changes not saved';
    if (_plan.savedAt == null) return 'Sample plan · No changes saved yet';
    return 'Saved on $_storageLocation · ${_date(_plan.savedAt!)}';
  }

  Future<void> _loadHelpPreference() async {
    final revision = _helpPromptRevision;
    var dismissed = false;
    try {
      dismissed = await _storage.getBool(_helpPromptKey) ?? false;
    } catch (_) {
      // Optional help preferences must never prevent access to a saved plan.
    }
    if (!mounted || revision != _helpPromptRevision) return;
    setState(() => _showHelpPrompt = !dismissed);
  }

  Future<void> _dismissHelpPrompt() async {
    _helpPromptRevision++;
    if (mounted) setState(() => _showHelpPrompt = false);
    try {
      await _storage.setBool(_helpPromptKey, true);
    } catch (_) {
      if (mounted) {
        _message(
          'The tour reminder is hidden for this session. Its preference '
          'could not be saved, so it may appear next time.',
        );
      }
    }
  }

  Future<void> _openHelp({bool tour = false, String? topicId}) async {
    if (!mounted || _helpOpen) return;
    setState(() => _helpOpen = true);
    // Remember that the prompt was acknowledged, not that a real plan is
    // complete. Reading help never edits plan, packing, or guide data.
    unawaited(_dismissHelpPrompt());
    HelpDestination? destination;
    try {
      destination = await Navigator.of(context).push<HelpDestination>(
        MaterialPageRoute<HelpDestination>(
          builder: (_) => tour
              ? const QuickTourPage()
              : HelpCenterPage(initialTopicId: topicId),
        ),
      );
    } catch (_) {
      if (mounted) _message('Help could not open. Please try again.');
    } finally {
      if (mounted) setState(() => _helpOpen = false);
    }
    if (!mounted || destination == null) return;
    await _openHelpDestination(destination);
  }

  Future<void> _openHelpDestination(HelpDestination destination) async {
    if (!mounted) return;
    if (destination == HelpDestination.appearance) {
      if (!_appearanceBusy) await _showAppearance();
      return;
    }
    if (destination == HelpDestination.guides) {
      await _openGuides();
      return;
    }
    if (_loading || _busy || _loadError != null) {
      _message(
        'The plan is not available yet. Finish loading or saving, '
        'or resolve its load warning before opening this section.',
      );
      return;
    }
    setState(() {
      switch (destination) {
        case HelpDestination.home:
          _tab = _homeTab;
        case HelpDestination.plan:
          _tab = _planTab;
        case HelpDestination.map:
          _tab = _mapTab;
        case HelpDestination.sharedKit:
          _tab = _kitTab;
          _kitSection = 0;
        case HelpDestination.personalPack:
          _tab = _kitTab;
          _kitSection = 1;
        case HelpDestination.suggested:
          _tab = _kitTab;
          _kitSection = 2;
        case HelpDestination.group:
          _tab = _groupTab;
        case HelpDestination.guides:
        case HelpDestination.appearance:
          break;
      }
    });
  }

  Future<void> _showAppearance() async {
    final selected = await showModalBottomSheet<BlackBoxStyle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: _type.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Rugged Field Terminal · Choose light or dark.',
                  style: _type.bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final style in const [
                  BlackBoxStyle.terminal,
                  BlackBoxStyle.terminalLight,
                ])
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: Icon(
                      style == BlackBoxStyle.terminalLight
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: _colors.primary,
                    ),
                    title: Text(style.label),
                    subtitle: Text(style.subtitle),
                    trailing: widget.style == style
                        ? Icon(
                            Icons.check_circle_outline,
                            color: _colors.primary,
                          )
                        : null,
                    selected: widget.style == style,
                    onTap: () => Navigator.pop(sheetContext, style),
                  ),
                const Divider(height: 24),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showAboutDialog(
                      context: context,
                      applicationName: 'Black Box',
                      applicationVersion: 'Prototype 0.8.0',
                      children: const [
                        Text(
                          'A local preparedness plan for your people, meeting '
                          'places, kit, and saved PDF/video guides. Family sync, offline maps, and '
                          'offline directions are still in development.',
                        ),
                      ],
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('About Black Box & licenses'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) await _applyAppearance(selected);
  }

  Future<void> _toggleBrightness() => _applyAppearance(
    _light ? BlackBoxStyle.terminal : BlackBoxStyle.terminalLight,
  );

  Future<void> _openGuides() async {
    if (_guidesOpen) return;
    setState(() => _guidesOpen = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const GuideLibraryPage()),
      );
    } finally {
      if (mounted) setState(() => _guidesOpen = false);
    }
  }

  Future<void> _applyAppearance(BlackBoxStyle selected) async {
    if (!mounted || _appearanceBusy) return;
    setState(() => _appearanceBusy = true);
    final saved = await widget.onStyleChanged(selected);
    if (!mounted) return;
    setState(() => _appearanceBusy = false);
    if (!saved) {
      _message('Appearance changed for this session, but could not be saved.');
    }
  }

  Future<void> _copy(String text, String success) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard access failed. Your plan has not changed.'),
        ),
      );
    }
  }

  void _copyPlan() => _copy(
    readablePlanText(_plan, saveStatus: _saveStatus),
    'Plan copied as text.',
  );

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _fileStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _downloadPlan({bool readable = false}) async {
    if (_busy) return;
    final now = DateTime.now().toUtc();
    final data = {
      ..._plan.toJson(_dirty ? now : (_plan.savedAt ?? now)),
      'exportedAt': now.toIso8601String(),
    };
    var contents = readable
        ? readablePlanText(_plan, saveStatus: _saveStatus)
        : const JsonEncoder.withIndent('  ').convert(data);
    if (!readable && utf8.encode(contents).length > maxPlanBackupBytes) {
      contents = jsonEncode(data);
    }
    if (!readable && utf8.encode(contents).length > maxPlanBackupBytes) {
      _message(
        'This plan is larger than the 2 MB restore limit. Download a text copy and contact us before replacing it.',
      );
      return;
    }
    setState(() => _fileBusy = true);
    try {
      final requested = await savePlanFile(
        contents: contents,
        filename:
            'black_box_${readable ? 'plan' : 'backup'}_${_fileStamp()}.${readable ? 'txt' : 'json'}',
        mimeType: readable ? 'text/plain' : 'application/json',
      );
      if (requested)
        _message(
          kIsWeb
              ? 'Download requested. Check your browser’s Downloads folder.'
              : 'File saved to the location you chose.',
        );
    } on PlanFileException catch (error) {
      _message(error.message);
    } catch (_) {
      _message(
        'The file could not be exported. Your plan is unchanged; you can still copy it as text.',
      );
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _downloadStoredData({
    bool previous = false,
    bool recovery = false,
  }) async {
    if (_busy) return;
    setState(() => _fileBusy = true);
    try {
      final contents = recovery
          ? await _storage.getString(_recoveryKey)
          : previous
          ? await _storage.getString(_previousKey)
          : _rawSavedData;
      if (contents == null) {
        _message('No stored copy is available.');
        return;
      }
      final requested = await savePlanFile(
        contents: contents,
        filename:
            'black_box_${recovery
                ? 'recovery'
                : previous
                ? 'previous'
                : 'stored'}_${_fileStamp()}.json',
        mimeType: 'application/json',
      );
      if (requested)
        _message(
          kIsWeb
              ? 'Stored-data download requested. Check your Downloads folder.'
              : 'Stored data saved.',
        );
    } catch (_) {
      _message('The stored copy could not be exported. Nothing was replaced.');
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _restoreBackup({
    bool previous = false,
    bool recovery = false,
  }) async {
    if (_busy || _loading) return;
    setState(() => _fileBusy = true);
    var stage = 'read';
    try {
      String contents;
      String filename;
      if (previous || recovery) {
        final stored = await _storage.getString(
          recovery ? _recoveryKey : _previousKey,
        );
        if (stored == null) {
          _message('That local copy is no longer available.');
          return;
        }
        contents = stored;
        filename = recovery
            ? 'Recovery copy from a restore'
            : 'Previous local copy';
      } else {
        final selected = await pickPlanBackup();
        if (selected == null) return;
        contents = selected.contents;
        filename = selected.name;
      }
      final incoming = GroupPlan.fromJson(jsonDecode(contents));
      // Check the upgraded form too, so an accepted file can be exported again.
      final checkedAt = DateTime.now().toUtc();
      final canonicalBackup = jsonEncode({
        ...incoming.toJson(checkedAt),
        'exportedAt': checkedAt.toIso8601String(),
      });
      if (!previous &&
          !recovery &&
          utf8.encode(canonicalBackup).length > maxPlanBackupBytes) {
        throw const PlanFileException(
          'This plan exceeds the 2 MB backup limit after conversion. Choose a smaller backup.',
        );
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Restore this plan?'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incoming.groupName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${incoming.members.length} members · ${incoming.supplies.length} supplies',
                ),
                const SizedBox(height: 8),
                Text(
                  '${(incoming.primary.isSet ? 1 : 0) + (incoming.backup.isSet ? 1 : 0)} meeting places',
                ),
                const SizedBox(height: 8),
                Text('File: $filename'),
                const SizedBox(height: 20),
                Text(
                  'This replaces the plan on $_storageLocation. A copy of the current '
                  'stored plan will be kept here so you can go back.',
                ),
                const SizedBox(height: 10),
                Text(
                  _canExportFiles
                      ? 'For a separate copy, cancel and download a backup first. '
                            'Restoring a file does not update anyone else’s device.'
                      : 'Keep your original backup file. Restoring a file does '
                            'not update anyone else’s device.',
                ),
                if (_hasRecovery && !recovery) ...[
                  const SizedBox(height: 12),
                  Text(
                    _canExportFiles
                        ? 'A recovery copy from an earlier restore is also stored here. '
                              'This restore will replace it. Cancel and download that '
                              'recovery copy first if you need it.'
                        : 'A recovery copy from an earlier restore is also stored here. '
                              'This restore will replace it. Cancel if you need to keep '
                              'that recovery copy.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace current plan'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      stage = 'save';
      final now = DateTime.now().toUtc();
      // Preserve current edits too, including any that failed to autosave.
      // On a load error, preserve the raw record instead of a sample plan.
      final current = _loadError != null
          ? _rawSavedData
          : (!_dirty && _rawSavedData != null)
          ? _rawSavedData
          : jsonEncode(_plan.toJson(now));
      if (current == null) {
        throw const PlanFileException(
          'The current stored data could not be read. Retry loading before replacing it.',
        );
      }
      final encoded = jsonEncode(incoming.toJson(now));
      final result = await _store.commitRestore(
        currentRaw: current,
        incomingRaw: contents,
        committedRaw: encoded,
      );
      if (!mounted) return;
      setState(() {
        _plan = incoming;
        _plan.savedAt = now;
        _rawSavedData = encoded;
        _migrationSnapshot = null;
        _hasPrevious = true;
        _hasRecovery = result.recoveryRemains;
        _dirty = false;
        _loadError = null;
        _writeError = null;
        _tab = _homeTab;
        _supplyFilter = 'All';
        _categoryFilter = '';
        _memberFilter = '';
        _search.clear();
      });
      _message('Plan restored and saved on $_storageLocation.');
    } on RestoreFailure catch (error) {
      if (mounted)
        setState(() {
          _hasRecovery = _hasRecovery || error.recoveryAvailable;
          _hasPrevious = _hasPrevious || error.previousUpdated;
        });
      _message(
        error.recoveryAvailable
            ? 'Restore interrupted. The selected backup is preserved as a Recovery '
                  'copy; preview it before retrying.'
            : 'Restore could not start. Existing stored plans were not replaced. '
                  'Keep the app open and copy your plan text before retrying.',
      );
    } on PlanFileException catch (error) {
      _message(error.message);
    } on FormatException catch (error) {
      _message(
        'This backup could not be restored: ${error.message} Your current plan was not replaced.',
      );
    } catch (_) {
      _message(
        stage == 'read'
            ? 'The backup could not be opened. Your current plan was not replaced.'
            : 'The restore could not be saved. Keep the app open and copy your '
                  'current plan text before retrying.',
      );
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<String?> _nameDialog(
    String title,
    String label,
    String initial, {
    String? Function(String)? extraValidation,
  }) {
    final key = GlobalKey<FormState>();
    var draft = initial;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: Form(
            key: key,
            child: TextFormField(
              initialValue: initial,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(labelText: label),
              onChanged: (value) => draft = value,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Please enter a $label.';
                return extraValidation?.call(text);
              },
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
              if (key.currentState!.validate()) {
                Navigator.pop(dialogContext, draft.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameGroup() async {
    final name = await _nameDialog(
      'Name your group',
      'group name',
      _plan.groupName,
    );
    if (name != null && mounted) await _change(() => _plan.groupName = name);
  }

  Future<void> _editMember([FamilyMember? member]) async {
    final name = await _nameDialog(
      member == null ? 'Add a member' : 'Edit member',
      'name',
      member?.name ?? '',
      extraValidation: (name) =>
          _plan.members.any(
            (other) =>
                other.id != member?.id &&
                other.name.trim().toLowerCase() == name.trim().toLowerCase(),
          )
          ? 'This name is already in your group.'
          : null,
    );
    if (name == null || !mounted) return;
    await _change(() {
      if (member == null) {
        _plan.members.add(FamilyMember(_newId('person'), name));
      } else {
        final index = _plan.members.indexWhere(
          (other) => other.id == member.id,
        );
        if (index >= 0) _plan.members[index] = FamilyMember(member.id, name);
      }
    });
  }

  Future<void> _removeMember(FamilyMember member) async {
    if (_plan.members.length <= 1) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          'Their supplies will stay on the list and become '
          'unassigned. This changes only your local prototype.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await _change(() {
      _plan.members.removeWhere((other) => other.id == member.id);
      if (_memberFilter == member.id) _memberFilter = '';
      for (final item in _plan.supplies) {
        if (item.assignedTo == member.id) item.assignedTo = null;
      }
    });
  }

  Future<void> _editPlace(bool primary) async {
    final result = await editMeetingPlace(
      context,
      initial: primary ? _plan.primary : _plan.backup,
      primary: primary,
    );
    if (result == null || !mounted) return;
    await _change(() {
      if (primary) {
        _plan.primary = result;
      } else {
        _plan.backup = result;
      }
    });
  }

  Future<void> _editSupply([Supply? item]) async {
    final result = await editSupplyDialog(
      context,
      initial: item,
      members: _plan.members,
      newId: _newId('supply'),
    );
    if (result == null || !mounted) return;
    await _change(() {
      if (item == null) {
        _plan.supplies.add(result);
      } else {
        final index = _plan.supplies.indexWhere((other) => other.id == item.id);
        if (index >= 0) _plan.supplies[index] = result;
      }
    });
  }

  Future<void> _setPin(bool primary) async {
    final existing = primary ? _plan.primary : _plan.backup;
    final point = await chooseMeetingPoint(
      context,
      latitude: existing.latitude,
      longitude: existing.longitude,
    );
    if (point == null || !mounted) return;
    final updated = MeetingPlace(
      name: existing.name,
      address: existing.address,
      notes: existing.notes,
      latitude: point.latitude,
      longitude: point.longitude,
    );
    await _change(() {
      if (primary) {
        _plan.primary = updated;
      } else {
        _plan.backup = updated;
      }
    });
  }

  Future<void> _removeSupply(Supply item) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${item.name}?'),
        content: const Text(
          'This removes the item and its assignment from this plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await _change(
      () => _plan.supplies.removeWhere((other) => other.id == item.id),
    );
  }

  Widget _panel(Widget child) => FieldPanel(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    child: child,
  );

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: FieldSectionHeading(
      eyebrow:
          '${(_tab + 1).toString().padLeft(2, '0')} / ${_labels[_tab].toUpperCase()}',
      title: title,
      subtitle: subtitle,
    ),
  );

  Widget _helpIntroduction() => FieldPanel(
    margin: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Get started with Black Box', style: _type.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Take a short tour of your plan, kit, and saved guides. '
          'You can skip it and reopen it from the question-mark button.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _helpOpen ? null : () => _openHelp(tour: true),
              icon: const Icon(Icons.help_outline),
              label: const Text('Start quick tour'),
            ),
            TextButton(
              onPressed: _dismissHelpPrompt,
              child: const Text('Not now'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _overview() {
    final packed = _plan.supplies.where((item) => item.packed).length;
    final unassigned = _plan.supplies
        .where((item) => item.assignedTo == null)
        .length;
    final primary = _plan.primary;
    final total = _plan.supplies.length;
    final primaryName = primary.isSet
        ? (primary.name.isEmpty ? 'Your meeting point' : primary.name)
        : 'Choose a place to meet';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Your field plan', _plan.groupName),
        if (_showHelpPrompt)
          _helpIntroduction()
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: _helpOpen ? null : () => _openHelp(),
              icon: const Icon(Icons.help_outline),
              label: const Text('Help & tutorial'),
            ),
          ),
        FieldPanel(
          prominent: true,
          accent: _colors.primary,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place_outlined, color: _colors.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'PRIMARY MEETING PLACE',
                      style: _type.labelMedium?.copyWith(
                        color: _colors.primary,
                        letterSpacing: _terminal ? 0 : 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(primaryName, style: _type.headlineLarge),
              const SizedBox(height: 10),
              Text(
                primary.address.isNotEmpty
                    ? primary.address
                    : primary.hasCoordinates
                    ? '${primary.latitude!.toStringAsFixed(6)}, ${primary.longitude!.toStringAsFixed(6)}'
                    : 'Add an address, a backup location, and clear instructions.',
                style: _type.bodyLarge?.copyWith(
                  color: _colors.onSurfaceVariant,
                ),
              ),
              if (primary.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  primary.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _type.bodyMedium,
                ),
              ],
              if (_terminal) ...[
                const Divider(height: 32),
                Text('BACKUP LOCATION', style: _type.labelMedium),
                const SizedBox(height: 6),
                Text(
                  _plan.backup.isSet
                      ? (_plan.backup.name.isEmpty
                            ? 'Backup meeting point added'
                            : _plan.backup.name)
                      : 'Not added yet',
                  style: _type.bodyLarge,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _tab = _planTab),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Open meeting plan'),
                ),
              ),
            ],
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _terminal ? 'KIT / PACKING' : 'Your go-bag kit',
                style: _type.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                total == 0
                    ? 'No items listed yet'
                    : '$packed of $total items packed',
                style: _type.headlineSmall,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _colors.surfaceContainerLowest,
                  border: Border.all(color: _colors.outline),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : packed / total,
                  minHeight: 8,
                  semanticsLabel: 'Listed items marked packed',
                  semanticsValue: '$packed of $total',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                total == 0
                    ? 'Add what your group plans to bring.'
                    : unassigned == 0
                    ? 'Every listed item has an assigned person.'
                    : '$unassigned listed items still need an assigned person.',
                style: _type.bodyMedium?.copyWith(
                  color: _colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _summaryRow(
                Icons.checklist_rounded,
                'Open kit and personal pack',
                'Group supplies and your private packing checklist.',
                _kitTab,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _tab = _kitTab;
                  _kitSection = 2;
                }),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Browse suggested items'),
              ),
            ],
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow(
                Icons.people_outline,
                '${_plan.members.length} people in this plan',
                'Review names and assignments.',
                _groupTab,
              ),
              const Divider(height: 24),
              _summaryRow(
                Icons.folder_copy_outlined,
                'Keep a copy',
                'Backup, restore, and readable plan text.',
                _groupTab,
              ),
            ],
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OFFLINE GUIDES', style: _type.titleLarge),
              const SizedBox(height: 10),
              Text(
                'Keep PDFs and videos on $_storageLocation for reference.',
                style: _type.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _guidesOpen ? null : _openGuides,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Open guides'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 20,
                color: _colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Map imagery requires internet.',
                  style: _type.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String title, String subtitle, int tab) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _tab = tab),
      );

  Widget _placeCard(String label, MeetingPlace place, bool primary) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(primary ? Icons.location_on_outlined : Icons.alt_route),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => _editPlace(primary),
              tooltip: 'Edit $label',
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          place.isSet
              ? (place.name.isEmpty ? 'Unnamed location' : place.name)
              : 'Choose a place to meet',
          style: _type.titleLarge,
        ),
        if (place.address.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(place.address),
        ],
        if (place.hasCoordinates) ...[
          const SizedBox(height: 10),
          SelectableText(
            'Map pin: ${place.latitude!.toStringAsFixed(6)}, '
            '${place.longitude!.toStringAsFixed(6)}',
          ),
        ],
        if (place.notes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(place.notes),
        ],
        if (!place.isSet) ...[
          const SizedBox(height: 8),
          const Text('Add an address and clear instructions for your group.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _editPlace(primary),
            icon: const Icon(Icons.add),
            label: const Text('Add location'),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _setPin(primary),
          icon: const Icon(Icons.map_outlined),
          label: Text(
            place.hasCoordinates ? 'View / change map pin' : 'Choose map pin',
          ),
        ),
      ],
    ),
  );

  Widget _meetings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Meeting plan',
        'Your primary location, backup, and written instructions.',
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _tab = _mapTab),
          icon: const Icon(Icons.map_outlined),
          label: const Text('View locations on map'),
        ),
      ),
      _placeCard('Primary meeting place', _plan.primary, true),
      _placeCard('Backup meeting place', _plan.backup, false),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Written details and coordinates are saved on $_storageLocation after '
          'a successful save. Map imagery needs internet; routes, closures, and '
          'live hazards are not shown.',
          style: _type.bodySmall,
        ),
      ),
    ],
  );

  Widget _map() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Plan locations', _plan.groupName),
      PlanMapPanel(
        plan: _plan,
        onEditPlace: (primary) => _editPlace(primary),
        onSetPin: (primary) => _setPin(primary),
      ),
    ],
  );

  Widget _kit() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Shared kit'),
            selected: _kitSection == 0,
            onSelected: (_) => setState(() => _kitSection = 0),
          ),
          ChoiceChip(
            label: const Text('My pack'),
            selected: _kitSection == 1,
            onSelected: (_) => setState(() => _kitSection = 1),
          ),
          ChoiceChip(
            label: const Text('Suggested'),
            selected: _kitSection == 2,
            onSelected: (_) => setState(() => _kitSection = 2),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (_kitSection == 1)
        const PersonalPacklistPanel()
      else if (_kitSection == 2)
        SuggestedItemsPanel(onOpenPack: () => setState(() => _kitSection = 1))
      else
        _supplies(),
    ],
  );

  Widget _supplies() {
    final packed = _plan.supplies.where((item) => item.packed).length;
    final query = _search.text.trim().toLowerCase();
    final visible = _plan.supplies.where((item) {
      if (_supplyFilter == 'To pack' && item.packed) return false;
      if (_supplyFilter == 'Packed' && !item.packed) return false;
      if (_supplyFilter == 'Unassigned' && item.assignedTo != null)
        return false;
      if (_categoryFilter.isNotEmpty && item.category != _categoryFilter)
        return false;
      if (_memberFilter.isNotEmpty && item.assignedTo != _memberFilter)
        return false;
      final haystack =
          '${item.name} ${item.quantity} ${item.category} ${item.notes} ${_personName(item.assignedTo)}';
      return query.isEmpty || haystack.toLowerCase().contains(query);
    }).toList();
    final hasFilters =
        query.isNotEmpty ||
        _supplyFilter != 'All' ||
        _categoryFilter.isNotEmpty ||
        _memberFilter.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Shared kit',
          '$packed of ${_plan.supplies.length} listed items packed. Set quantities, assign people, and check them off.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: FilledButton.icon(
            onPressed: () => _editSupply(),
            icon: const Icon(Icons.add),
            label: const Text('Add supply'),
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search supplies',
                  hintText: 'Item, person, quantity, or notes',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(() => _search.clear()),
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in [
                    'All',
                    'To pack',
                    'Unassigned',
                    'Packed',
                  ])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _supplyFilter == filter,
                      onSelected: (_) => setState(() => _supplyFilter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 500
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: width,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('category:$_categoryFilter'),
                          initialValue: _categoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All categories'),
                            ),
                            ...supplyCategories.map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _categoryFilter = value ?? ''),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('person:$_memberFilter'),
                          initialValue: _memberFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned to',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Everyone'),
                            ),
                            ..._plan.members.map(
                              (member) => DropdownMenuItem(
                                value: member.id,
                                child: Text(member.name),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _memberFilter = value ?? ''),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Showing ${visible.length} of ${_plan.supplies.length} supplies',
                  ),
                  if (hasFilters)
                    TextButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _supplyFilter = 'All';
                        _categoryFilter = '';
                        _memberFilter = '';
                      }),
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (visible.isEmpty)
          _panel(
            Text(
              _plan.supplies.isEmpty
                  ? 'Your supply list is empty. Add the first item above.'
                  : 'No supplies match these filters. Try another search or clear the filters.',
            ),
          ),
        ...visible.map(
          (item) => _panel(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.packed,
                  semanticLabel: 'Packed: ${item.name}',
                  onChanged: (value) =>
                      _change(() => item.packed = value ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _editSupply(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: _type.titleMedium?.copyWith(
                              decoration: item.packed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item.quantity.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Quantity: ${item.quantity}'),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _tag(item.category),
                              _tag(
                                _personName(item.assignedTo),
                                attention: item.assignedTo == null,
                              ),
                              if (item.packed) _tag('Packed'),
                            ],
                          ),
                          if (item.notes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              item.notes,
                              style: _type.bodyMedium?.copyWith(
                                color: _colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Supply actions',
                  onSelected: (action) {
                    if (action == 'edit') _editSupply(item);
                    if (action == 'delete') _removeSupply(item);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit / assign')),
                    PopupMenuItem(value: 'delete', child: Text('Remove')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tag(String text, {bool attention = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: attention ? _colors.tertiaryContainer : _colors.secondaryContainer,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: _colors.outlineVariant),
    ),
    child: Text(
      text,
      style: _type.labelMedium?.copyWith(
        color: attention
            ? _colors.onTertiaryContainer
            : _colors.onSecondaryContainer,
      ),
    ),
  );

  Widget _group() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Your group', 'People and assignments in this local plan.'),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GROUP NAME',
              style: _type.labelMedium?.copyWith(
                color: _colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _plan.groupName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _renameGroup,
                  tooltip: 'Edit group name',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This is a local roster. Adding a name does not invite or notify '
              'anyone; family sync and messaging are still in development.',
              style: _type.bodySmall,
            ),
          ],
        ),
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ..._plan.members.map(
              (member) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(member.name.characters.first.toUpperCase()),
                ),
                title: Text(member.name),
                subtitle: Text(
                  '${_plan.supplies.where((item) => item.assignedTo == member.id).length} assigned · '
                  '${_plan.supplies.where((item) => item.assignedTo == member.id && item.packed).length} packed',
                ),
                onTap: () => _editMember(member),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Member actions',
                  onSelected: (action) {
                    if (action == 'edit') _editMember(member);
                    if (action == 'remove') _removeMember(member);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit name'),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      enabled: _plan.members.length > 1,
                      child: const Text('Remove member'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _editMember(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add member'),
            ),
          ],
        ),
      ),
      _backupPanel(),
    ],
  );

  Widget _backupPanel() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Backup & restore', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(
          _canExportFiles
              ? 'A backup file keeps your people, meeting places, map pins, '
                    'supplies, and packed status. Save it somewhere you can find again.'
              : 'Restore a JSON backup from Files. Creating or sharing backup '
                    'files on a phone is still in development; export them from '
                    'the browser or desktop app for now.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_canExportFiles)
              FilledButton.icon(
                onPressed: () => _downloadPlan(),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download backup'),
              ),
            OutlinedButton.icon(
              onPressed: () => _restoreBackup(),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Restore backup'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Backup files are ordinary, unencrypted JSON files. They contain the '
          'details you entered; keep them private. They do not include map images.',
          style: _type.bodySmall,
        ),
        const Divider(height: 32),
        Text('A readable copy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          _canExportFiles
              ? 'Download a text plan to keep and print, or copy the text. '
                    'Use a JSON backup to restore into the app.'
              : 'Copy the plan text to keep a readable copy elsewhere. '
                    'Text copies cannot be restored into the app; restore needs '
                    'a JSON backup.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_canExportFiles)
              OutlinedButton.icon(
                onPressed: () => _downloadPlan(readable: true),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Download text plan'),
              ),
            TextButton.icon(
              onPressed: _copyPlan,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy plan text'),
            ),
          ],
        ),
        if (_hasRecovery) ...[
          const Divider(height: 32),
          Text('Recovery copy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'The selected backup was kept during a restore. You can preview '
            'it before trying the restore again.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: () => _restoreBackup(recovery: true),
                child: const Text('Preview recovery copy'),
              ),
              if (_canExportFiles)
                TextButton(
                  onPressed: () => _downloadStoredData(recovery: true),
                  child: const Text('Download recovery copy'),
                ),
            ],
          ),
        ],
        if (_hasPrevious) ...[
          const Divider(height: 32),
          Text(
            'Previous local copy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'One earlier copy is kept when you upgrade or restore a plan. '
            'It stays on $_storageLocation. Keep a separate backup as well.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: () => _restoreBackup(previous: true),
                child: const Text('Preview previous copy'),
              ),
              if (_canExportFiles)
                TextButton(
                  onPressed: () => _downloadStoredData(previous: true),
                  child: const Text('Download previous copy'),
                ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _content() {
    final pages = [_overview, _meetings, _map, _kit, _group];
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 3),
        if (_writeError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _colors.errorContainer,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _writeError!,
                  style: _type.bodyMedium?.copyWith(
                    color: _colors.onErrorContainer,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Retry save'),
                ),
                TextButton(
                  onPressed: _copyPlan,
                  child: const Text('Copy plan'),
                ),
              ],
            ),
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _busy,
            child: SingleChildScrollView(
              key: ValueKey(_tab),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Padding(
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                    ),
                    child: pages[_tab](),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: _colors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: _colors.outline, width: 1.5)),
          ),
          child: Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _dirty
                      ? Icons.warning_amber_rounded
                      : _plan.savedAt == null
                      ? Icons.info_outline
                      : Icons.save_outlined,
                  size: 18,
                  color: _dirty ? _colors.tertiary : _colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveStatus,
                    style: _type.labelMedium?.copyWith(
                      color: _dirty
                          ? _colors.tertiary
                          : _colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadFailure() => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder_off_outlined, size: 36),
                const SizedBox(height: 16),
                Text(
                  'Couldn’t open saved plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(_loadError!),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Retry loading'),
                ),
                if (_rawSavedData != null) ...[
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _copy(_rawSavedData!, 'Stored data copied.'),
                    child: const Text('Copy stored data'),
                  ),
                  if (_canExportFiles)
                    TextButton(
                      onPressed: _busy ? null : () => _downloadStoredData(),
                      child: const Text('Download stored data'),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => _restoreBackup(),
                    child: const Text('Restore a backup file'),
                  ),
                ],
                if (_hasPrevious) ...[
                  const Divider(height: 24),
                  const Text('A previous local copy is available.'),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _restoreBackup(previous: true),
                    child: const Text('Preview previous copy'),
                  ),
                  if (_canExportFiles)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _downloadStoredData(previous: true),
                      child: const Text('Download previous copy'),
                    ),
                ],
                if (_hasRecovery) ...[
                  const Divider(height: 24),
                  const Text('A recovery copy from a restore is available.'),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _restoreBackup(recovery: true),
                    child: const Text('Preview recovery copy'),
                  ),
                  if (_canExportFiles)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _downloadStoredData(recovery: true),
                      child: const Text('Download recovery copy'),
                    ),
                ],
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final available = !_loading && _loadError == null;
      final compactBrand =
          constraints.maxWidth < 400 ||
          MediaQuery.textScalerOf(context).scale(16) > 20;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          titleSpacing: 16,
          flexibleSpace: const FieldBackdrop(child: SizedBox.expand()),
          title: Row(
            children: [
              if (!compactBrand) ...[
                ExcludeSemantics(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: ShapeDecoration(
                      color: _colors.primary,
                      shape: BeveledRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                        side: BorderSide(color: _colors.outline, width: 1.5),
                      ),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: _colors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BLACK BOX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _type.titleLarge?.copyWith(
                        fontFamily: 'Barlow Condensed',
                        fontWeight: FontWeight.w600,
                        fontSize: compactBrand ? 24 : 28,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (!compactBrand) ...[
                      const SizedBox(height: 2),
                      Text(
                        'FIELD TERMINAL',
                        style: _type.labelSmall?.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.0,
                          color: _colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _guidesOpen ? null : _openGuides,
              tooltip: 'Offline guides',
              icon: const Icon(Icons.menu_book_outlined),
            ),
            IconButton(
              onPressed: _appearanceBusy ? null : _toggleBrightness,
              tooltip: _light ? 'Switch to dark mode' : 'Switch to light mode',
              icon: Icon(
                _light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
            ),
            IconButton(
              onPressed: _helpOpen ? null : () => _openHelp(),
              tooltip: 'Help & tutorial',
              icon: const Icon(Icons.help_outline),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: ExcludeSemantics(
              child: Container(
                height: 4,
                color: _colors.outlineVariant,
                alignment: Alignment.centerLeft,
                child: Container(width: 64, color: _colors.tertiary),
              ),
            ),
          ),
        ),
        body: FieldBackdrop(
          child: SafeArea(
            top: false,
            bottom: wide || !available,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? _loadFailure()
                : Row(
                    children: [
                      if (wide)
                        DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: _colors.outline,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: NavigationRail(
                            extended: true,
                            selectedIndex: _tab,
                            onDestinationSelected: (index) =>
                                setState(() => _tab = index),
                            destinations: List.generate(
                              _labels.length,
                              (index) => NavigationRailDestination(
                                icon: Icon(_icons[index]),
                                label: Text(_labels[index]),
                              ),
                            ),
                          ),
                        ),
                      Expanded(child: _content()),
                    ],
                  ),
          ),
        ),
        bottomNavigationBar: !wide && available
            ? DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _colors.outline, width: 1.5),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (index) =>
                      setState(() => _tab = index),
                  destinations: List.generate(
                    _labels.length,
                    (index) => NavigationDestination(
                      icon: Icon(_icons[index]),
                      label: _labels[index],
                    ),
                  ),
                ),
              )
            : null,
      );
    },
  );
}
