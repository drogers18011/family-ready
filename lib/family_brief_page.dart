import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'field_surfaces.dart';
import 'plan_models.dart';

/// Edits a draft only. The caller saves the returned value to its selected plan.
class FamilyBriefPage extends StatefulWidget {
  const FamilyBriefPage({
    super.key,
    required this.initial,
    required this.planName,
  });

  final FamilyBrief initial;
  final String planName;

  @override
  State<FamilyBriefPage> createState() => _FamilyBriefPageState();
}

class _FamilyBriefPageState extends State<FamilyBriefPage> {
  final _form = GlobalKey<FormState>();
  late final _outOfAreaName = TextEditingController(
    text: widget.initial.outOfAreaName,
  );
  late final _outOfAreaPhone = TextEditingController(
    text: widget.initial.outOfAreaPhone,
  );
  late final _communication = TextEditingController(
    text: widget.initial.communicationNotes,
  );
  late final _care = TextEditingController(text: widget.initial.careNotes);
  late final _departure = TextEditingController(
    text: widget.initial.departureNotes,
  );
  late final _contacts = widget.initial.contacts
      .map(_ContactDraft.new)
      .toList();
  late final _initialSnapshot = jsonEncode(widget.initial.toJson());
  bool _confirming = false;
  bool _leaving = false;

  Map<String, Object?> get _snapshot => {
    'outOfAreaName': _outOfAreaName.text.trim(),
    'outOfAreaPhone': _outOfAreaPhone.text.trim(),
    'communicationNotes': _communication.text.trim(),
    'careNotes': _care.text.trim(),
    'departureNotes': _departure.text.trim(),
    'contacts': _contacts.map((contact) => contact.toJson()).toList(),
  };

  bool get _dirty => jsonEncode(_snapshot) != _initialSnapshot;
  bool get _blocked => _leaving || _confirming;

