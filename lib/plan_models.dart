/// Data shared by the local planner, its backup files, and migration checks.
/// This file deliberately has no Flutter or browser dependencies.
const supplyCategories = <String>[
  'Water & food',
  'Health & hygiene',
  'Light & power',
  'Documents & cash',
  'Tools & clothing',
  'Other',
];

class FamilyMember {
  const FamilyMember(this.id, this.name);
  final String id;
  final String name;
  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

/// A contact copied into this plan, independent of the device address book.
class PlanContact {
  factory PlanContact({
    String name = '',
    String phone = '',
    String role = '',
  }) => PlanContact._(
    _briefText(name, 'contact name', 120),
    _briefText(phone, 'contact phone', 80),
    _briefText(role, 'contact role', 160),
  );

  const PlanContact._(this.name, this.phone, this.role);

  final String name;
  final String phone;
  final String role;

  Map<String, Object?> toJson() => {'name': name, 'phone': phone, 'role': role};

  factory PlanContact.fromJson(Object? value) {
    final map = readMap(value);
    return PlanContact(
      name: readString(map, 'name', allowEmpty: true),
      phone: readString(map, 'phone', allowEmpty: true),
      role: readString(map, 'role', allowEmpty: true),
    );
  }
}

/// Optional written information belonging to one plan. The contact list is
/// copied on construction so editing a form cannot mutate the saved value.
class FamilyBrief {
  factory FamilyBrief({
    String outOfAreaName = '',
    String outOfAreaPhone = '',
    String communicationNotes = '',
    String careNotes = '',
    String departureNotes = '',
    List<PlanContact> contacts = const [],
  }) {
    if (contacts.length > maxContacts) {
      throw const FormatException('A family brief has too many contacts.');
    }
    return FamilyBrief._(
      _briefText(outOfAreaName, 'out-of-area contact name', 120),
      _briefText(outOfAreaPhone, 'out-of-area contact phone', 80),
      _briefText(communicationNotes, 'communication notes', maxNoteLength),
      _briefText(careNotes, 'care and pickup notes', maxNoteLength),
      _briefText(departureNotes, 'departure notes', maxNoteLength),
      List<PlanContact>.unmodifiable(contacts),
    );
  }

  const FamilyBrief._(
    this.outOfAreaName,
    this.outOfAreaPhone,
    this.communicationNotes,
    this.careNotes,
    this.departureNotes,
    this.contacts,
  );

  const FamilyBrief.empty()
    : outOfAreaName = '',
      outOfAreaPhone = '',
      communicationNotes = '',
      careNotes = '',
      departureNotes = '',
      contacts = const [];

  static const maxContacts = 30;
  static const maxNoteLength = 3000;

  final String outOfAreaName;
  final String outOfAreaPhone;
  final String communicationNotes;
  final String careNotes;
  final String departureNotes;
  final List<PlanContact> contacts;

  bool get isEmpty =>
      outOfAreaName.isEmpty &&
      outOfAreaPhone.isEmpty &&
      communicationNotes.isEmpty &&
      careNotes.isEmpty &&
      departureNotes.isEmpty &&
      contacts.isEmpty;

  Map<String, Object?> toJson() => {
    'outOfAreaName': outOfAreaName,
    'outOfAreaPhone': outOfAreaPhone,
    'communicationNotes': communicationNotes,
    'careNotes': careNotes,
    'departureNotes': departureNotes,
    'contacts': contacts.map((contact) => contact.toJson()).toList(),
  };

  factory FamilyBrief.fromJson(Object? value) {
    final map = readMap(value);
    final contacts = map['contacts'];
    if (contacts is! List || contacts.length > maxContacts) {
      throw const FormatException('The saved family contact list is invalid.');
    }
    return FamilyBrief(
      outOfAreaName: readString(map, 'outOfAreaName', allowEmpty: true),
      outOfAreaPhone: readString(map, 'outOfAreaPhone', allowEmpty: true),
      communicationNotes: readString(
        map,
        'communicationNotes',
        allowEmpty: true,
      ),
      careNotes: readString(map, 'careNotes', allowEmpty: true),
      departureNotes: readString(map, 'departureNotes', allowEmpty: true),
      contacts: contacts.map(PlanContact.fromJson).toList(),
    );
  }
}

String _briefText(String value, String name, int limit) {
  final text = value.trim();
  if (text.length > limit) {
    throw FormatException('The saved $name exceeds $limit characters.');
  }
  return text;
}

class MeetingPlace {
  const MeetingPlace({
    this.name = '',
    this.address = '',
    this.notes = '',
    this.latitude,
    this.longitude,
  });

