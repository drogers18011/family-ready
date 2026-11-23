import 'dart:convert';

import '../lib/plan_models.dart';

// Run with: dart test/plan_models_check.dart
// This small check runner needs neither Flutter nor third-party test packages.
int _checks = 0;

void check(bool condition, String description) {
  _checks++;
  if (!condition) throw StateError('FAILED: $description');
}

void rejects(Object? value, String description) {
  var rejected = false;
  try {
    GroupPlan.fromJson(value);
  } on FormatException {
    rejected = true;
  }
  check(rejected, description);
}

Map<String, dynamic> legacyFixture() => jsonDecode('''
{
  "version": 1,
  "groupName": "Rogers family",
  "members": [
    {"id": "you", "name": "Dennis"},
    {"id": "alex", "name": "Alex"}
  ],
  "primary": {
    "name": "Library",
    "address": "123 Main Street",
    "notes": "Meet at the west entrance."
  },
  "backup": {
    "name": "",
    "address": "Park entrance",
    "notes": "Use only if our primary place is inaccessible."
  },
  "supplies": [
    {"id": "water", "name": "Water — 2 jugs", "assignedTo": "you", "packed": true},
    {"id": "light", "name": "Flashlight", "assignedTo": null, "packed": false}
  ],
  "savedAt": "2026-11-18T10:15:00.000Z"
}
''') as Map<String, dynamic>;

Map<String, dynamic> currentFixture() => jsonDecode(
  jsonEncode(
    GroupPlan.fromJson(legacyFixture()).toJson(DateTime.utc(2026, 11, 22)),
  ),
) as Map<String, dynamic>;