  @override
  void dispose() {
    for (final controller in [
      _outOfAreaName,
      _outOfAreaPhone,
      _communication,
      _care,
      _departure,
    ]) {
      controller.dispose();
    }
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  void _finish([FamilyBrief? result]) {
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    // Let PopScope observe the completed decision before leaving the route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop<FamilyBrief>(result);
    });
  }

  Future<void> _requestClose() async {
    if (_blocked || !mounted) return;
    if (!_dirty) {
      _finish();
      return;
    }
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Discard these changes?'),
        content: const Text(
          'Your family information has unsaved changes. '
          'Keep editing to save them, or discard this draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (discard == true) _finish();
  }

  void _save() {
    if (_blocked || !_form.currentState!.validate()) return;
    try {
      _finish(FamilyBrief.fromJson(_snapshot));
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _addContact() {
    if (_blocked || _contacts.length >= FamilyBrief.maxContacts) return;
    setState(() => _contacts.add(_ContactDraft(PlanContact())));
  }

  Future<void> _removeContact(_ContactDraft contact, int number) async {
    if (_blocked) return;
    setState(() => _confirming = true);
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Remove this contact?'),
        content: Text(
          'Remove contact $number from this draft? '
          'Save family information to apply the change to this plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep contact'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove contact'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (remove == true) _contacts.remove(contact);
    });
    if (remove == true) {
      // Release controllers after the removed form fields have unmounted.
      WidgetsBinding.instance.addPostFrameCallback((_) => contact.dispose());
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int limit,
    String? hint,
    bool notes = false,
    bool phone = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_blocked,
      maxLength: limit,
      minLines: notes ? 3 : 1,
      maxLines: notes ? 8 : 1,
      keyboardType: phone
          ? TextInputType.phone
          : (notes ? TextInputType.multiline : TextInputType.text),
      textCapitalization: phone
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: notes,
      ),
      onChanged: (_) => setState(() {}),
      // The model also bounds imported records. This catches unusually long
      // Unicode input before constructing a value, without discarding text.
      validator: (value) => (value ?? '').trim().length > limit
          ? 'This entry is too long. Shorten it before saving.'
          : null,
    ),
  );

  Widget _section(String title, String description, List<Widget> fields) =>
      FieldPanel(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(description),
            ...fields,
          ],
        ),
      );

  Widget _contact(_ContactDraft contact, int number) => Container(
    key: ObjectKey(contact),
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.only(top: 16),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Contact $number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _field(controller: contact.name, label: 'Name', limit: 120),
        _field(
          controller: contact.phone,
          label: 'Phone number',
          limit: 80,
          phone: true,
        ),
        _field(
          controller: contact.role,
          label: 'Role or reason to contact',
          hint: 'For example, school office or neighbor',
          limit: 160,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _blocked ? null : () => _removeContact(contact, number),
            icon: const Icon(Icons.person_remove_outlined),
            label: Text('Remove contact $number'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = theme.textTheme.titleLarge;
    final titleHeight =
        scaler.scale(titleStyle?.fontSize ?? 22) * (titleStyle?.height ?? 1.2) +
        16;
    return PopScope<FamilyBrief>(
      canPop: _leaving || (!_dirty && !_confirming),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: titleHeight > 56 ? titleHeight : 56,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _blocked ? null : _requestClose,
            tooltip: 'Back to plan',
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text(
            'Family information',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              onPressed: _blocked ? null : _save,
              tooltip: 'Save family information',
              icon: const Icon(Icons.save_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FieldBackdrop(
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Form(
                  key: _form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FieldSectionHeading(
                          title: 'Family information',
                          eyebrow: widget.planName,
                          subtitle:
                              'Keep important contacts and responsibilities '
                              'with this plan. Every field is optional.',
                        ),
                        const SizedBox(height: 16),
                        _section(
                          'Out-of-area contact',
                          'A person your group has agreed to contact. '
                              'Write their details here so everyone can find them.',
                          [
                            _field(
                              controller: _outOfAreaName,
                              label: 'Contact name',
                              limit: 120,
                            ),
                            _field(
                              controller: _outOfAreaPhone,
                              label: 'Phone number',
                              limit: 80,
                              phone: true,
                            ),
                          ],
                        ),
                        _section(
                          'Additional contacts',
                          'Add the people or places you want in this plan. '
                              'These entries are separate from your group member list.',
                          [
                            for (var i = 0; i < _contacts.length; i++)
                              _contact(_contacts[i], i + 1),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _blocked ||
                                        _contacts.length >=
                                            FamilyBrief.maxContacts
                                    ? null
                                    : _addContact,
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text('Add contact'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_contacts.length} of ${FamilyBrief.maxContacts} contacts',
                            ),
                          ],
                        ),
                        _section(
                          'Communication notes',
                          'Record what your group has agreed to do if you are separated '
                              'or cannot reach one another.',
                          [
                            _field(
                              controller: _communication,
                              label: 'Your communication plan',
                              limit: FamilyBrief.maxNoteLength,
                              notes: true,
                            ),
                          ],
                        ),
                        _section(
                          'Care and pickup responsibilities',
                          'Write who helps children, pets, or anyone needing assistance, '
                              'and who can take over. Use your own agreed arrangements.',
                          [
                            _field(
                              controller: _care,
                              label: 'People, responsibilities, and backups',
                              limit: FamilyBrief.maxNoteLength,
                              notes: true,
                            ),
                          ],
                        ),
                        _section(
                          'Departure notes',
                          'Keep your agreed departure steps and responsibilities here.',
                          [
                            _field(
                              controller: _departure,
                              label: 'Your departure plan',
                              limit: FamilyBrief.maxNoteLength,
                              notes: true,
                            ),
                          ],
                        ),
                        Text(
                          'This information stays with the selected local plan. '
                          'Its backups and text copies include the details you enter. '
                          'Saving does not contact anyone; a stored phone number '
                          'does not provide service when networks are unavailable.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _blocked ? null : _requestClose,
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              onPressed: _blocked ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save family information'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactDraft {
  _ContactDraft(PlanContact initial)
    : name = TextEditingController(text: initial.name),
      phone = TextEditingController(text: initial.phone),
      role = TextEditingController(text: initial.role);

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController role;

  Map<String, Object?> toJson() => {
    'name': name.text.trim(),
    'phone': phone.text.trim(),
    'role': role.text.trim(),
  };

  void dispose() {
    name.dispose();
    phone.dispose();
    role.dispose();
  }
}