  final String name;
  final String address;
  final String notes;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isSet =>
      name.isNotEmpty ||
      address.isNotEmpty ||
      notes.isNotEmpty ||
      hasCoordinates;

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'notes': notes,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory MeetingPlace.fromJson(Object? value) {
    final map = readMap(value);
    final latitude = _readCoordinate(map['latitude'], 'latitude', 90);
    final longitude = _readCoordinate(map['longitude'], 'longitude', 180);
    if ((latitude == null) != (longitude == null)) {
      throw const FormatException(
        'A meeting pin must contain both latitude and longitude.',
      );
    }
    return MeetingPlace(
      name: readString(map, 'name', allowEmpty: true),
      address: readString(map, 'address', allowEmpty: true),
      notes: readString(map, 'notes', allowEmpty: true),
      latitude: latitude,
      longitude: longitude,
    );
  }
}

double? _readCoordinate(Object? value, String name, double limit) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < -limit || value > limit) {
    throw FormatException('The saved $name is invalid.');
  }
  return value.toDouble();
}

class Supply {
  Supply(
    this.id,
    this.name, {
    this.assignedTo,
    this.packed = false,
    this.quantity = '',
    this.category = 'Other',
    this.notes = '',
  });

  final String id;
  String name;
  String? assignedTo;
  bool packed;
  String quantity;
  String category;
  String notes;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'assignedTo': assignedTo,
    'packed': packed,
    'quantity': quantity,
    'category': category,
    'notes': notes,
  };
}

Map<String, dynamic> readMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a saved object.');
  }
  return value;
}

String readString(
  Map<String, dynamic> map,
  String key, {
  bool allowEmpty = false,
}) {
  final value = map[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('Invalid saved field: $key.');
  }
  return value;
}

String _readOptionalString(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  if (!map.containsKey(key)) return fallback;
  return readString(map, key, allowEmpty: true);
}

class GroupPlan {
  GroupPlan({
    required this.groupName,
    required this.members,
    required this.supplies,
    this.primary = const MeetingPlace(),
    this.backup = const MeetingPlace(),
    this.familyBrief = const FamilyBrief.empty(),
    this.savedAt,
  });

  String groupName;
  final List<FamilyMember> members;
  final List<Supply> supplies;
  MeetingPlace primary;
  MeetingPlace backup;
  FamilyBrief familyBrief;
  DateTime? savedAt;

  factory GroupPlan.sample() => GroupPlan(
    groupName: 'My preparedness group',
    members: const [
      FamilyMember('you', 'You'),
      FamilyMember('alex', 'Alex'),
      FamilyMember('sam', 'Sam'),
    ].toList(),
    supplies: [
      Supply('water', 'Water', assignedTo: 'you', category: 'Water & food'),
      Supply(
        'light',
        'Flashlight',
        assignedTo: 'alex',
        category: 'Light & power',
      ),
      Supply('charger', 'Phone charger', category: 'Light & power'),
    ],
  );

