import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plan_dialogs.dart';
import 'plan_files.dart';
import 'plan_models.dart';
import 'plan_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyReadyApp());
}

class FamilyReadyApp extends StatelessWidget {
  const FamilyReadyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Black Box',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF285B48)),
      scaffoldBackgroundColor: const Color(0xFFF5F5EF),
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    builder: (context, child) {
      // Flutter's temporary bridge supplies legacy theme/localization context.
      // Remove it after dependencies finish migrating to material_ui.
      // ignore: deprecated_member_use
      return MaterialUiCompatibilityBridge(
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: const PlanHome(),
  );
}

class PlanHome extends StatefulWidget {
  const PlanHome({super.key});
  @override
  State<PlanHome> createState() => _PlanHomeState();
}

class _PlanHomeState extends State<PlanHome> {
  // Keep the original key and origin so existing plans survive the update.
  static const _storageKey = PlanStore.currentKey;
  static const _previousKey = PlanStore.previousKey;
  static const _recoveryKey = PlanStore.recoveryKey;
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
  int _tab = 0;
  int _idCounter = 0;
  static const _labels = ['Overview', 'Meeting plan', 'Supplies', 'Group'];
  static const _icons = [
    Icons.home_outlined,
    Icons.place_outlined,
    Icons.checklist_rounded,
    Icons.people_outline,
  ];

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
            'Your browser could not read the saved plan. '
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
            'Changes are only in this open page. Saving failed; '
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
    if (_saving) return 'Saving on this browser…';
    if (_dirty) return 'Changes not saved';
    if (_plan.savedAt == null) return 'Sample plan · No changes saved yet';
    return 'Saved on this browser · ${_date(_plan.savedAt!)}';
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
                const Text(
                  'This replaces the plan in this browser. A copy of the current '
                  'stored plan will be kept here so you can go back.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'For a separate copy, cancel and download a backup first. '
                  'Restoring a file does not update anyone else’s device.',
                ),
                if (_hasRecovery && !recovery) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'A recovery copy from an earlier restore is also stored here. '
                    'This restore will replace it. Cancel and download that recovery copy first if you need it.',
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
        _tab = 0;
        _supplyFilter = 'All';
        _categoryFilter = '';
        _memberFilter = '';
        _search.clear();
      });
      _message('Plan restored and saved in this browser.');
    } on RestoreFailure catch (error) {
      if (mounted)
        setState(() {
          _hasRecovery = _hasRecovery || error.recoveryAvailable;
          _hasPrevious = _hasPrevious || error.previousUpdated;
        });
      _message(
        error.recoveryAvailable
            ? 'Restore interrupted. The selected backup is preserved as a Recovery copy; preview or download it before retrying.'
            : 'Restore could not start. Existing stored plans were not replaced. Keep this page open and download your plan.',
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
            : 'The restore could not be saved. Keep this page open and download your current plan before retrying.',
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

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE1E5DC)),
    ),
    child: child,
  );

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF203C32),
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );

  Widget _overview() {
    final packed = _plan.supplies.where((item) => item.packed).length;
    final unassigned = _plan.supplies
        .where((item) => item.assignedTo == null)
        .length;
    final primary = _plan.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('A plan to come together.', _plan.groupName),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 22),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF285B48),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.explore_outlined,
                color: Color(0xFFDCECC6),
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                primary.isSet
                    ? 'YOUR PRIMARY MEETING PLACE'
                    : 'START WITH A MEETING PLACE',
                style: const TextStyle(
                  color: Color(0xFFDCECC6),
                  fontSize: 12,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                primary.isSet
                    ? (primary.name.isNotEmpty
                          ? primary.name
                          : 'Your main meeting point')
                    : 'Know where to find each other.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                primary.address.isNotEmpty
                    ? primary.address
                    : primary.hasCoordinates
                    ? '${primary.latitude!.toStringAsFixed(6)}, ${primary.longitude!.toStringAsFixed(6)}'
                    : 'Choose your main location, add a backup, and give everyone a clear role.',
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
              if (primary.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  primary.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFE7EFE7)),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.tonal(
                    onPressed: () => setState(() => _tab = 1),
                    child: const Text('Open meeting plan'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFB6D0BD)),
                    ),
                    onPressed: () => _downloadPlan(),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Back up plan'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your plan at a glance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _summaryRow(
                Icons.people_outline,
                '${_plan.members.length} group members',
                'See who is bringing each item.',
                3,
              ),
              _summaryRow(
                Icons.place_outlined,
                '${(primary.isSet ? 1 : 0) + (_plan.backup.isSet ? 1 : 0)} of 2 meeting places added',
                'Keep a written address and an optional map pin.',
                1,
              ),
              _summaryRow(
                Icons.assignment_ind_outlined,
                unassigned == 0
                    ? 'Every listed supply has an owner'
                    : '$unassigned supplies need an owner',
                'Assign a person to each item.',
                2,
              ),
              const Divider(height: 24),
              Text(
                'Packing progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _plan.supplies.isEmpty
                      ? 0
                      : packed / _plan.supplies.length,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE7ECE3),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$packed of ${_plan.supplies.length} listed items marked packed',
              ),
            ],
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keep a copy you can take with you.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Download a backup to restore this plan later, or a readable text copy '
                'to keep and print. Browser data can be cleared.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _downloadPlan(readable: true),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Download text plan'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tab = 3),
                    child: const Text('Backup & restore'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Local browser preview. Maps require internet; family syncing, messaging, '
            'and a phone app that reopens offline are still to come.',
            style: TextStyle(color: Color(0xFF59655D), fontSize: 13),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
        'Know where to go.',
        'Keep the location and instructions together.',
      ),
      _placeCard('Primary meeting place', _plan.primary, true),
      _placeCard('Backup meeting place', _plan.backup, false),
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Written details and coordinates are saved in your browser. The map '
          'needs internet and does not show routes, closures, or live hazards.',
        ),
      ),
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
          'Everyone has a part.',
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
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
                              style: const TextStyle(color: Color(0xFF59655D)),
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
      color: attention ? const Color(0xFFFFEFCE) : const Color(0xFFEDF2E8),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: attention ? const Color(0xFF785000) : const Color(0xFF31513D),
      ),
    ),
  );

  Widget _group() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Your people, your plan.',
        'See the group’s assignments and keep a backup of your plan.',
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GROUP NAME',
              style: TextStyle(fontSize: 12, letterSpacing: 1.2),
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
            const Text('Adding a name does not invite or notify anyone.'),
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
        const Text(
          'A backup file keeps your members, meeting places, map pins, supplies, '
          'and packed status. Save it somewhere you can find again.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
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
        const Text(
          'Backup files are ordinary, unencrypted JSON files. They contain the '
          'details you entered; keep them private. They do not include map images.',
          style: TextStyle(fontSize: 12, color: Color(0xFF59655D)),
        ),
        const Divider(height: 32),
        Text('A readable copy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Download a text plan to open in Notepad and print, or copy the text. '
          'Use the JSON backup above when you want to restore into the app.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
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
            'The selected backup was kept during a restore. Download this '
            'copy to keep it, or preview it before trying the restore again.',
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
          const Text(
            'One earlier copy is kept when you upgrade or restore a plan. '
            'It stays in this browser, so keep a downloaded backup as well.',
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
    final pages = [_overview, _meetings, _supplies, _group];
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 3),
        if (_writeError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFFE9BD),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_writeError!),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: pages[_tab](),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
          color: Colors.white,
          child: Text(
            _saveStatus,
            style: TextStyle(
              fontSize: 12,
              color: _dirty ? const Color(0xFF8D4E00) : const Color(0xFF45604F),
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
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Black Box',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(30),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Local prototype v0.2.2 · Not shared',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _loadFailure()
            : Row(
                children: [
                  if (wide)
                    NavigationRail(
                      extended: true,
                      backgroundColor: Colors.white,
                      selectedIndex: _tab,
                      onDestinationSelected: (index) =>
                          setState(() => _tab = index),
                      destinations: List.generate(
                        4,
                        (index) => NavigationRailDestination(
                          icon: Icon(_icons[index]),
                          label: Text(_labels[index]),
                        ),
                      ),
                    ),
                  Expanded(child: _content()),
                ],
              ),
        bottomNavigationBar: !wide && available
            ? NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: List.generate(
                  4,
                  (index) => NavigationDestination(
                    icon: Icon(_icons[index]),
                    label: _labels[index],
                  ),
                ),
              )
            : null,
      );
    },
  );
}
