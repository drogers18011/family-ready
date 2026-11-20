BLACK BOX - VERSION 0.2.2
========================
Prepared for Dennis Rogers, November 20, 2026

RENAMED TO BLACK BOX
--------------------
The app previously called Family Ready is now Black Box. This update changes
the app heading, browser title, iPhone display name, Windows launcher, backup
picker labels, downloaded filenames, and printable plan heading.

Existing saved plans and JSON backups use the same data format and storage
keys. Continue using your normal Chrome profile at http://127.0.0.1:54321.
Older Family Ready JSON backups remain supported.

Upload the contents of the extracted black_box_starter.zip into the existing
family-ready GitHub repository on the same build branch. Keep lib, scripts,
test, and web as folders beside pubspec.yaml and codemagic.yaml. In particular,
scripts/configure_ios.py applies the new iPhone display name during a build.

The existing package, repository, storage, and build identifiers retain their
original family_ready/family-ready names. The proposed Apple bundle identifier
remains com.dennisrogers.familyready. These technical names are separate from
the visible Black Box name and keep the working setup consistent.

CURRENT STATUS
---------------
You reported a green unsigned iPhone compile check for version 0.2.1. Your
Apple Developer enrollment is pending as of November 20. The next account step
is Apple signing and TestFlight after the membership becomes active.

Monetization is a later product milestone. Current priorities are installation
on the test iPhone, reliable saved plans, and real offline maps and directions.

FLUTTER 3.50 BUILD FIX
----------------------
Version 0.2.1 replaces the three deprecated Flutter Material imports with the
official material_ui 1.11.1 package and adds its compatibility bridge for
dependencies. It requires Flutter 3.47 / Dart 3.13 or later; your Flutter
3.50.0 / Dart 3.14.0 setup meets those requirements.

That Material migration passed your unsigned Codemagic build and remains part
of this package. Strict analysis and the existing data checks remain enabled.

IPHONE BUILD SETUP ADDED
------------------------
For your iPhone 16 Pro Max and Windows-only development setup, start with
START_IPHONE_CLOUD.txt. The included Codemagic workflows prepare the current
v0.2.2 app for an unsigned iOS compile check and, after your Apple account setup,
an internal TestFlight build. Offline routing is the next functional milestone.
If v0.2 is already working in Chrome, continue with that cloud guide; you do
not need to repeat the browser installation steps below.


This update builds on the first Flutter browser prototype you successfully ran
on your Windows PC. It keeps the green-and-cream design and adds real online
meeting-point selection, better supply organization, and backup/restore files.

UPDATE FROM YOUR FIRST VERSION
------------------------------
1. If you entered anything worth keeping in the first version, use Group >
   Copy plan and paste that text into Notepad as an extra copy.
2. Click the running app's terminal window and press q to stop it. Close
   its browser tab too.
3. Download black_box_starter.zip. Choose Extract All and use a NEW folder,
   such as Documents\BlackBox_v022. Keep your old source folder.
4. Open the extracted folder containing START_HERE.cmd and pubspec.yaml.
5. Double-click START_HERE.cmd and keep its terminal window open. It downloads
   the added Flutter packages and compiles the updated app; internet is needed.
6. When the terminal says the app is being served, open your normal Chrome
   profile and go to this exact address:

   http://127.0.0.1:54321

7. Confirm the app shows Black Box and v0.2.2. If the old screen is still visible,
   press Ctrl+Shift+R to reload it. Do NOT clear site data.
8. Check that any plan you saved in the first version is still there. Then
   open Group > Download backup and keep the downloaded JSON file.

The project folder can change. Browser data belongs to the browser profile
and exact website address, so the URL and profile must stay the same. Using
localhost instead of 127.0.0.1, changing ports, using private browsing, or
clearing browser data can make the earlier plan unavailable.

Use one Black Box browser tab while editing. The prototype does not
coordinate edits between multiple tabs or devices.

WHAT IS NEW
-----------
MEETING POINTS
- Primary and backup meeting places still have a name, written address, and
  meeting instructions.
- Choose map pin opens an interactive OpenStreetMap map. Pan and zoom, then
  click a point and choose Use selected pin.
- You can also enter decimal latitude/longitude, press Use coordinates, then
  choose Use selected pin. Existing written details are preserved.
- Edit meeting place lets you change written details, change/remove its pin,
  or cancel without saving the draft.