void main() {
  final legacy = legacyFixture();
  final before = jsonEncode(legacy);
  final migrated = GroupPlan.fromJson(legacy);
  check(
    migrated.groupName == 'Rogers family',
    'legacy group name is preserved',
  );
  check(migrated.members[0].name == 'Dennis', 'legacy names are preserved');
  check(
    migrated.members[1].id == 'alex',
    'legacy member identifiers are preserved',
  );
  check(migrated.primary.name == 'Library', 'legacy meeting name is preserved');
  check(
    migrated.primary.address == '123 Main Street',
    'legacy address is preserved',
  );
  check(
    migrated.primary.notes == 'Meet at the west entrance.',
    'legacy instructions are preserved',
  );
  check(
    migrated.backup.address == 'Park entrance',
    'legacy backup is preserved',
  );
  check(
    migrated.supplies[0].name == 'Water — 2 jugs',
    'quantities embedded in old names remain intact',
  );
  check(
    migrated.supplies[0].assignedTo == 'you',
    'legacy assignment is preserved',
  );
  check(migrated.supplies[0].packed, 'legacy packed state is preserved');
  check(!migrated.supplies[1].packed, 'legacy unpacked state is preserved');
  check(
    migrated.supplies[1].assignedTo == null,
    'legacy unassigned state is preserved',
  );
  check(
    migrated.supplies[0].quantity.isEmpty,
    'migration does not invent quantities',
  );
  check(
    migrated.supplies[0].category == 'Other',
    'legacy category defaults safely',
  );
  check(
    migrated.supplies[0].notes.isEmpty,
    'legacy supply notes default safely',
  );
  check(!migrated.primary.hasCoordinates, 'migration does not invent a pin');
  check(
    migrated.savedAt == DateTime.utc(2026, 11, 18, 10, 15),
    'original save time is preserved',
  );
  check(
    jsonEncode(legacy) == before,
    'migration does not mutate imported data',
  );
  check(
    migrated.familyBrief.isEmpty,
    'schema 1 starts with an empty family brief',
  );
  final oldV2 = legacyFixture()..['version'] = 2;
  check(
    GroupPlan.fromJson(oldV2).familyBrief.isEmpty,
    'schema 2 starts with an empty family brief',
  );
  check(
    GroupPlan.sample().familyBrief.isEmpty,
    'sample family details are not invented',
  );

  migrated.primary = const MeetingPlace(
    name: 'North gate',
    address: 'Park entrance',
    notes: 'Use the marked footpath.',
    latitude: 40.7128,
    longitude: -74.006,
  );
  migrated.backup = const MeetingPlace(latitude: 0, longitude: 0);
  migrated.supplies[0]
    ..quantity = '2 jugs'
    ..category = 'Water & food'
    ..notes = 'Stored on the lower shelf.';
  final timestamp = DateTime.utc(2026, 11, 18, 12, 30);
  final encoded = jsonEncode(migrated.toJson(timestamp));
  final roundtrip = GroupPlan.fromJson(jsonDecode(encoded));
  check(
    jsonDecode(encoded)['version'] == 3,
    'new backups declare schema version 3',
  );
  check(
    jsonEncode(roundtrip.toJson(timestamp)) == encoded,
    'all existing fields round-trip exactly in schema 3',
  );
  check(roundtrip.primary.hasCoordinates, 'coordinates survive a round-trip');
  check(
    roundtrip.backup.hasCoordinates && roundtrip.backup.isSet,
    'zero coordinates are valid',
  );
  check(
    roundtrip.savedAt == timestamp,
    'updated save time survives a round-trip',
  );

  final originalContacts = <PlanContact>[
    PlanContact(
      name: ' School office ',
      phone: ' +1 (555) 010-0200 ext 2 ',
      role: ' Pickup contact ',
    ),
    PlanContact(name: 'Neighbor', phone: '', role: 'Pet pickup backup'),
  ];
  roundtrip.familyBrief = FamilyBrief(
    outOfAreaName: ' Aunt Morgan ',
    outOfAreaPhone: ' +1 555 010 0300 ',
    communicationNotes:
        ' Check with our agreed contact.\nUse the written backup plan. ',
    careNotes: ' Chris handles pickup. Pat is the backup. ',
    departureNotes: ' Sam brings the carriers. ',
    contacts: originalContacts,
  );
  final brief = roundtrip.familyBrief;
  originalContacts.clear();
  check(
    brief.contacts.length == 2,
    'family brief copies the caller contact list',
  );
  var cannotMutate = false;
  try {
    brief.contacts.clear();
  } on UnsupportedError {
    cannotMutate = true;
  }
  check(
    cannotMutate,
    'family brief contacts cannot be mutated through the getter',
  );
  check(brief.outOfAreaName == 'Aunt Morgan', 'family input is trimmed');
  check(
    brief.contacts.first.name == 'School office',
    'contact input is trimmed',
  );
  check(
    brief.contacts.first.phone == '+1 (555) 010-0200 ext 2',
    'phone formatting and extensions survive',
  );
  check(
    brief.communicationNotes.contains('\n'),
    'multiline family notes survive',
  );
  check(!brief.isEmpty, 'a filled family brief reports present information');
  final familyEncoded = jsonEncode(roundtrip.toJson(timestamp));
  final familyRestored = GroupPlan.fromJson(jsonDecode(familyEncoded));
  check(
    jsonEncode(familyRestored.toJson(timestamp)) == familyEncoded,
    'schema 3 restores every family field and contact without loss',
  );
  check(
    familyRestored.familyBrief.contacts[1].phone.isEmpty,
    'optional contact fields remain empty',
  );
  check(
    !identical(familyRestored.familyBrief.contacts, brief.contacts),
    'JSON copy creates an independent contact list',
  );
  check(
    FamilyBrief.fromJson(const FamilyBrief.empty().toJson()).isEmpty,
    'empty family information is valid',
  );
  final blankContact = FamilyBrief(contacts: [PlanContact()]);
  check(
    FamilyBrief.fromJson(blankContact.toJson()).contacts.length == 1,
    'an all-optional contact is preserved rather than silently dropped',
  );

  final text = readablePlanText(roundtrip, saveStatus: 'Saved locally');
  check(text.contains('Rogers family'), 'text plan includes the group');
  check(
    text.contains('40.712800, -74.006000'),
    'text plan includes the map pin',
  );
  check(
    text.contains('[x] Water — 2 jugs (2 jugs) — Dennis'),
    'text plan includes quantity, person, and packed status',
  );
  check(
    text.contains('Stored on the lower shelf.'),
    'text plan includes supply notes',
  );
  check(
    !text.contains('Sample information'),
    'text copy does not mislabel user data as samples',
  );
  for (final detail in [
    'Aunt Morgan',
    '+1 555 010 0300',
    'School office',
    '+1 (555) 010-0200 ext 2',
    'Pickup contact',
    'Pet pickup backup',
    'Check with our agreed contact.',
    'Chris handles pickup. Pat is the backup.',
    'Sam brings the carriers.',
  ]) {
    check(
      text.contains(detail),
      'readable plan includes family detail: $detail',
    );
  }

  final dangling = legacyFixture();
  dangling['supplies'][0]['assignedTo'] = 'removed-member';
  check(
    GroupPlan.fromJson(dangling).supplies[0].assignedTo == null,
    'missing member references become unassigned without deleting the item',
  );

  for (final version in <Object?>[0, 4, '2', 2.0, 3.0, null]) {
    final value = legacyFixture()..['version'] = version;
    rejects(value, 'unsupported version $version is rejected');
  }
  rejects(null, 'null input is rejected');
  rejects([], 'list input is rejected');
  rejects(legacyFixture()..['members'] = [], 'an empty group is rejected');
  rejects(
    legacyFixture()..['members'] = 'people',
    'a malformed members list is rejected',
  );
  rejects(
    legacyFixture()..['supplies'] = null,
    'a missing supply list is rejected',
  );
  rejects(
    legacyFixture()..['groupName'] = ' ',
    'a blank group name is rejected',
  );
  rejects(
    legacyFixture()..['savedAt'] = 'yesterday',
    'an invalid date is rejected',
  );
  rejects(
    legacyFixture()..['primary'] = null,
    'a missing meeting object is rejected',
  );

  final duplicateId = legacyFixture();
  duplicateId['members'][1]['id'] = 'you';
  rejects(duplicateId, 'duplicate member IDs are rejected');
  final duplicateName = legacyFixture();
  duplicateName['members'][1]['name'] = ' DENNIS ';
  rejects(duplicateName, 'duplicate member names ignore case and whitespace');
  final duplicateSupply = legacyFixture();
  duplicateSupply['supplies'][1]['id'] = 'water';
  rejects(duplicateSupply, 'duplicate supply IDs are rejected');
  final invalidPacked = legacyFixture();
  invalidPacked['supplies'][0]['packed'] = 'true';
  rejects(invalidPacked, 'packed must be a boolean');
  final invalidAssignment = legacyFixture();
  invalidAssignment['supplies'][0]['assignedTo'] = 1;
  rejects(invalidAssignment, 'assigned member must be a string or null');

  for (final field in ['quantity', 'category', 'notes']) {
    final value = legacyFixture()..['version'] = 2;
    value['supplies'][0][field] = null;
    rejects(value, '$field cannot be null when supplied');
  }
  final invalidCategory = legacyFixture();
  invalidCategory['supplies'][0]['category'] = 'Unknown category';
  rejects(
    invalidCategory,
    'unknown categories cannot break dropdown selection',
  );

  for (final coordinates in <List<Object?>>[
    [91, 0],
    [-91, 0],
    [0, 181],
    [0, -181],
    [double.nan, 0],
    [0, double.infinity],
    ['40', -74],
    [40, null],
    [null, -74],
  ]) {
    final value = legacyFixture()..['version'] = 2;
    value['primary']['latitude'] = coordinates[0];
    value['primary']['longitude'] = coordinates[1];
    rejects(value, 'invalid coordinate pair $coordinates is rejected');
  }
  final bounds = legacyFixture();
  bounds['primary']['latitude'] = -90;
  bounds['primary']['longitude'] = 180;
  check(
    GroupPlan.fromJson(bounds).primary.hasCoordinates,
    'valid coordinate bounds are accepted',
  );

  final noSupplies = legacyFixture()..['supplies'] = [];
  check(
    GroupPlan.fromJson(noSupplies).supplies.isEmpty,
    'an empty supply list is valid',
  );

  rejects(
    currentFixture()..remove('familyBrief'),
    'schema 3 requires its family brief',
  );
  for (final invalid in <Object?>[null, [], 'notes']) {
    rejects(
      currentFixture()..['familyBrief'] = invalid,
      'malformed family brief $invalid is rejected',
    );
  }
  for (final field in [
    'outOfAreaName',
    'outOfAreaPhone',
    'communicationNotes',
    'careNotes',
    'departureNotes',
  ]) {
    final absent = currentFixture();
    absent['familyBrief'].remove(field);
    rejects(absent, 'missing family field $field is rejected');
    final invalid = currentFixture();
    invalid['familyBrief'][field] = 17;
    rejects(invalid, 'non-string family field $field is rejected');
  }
  for (final invalid in <Object?>[
    null,
    'contacts',
    [null],
    [17],
    [<String, dynamic>{}],
  ]) {
    final value = currentFixture();
    value['familyBrief']['contacts'] = invalid;
    rejects(value, 'malformed contact list $invalid is rejected');
  }
  for (final field in ['name', 'phone', 'role']) {
    final value = currentFixture();
    value['familyBrief']['contacts'] = [PlanContact(name: 'Valid').toJson()];
    value['familyBrief']['contacts'][0][field] = null;
    rejects(
      value,
      'invalid contact $field is rejected without dropping the contact',
    );
  }
  final tooMany = currentFixture();
  tooMany['familyBrief']['contacts'] = List.generate(
    FamilyBrief.maxContacts + 1,
    (_) => PlanContact(name: 'Person').toJson(),
  );
  rejects(tooMany, 'oversized contact list is rejected');
  final tooLong = currentFixture();
  tooLong['familyBrief']['careNotes'] = 'x' * (FamilyBrief.maxNoteLength + 1);
  rejects(tooLong, 'oversized family notes are rejected');
  final longContact = currentFixture();
  longContact['familyBrief']['contacts'] = [
    {'name': 'x' * 121, 'phone': '', 'role': ''},
  ];
  rejects(longContact, 'oversized contact fields are rejected');
  final missingContacts = currentFixture();
  missingContacts['familyBrief'].remove('contacts');
  rejects(missingContacts, 'missing schema 3 contact list is rejected');
  final completeEmpty = GroupPlan.fromJson(currentFixture());
  check(
    completeEmpty.familyBrief.isEmpty,
    'explicit empty schema 3 brief is accepted',
  );
  print('Passed $_checks model, migration, backup, and validation checks.');
}
