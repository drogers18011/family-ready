import 'package:shared_preferences/shared_preferences.dart';

import 'personal_packlist_models.dart';
export 'personal_packlist_models.dart';

/// One queue and working draft are shared by My pack and Suggested items.
/// No account, Amazon identifier, or link history is stored here.
final _personalPreferences = SharedPreferencesAsync();
final personalPacklistStore = PersonalPacklistStore(
  read: _personalPreferences.getString,
  write: _personalPreferences.setString,
);