- Choosing a map pin does not look up an address. Typing an address does not
  move the pin. Check that both identify the same place.

SUPPLIES
- Each item has a quantity, category, person responsible, optional notes,
  and packed checkbox. Quantity is free text, for example "2 flashlights".
- Search by item, person, quantity, category, or notes.
- Filter All, To pack, Unassigned, or Packed; narrow by category or person.
- The overview shows the main meeting place, assignments, and packing counts.
- The group roster shows each person's assigned and packed item counts.
- Removing a member keeps their supplies and marks them unassigned.
- Removing a supply asks you to confirm which item will be removed.

BACKUPS AND READABLE COPIES
- Download backup creates a JSON file containing your whole plan: members,
  locations, coordinates, supplies, quantities, assignments, notes, and checks.
- Restore backup validates the file and shows its group name and counts before
  you decide whether to replace the current plan. It does not merge two plans.
- A previous local copy is retained during upgrade/restore. A separate recovery
  copy protects the selected backup if a restore is interrupted or a write fails.
- Group provides preview/download controls when those local copies are present.
- Download text plan creates a readable .txt file you can open in Notepad and
  print with Ctrl+P. Copy plan text is also available.
- Text copies are for reading and printing. Restore backup accepts the JSON
  backup, up to 2 MiB. JSON files are plain and unencrypted; keep them private.
- A browser download message means the download was requested. Check Chrome's
  Downloads list and confirm the file exists where you expect.

A QUICK WALKTHROUGH
-------------------
1. Open Meeting plan. Add a sample name/address, choose a map pin, and save.
2. Do the same for the backup location.
3. Open Supplies. Add "Flashlight", quantity "2", category "Light & power",
   assign someone, and add a note such as "Hall cupboard".
4. Mark it packed and try the filters. Use Clear filters to show everything.
5. Wait for the saved status, refresh the page, and check that the fields remain.
6. Open Group > Download backup. Check the downloaded file is present.
7. To try restore safely, change one sample item, then select the backup file.
   Review the preview and choose Replace current plan. Confirm the older value
   comes back. Group > Preview previous copy lets you review the replaced plan.
8. Download a text plan and open it in Notepad to inspect the readable copy.

WHAT WORKS OFFLINE, AND WHAT IS STILL BEING BUILT
------------------------------------------------
The current browser prototype stores written plan details and coordinates in
this browser. It runs from the development server on your Windows computer.
This is not yet an installed phone app with verified offline startup.

The interactive map uses online OpenStreetMap tiles. It has no offline map
package, address search, directions, road closures, or live hazard information.
Its tile service allows ordinary interactive viewing but prohibits bulk/offline
map downloading. This prototype requests only the area you actively view.
The JSON backup stores pin coordinates, not map imagery.

There are no shared accounts, invitations, family synchronization, live member
locations, messages, or built-in survival guides in this version. Adding a name
only changes the roster in this browser. A save time is not a synchronization
time or evidence that another person's device has received your plan.

The native emergency app still needs durable local storage, a map provider
that permits offline packages, per-device download/sync status, and actual
phone restart tests in airplane mode. This prototype is for development and
feedback, not emergency reliance.

STARTER AND DEVELOPMENT DETAILS
-------------------------------
START_HERE.cmd uses the installation locations we already confirmed on your PC:
  Git:     %LOCALAPPDATA%\Programs\Git\cmd
  Flutter: %USERPROFILE%\Desktop\flutter\bin

It adds them only to the current launcher's PATH, preserving existing entries.
It does not reinstall your tools or change permanent Windows settings.

Your Flutter 3.50.0 / Dart 3.14.0 setup is sufficient for this browser target.
The missing Android SDK and Visual Studio C++ desktop tools do not block it.
The Windows launcher still uses the web target. The cloud build workflow now
generates an isolated iOS host on the hosted Mac for initial device testing.

To run manually from the project folder in VS Code's PowerShell terminal:

$env:Path = "$env:LOCALAPPDATA\Programs\Git\cmd;$env:USERPROFILE\Desktop\flutter\bin;$env:Path"
flutter pub get
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=54321

Then open http://127.0.0.1:54321 in your normal Chrome window.

The same original browser storage key is retained. Version 1 plans remain
readable; new writes use version 2. Before the first version-2 save, the exact
old stored record is retained as the previous copy. Opening an old source
version after upgrading is not a supported downgrade path: the old code cannot
read version-2 plans. Keep the updated code with your downloaded backups.