  Map<String, Object?> toJson(DateTime savedAt) => {
    'version': 3,
    'groupName': groupName,
    'members': members.map((member) => member.toJson()).toList(),
    'primary': primary.toJson(),
    'backup': backup.toJson(),
    'familyBrief': familyBrief.toJson(),
    'supplies': supplies.map((item) => item.toJson()).toList(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory GroupPlan.fromJson(Object? value) {
    final map = readMap(value);
    final version = map['version'];
    if (version is! int || (version != 1 && version != 2 && version != 3)) {
      throw const FormatException(
        'This saved plan uses an unsupported version.',
      );
    }
    final rawMembers = map['members'];
    final rawSupplies = map['supplies'];
    if (rawMembers is! List || rawMembers.isEmpty || rawSupplies is! List) {
      throw const FormatException(
        'The saved group or supply list is incomplete.',
      );
    }
    final members = <FamilyMember>[];
    final memberIds = <String>{};
    final names = <String>{};
    for (final value in rawMembers) {
      final entry = readMap(value);
      final id = readString(entry, 'id');
      final name = readString(entry, 'name');
      if (!memberIds.add(id) || !names.add(name.trim().toLowerCase())) {
        throw const FormatException(
          'The saved group contains duplicate members.',
        );
      }
      members.add(FamilyMember(id, name));
    }
    final supplies = <Supply>[];
    final supplyIds = <String>{};
    for (final value in rawSupplies) {
      final entry = readMap(value);
      final id = readString(entry, 'id');
      final packed = entry['packed'];
      final assignedTo = entry['assignedTo'];
      if (!supplyIds.add(id) ||
          packed is! bool ||
          (assignedTo != null && assignedTo is! String)) {
        throw const FormatException('A saved supply item is invalid.');
      }
      final category = _readOptionalString(
        entry,
        'category',
        fallback: 'Other',
      );
      if (!supplyCategories.contains(category)) {
        throw const FormatException(
          'A saved supply category is not supported.',
        );
      }
      supplies.add(
        Supply(
          id,
          readString(entry, 'name'),
          assignedTo: memberIds.contains(assignedTo)
              ? assignedTo as String
              : null,
          packed: packed,
          quantity: _readOptionalString(entry, 'quantity'),
          category: category,
          notes: _readOptionalString(entry, 'notes'),
        ),
      );
    }
    final savedAt = DateTime.tryParse(readString(map, 'savedAt'));
    if (savedAt == null) {
      throw const FormatException('The saved date is invalid.');
    }
    return GroupPlan(
      groupName: readString(map, 'groupName'),
      members: members,
      supplies: supplies,
      primary: MeetingPlace.fromJson(map['primary']),
      backup: MeetingPlace.fromJson(map['backup']),
      familyBrief: version == 3
          ? FamilyBrief.fromJson(map['familyBrief'])
          : const FamilyBrief.empty(),
      savedAt: savedAt,
    );
  }
}

/// A plain-text copy that can be opened or printed without this app.
String readablePlanText(GroupPlan plan, {required String saveStatus}) {
  final output = StringBuffer()
    ..writeln('BLACK BOX — PLAN COPY')
    ..writeln(plan.groupName)
    ..writeln(saveStatus)
    ..writeln('Local prototype. Changes are not sent to other group members.')
    ..writeln('\nGROUP')
    ..writeln(plan.members.map((member) => member.name).join(', '));

  void place(String label, MeetingPlace location) {
    output.writeln('\n$label');
    if (!location.isSet) {
      output.writeln('Not set');
      return;
    }
    if (location.name.isNotEmpty) output.writeln(location.name);
    if (location.address.isNotEmpty) output.writeln(location.address);
    if (location.hasCoordinates) {
      output.writeln(
        'Map pin: ${location.latitude!.toStringAsFixed(6)}, '
        '${location.longitude!.toStringAsFixed(6)}',
      );
    }
    if (location.notes.isNotEmpty) output.writeln(location.notes);
  }

  place('PRIMARY MEETING PLACE', plan.primary);
  place('BACKUP MEETING PLACE', plan.backup);
  final brief = plan.familyBrief;
  output.writeln('\nFAMILY INFORMATION');
  if (brief.isEmpty) {
    output.writeln('No family information added yet.');
  } else {
    if (brief.outOfAreaName.isNotEmpty || brief.outOfAreaPhone.isNotEmpty) {
      output.writeln('Out-of-area contact: ${brief.outOfAreaName}');
      if (brief.outOfAreaPhone.isNotEmpty) {
        output.writeln('Phone: ${brief.outOfAreaPhone}');
      }
    }
    for (var i = 0; i < brief.contacts.length; i++) {
      final contact = brief.contacts[i];
      output.writeln('Contact ${i + 1}: ${contact.name}');
      if (contact.phone.isNotEmpty) output.writeln('Phone: ${contact.phone}');
      if (contact.role.isNotEmpty) output.writeln('Role: ${contact.role}');
    }
    if (brief.communicationNotes.isNotEmpty) {
      output.writeln('Communication notes: ${brief.communicationNotes}');
    }
    if (brief.careNotes.isNotEmpty) {
      output.writeln('Care and pickup responsibilities: ${brief.careNotes}');
    }
    if (brief.departureNotes.isNotEmpty) {
      output.writeln('Departure notes: ${brief.departureNotes}');
    }
  }
  output.writeln('\nSUPPLIES');
  if (plan.supplies.isEmpty) output.writeln('No supplies added yet.');
  final names = {for (final member in plan.members) member.id: member.name};
  for (final item in plan.supplies) {
    final quantity = item.quantity.isEmpty ? '' : ' (${item.quantity})';
    output.writeln(
      '${item.packed ? '[x]' : '[ ]'} ${item.name}$quantity '
      '— ${names[item.assignedTo] ?? 'Unassigned'}',
    );
    output.writeln('    Category: ${item.category}');
    if (item.notes.isNotEmpty) output.writeln('    Notes: ${item.notes}');
  }
  output.writeln(
    '\nThis is a point-in-time copy. Map imagery and live messaging are not '
    'included. Keep a current copy with everyone who needs the plan.',
  );
  return output.toString();
}