The prototype still uses shared_preferences for local sample data. Its
maintainers do not recommend it for critical data; native storage will be
replaced and tested before an emergency-ready release.

PROJECT FILES
-------------
lib/main.dart          Screens, local saving, backup preview, and recovery UI.
lib/plan_models.dart   Data model, version migration, validation, readable export.
lib/plan_dialogs.dart  Meeting-place and supply editors.
lib/meeting_map.dart   Interactive online map and coordinate picker.
lib/plan_files.dart    File import, browser download, and desktop save helpers.
lib/plan_store.dart    Restore journal and ordered persistence writes.
test/                  Pure Dart model/migration and restore-failure checks.
pubspec.yaml           Version and pinned direct dependencies.
web/index.html         Browser entry point.
START_HERE.cmd         Windows launcher.
README.txt             Browser prototype guide.
START_IPHONE_CLOUD.txt  Windows-to-iPhone build and TestFlight instructions.
codemagic.yaml         Manual unsigned and signed iOS build workflows.
scripts/               Isolated native-project preparation and build helpers.

Flutter creates dependency and build files when you launch the project. The
archive does not include an invented dependency lockfile or compiled app.

IF SOMETHING STOPS
------------------
- Port 54321 already in use: stop the previous launcher, then try again. Keep
  the same port so browser storage remains accessible.
- Cannot find Git or Flutter: send the error and your installation folder.
- Package/compiler error: copy the FIRST error and the lines just below it.
- Map fails to load: check internet access or enter coordinates manually.
- Save fails: keep the page open; retry saving or download/copy the current
  plan. The status distinguishes unsaved edits from a completed local save.
- Restore fails: keep the page open. Check Group for a Recovery copy and
  download it. An interrupted restore must not discard the selected backup.
- Saved plan cannot load: download/copy the stored data before attempting
  recovery; the error screen also offers available previous/recovery copies.
- Browser still shows the first version: close the old app tab, check that the
  new folder's launcher is running, and hard-refresh the exact URL above.

VERIFICATION
------------
You confirmed that version 0.2 looks good and works on your Windows computer.
During preparation, all Dart sources were parsed/formatted, the pure data models
passed static analysis and 62 migration/model/roundtrip checks, and map/file APIs were
checked against their official packages. Restore writes also have injected
failure checks: all six tested scenarios retained the required current/recovery data.

A full Flutter build/browser test has not run in the preparation environment. Automatic approval review previously rejected Flutter startup
because it attempted to contact a cloud instance metadata endpoint. That
blocked path was not retried or bypassed. Your earlier Windows run provides
the v0.2 browser check. You subsequently reported a green ios-compile-check
run for v0.2.1, covering its configured analysis, data checks, and unsigned
iPhone compilation. This v0.2.2 branding update has source-scope, syntax, and
format checks. Its display changes will be verified in your next ordinary
browser/cloud build. Installation and behavior on the physical iPhone still
need testing after Apple signing is configured.

Optional developer checks (after Dart is available in your terminal):
  dart test/plan_models_check.dart
  dart test/plan_store_check.dart

NEXT DEVELOPMENT MILESTONE
--------------------------
After checking this update's screens and backup flow, move the plan onto an
installed phone app with durable local storage. Verify a complete phone-app
restart in airplane mode before adding family accounts/sync and offline map
packages. Messaging must clearly distinguish queued and delivered messages.
Later, consider a paid product or premium features after validating the core
preparedness experience. No monetization model has been selected yet.

PRIMARY TECHNICAL REFERENCES
----------------------------
Flutter browser setup and run:
https://docs.flutter.dev/platform-integration/web/setup
https://docs.flutter.dev/platform-integration/web/building
Flutter offline-first architecture:
https://docs.flutter.dev/app-architecture/design-patterns/offline-first
Flutter Material migration and package:
https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
https://pub.dev/packages/material_ui/versions/1.11.1
Map package and OpenStreetMap tile policy:
https://pub.dev/packages/flutter_map/versions/8.3.2
https://operations.osmfoundation.org/policies/tiles/
File APIs:
https://pub.dev/packages/file_selector/versions/1.1.0
https://pub.dev/packages/cross_file/versions/0.3.5%2B5
Local preferences limitations:
https://pub.dev/packages/shared_preferences
