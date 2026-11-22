BLACK BOX - VERSION 0.8.0+11
==========================
Updated for Dennis Rogers, November 22, 2026

HELP AND QUICK TOUR
--------------------
This release adds instructions inside the app. Home offers a Get started with
Black Box card with Start quick tour and Not now. You can keep using the app
without taking the tour. The six short chapters explain the group plan,
meeting places, packing lists, saved guides, offline practice, and plan copies.
Use Back, Next, or Skip; the last chapter offers Done or Open Plan.

The question-mark button in the header opens Help & tutorial whenever you
need it. Search ten topics, expand one for numbered instructions, and use its
Open button to go to that part of the app. Choose Quick tour to replay the
introduction. The header keeps three shortcuts: guides, Light/Dark, and Help.
Appearance is now inside Help; About Black Box & licenses is inside Appearance.

These instructions are bundled text. Reading them does not require a network
connection or a video download once the app is open. The tour only records
that its introduction was acknowledged; it does not edit the plan, mark
supplies packed, or certify that the plan is ready. A preference-save problem
does not block the app or the instructions.

RUGGED FIELD TERMINAL
---------------------
The rugged field-equipment look from v0.7.0+10 is retained.
Static ripstop and grain textures sit behind the content. Matte panels have
chamfered corners, double edges, and small fastener details. Buttons have
stronger borders and depth, and the selected navigation item is more visible.
Large headings use bundled Barlow Condensed; body text and utility labels
retain IBM Plex Mono.

Dark combines olive-black panels, sage controls, cream text, and amber details.
Light uses sand/canvas tones with forest-green controls. The texture is drawn
by the app's code: no texture downloads, new image assets, or dependencies are
needed. Controls and text-entry surfaces remain clear. The header simplifies
at narrow widths or enlarged text settings to leave room for its controls.

The existing Light/Dark preference, plan/checklist/guide storage, shopping
behavior, and features are retained. You reported a green ios-compile-check
and that v0.7.0+10 rendered great. That is the user-reported baseline;
this new tutorial release still needs its own compile and screen checks.

SUGGESTED ITEMS AND PERSONAL INVENTORY
--------------------------------------
Kit now has Shared kit, My pack, and Suggested. Home also has a Browse
suggested items shortcut. The six suggestions include original preparation
notes, four ordinary Amazon product links, and two clearly labeled Amazon
search links. No affiliate tag or commission income is enabled by default.

My pack is a free, personal checklist with items, quantities, notes, and
separate Owned and Packed states. Marking an item Packed also marks it Owned;
clearing Owned clears Packed. You can own something without having packed it.
Items bought anywhere, gifts, and supplies you already have use the same
inventory controls. These actions do not change the shared plan.

Add & shop on Amazon first saves a new suggestion to My pack as unowned,
then offers an explicit Open Amazon or Open Amazon search action. A failed
save does not proceed to shopping. I have this confirms possession; it does
not mark the item packed. Opening a link or returning from Amazon never
confirms a purchase. Adding the same catalog item again reuses its entry and
preserves your edits instead of making a duplicate.

The Windows Chrome preview uses ordinary, untagged US links. All Amazon
shopping in installed iPhone/Android builds requires the corresponding
Amazon mobile-app approval, separate from Apple approval. Installed desktop
builds do not offer Amazon shopping. Inventory remains available in every
case. Future affiliate use requires real Amazon-generated links and the
approved app or exact registered HTTPS web origin. Setup details, the six
item IDs, sources, and disclosure instructions are in AMAZON_AFFILIATE_SETUP.txt.

Failed saves show a warning and offer Retry; use Copy list text to keep a
readable copy. Group-plan JSON backups do NOT include this personal list.

PERSONAL PDF AND VIDEO GUIDES
------------------------------

Open Offline guides from the book button in the top bar or the Home card.
Import a PDF, MP4, MOV, or M4V from the file picker. Black Box copies the actual
file before listing it as saved. Rename guides, search/filter them, open the
saved copy, or remove that copy without deleting the original source file.
No sample guide files are bundled. Cloud-only sources must download first.
On iPhone, a video stored only in Photos may first need Share > Save to Files;
this version imports through Files, with no Photos-library picker.

Native iPhone/device: files are kept in the app's Documents storage, with a
1 GiB per-file import limit. The app opens the local copy using the device
viewer. Compatible PDF/video playback must be checked on the actual phone.
The original file should be kept as a backup; uninstalling/clearing the app
can remove its copies. Operating-system backups may also include these files.

Windows Chrome preview: actual file copies are kept in browser storage with
a 100 MiB per-file import limit. Open PDF/video first prepares the copy, then
Open saved file opens a new browser tab. Some browsers may download it instead
of previewing it. Browser data can be cleared or evicted, and the launcher
must be running to reopen the preview. This is not an installed offline PWA.

The file list shows saved bytes and file sizes. Copy size and basic container
headers are checked; these checks do not prove that a viewer can decode every
page or frame. Open each file and test it in airplane mode on the phone before
relying on it. Guides are not part of the group JSON backup. No Black Box
cloud upload or group sharing of these files is implemented in this release.

Confirmed product rules: free users can post/reply in the future forum, but
cannot moderate it. Moderator eligibility requires Premium plus an assigned
administrator-approved role; a purchase alone grants no moderation power.
Personal packing lists are free. Free inbox sending is still an open choice.
The forum, subscriptions, accounts, and online permissions remain future work.

NAMED LOCATIONS IN A SEPARATE MAP TAB
------------------------------------
The Map tab shows the current local plan's primary and backup meeting
places using their saved names. Select a marker to review that place's local
details. The existing edit and place-pin controls remain available.

The five tabs are Home, Plan, Map, Kit, and Group. This version still manages
one local plan. The Map tab uses online map imagery; it does not download
offline maps or calculate directions.

FIELD TERMINAL - DARK AND LIGHT
-------------------------------
Black Box uses the rugged Field Terminal design in two modes. Dark is the
default, with olive-black equipment panels, cream text, and sage controls.
Light uses sand/canvas surfaces with forest-green controls. Both have static
texture, chamfered panels, and restrained amber details.

Use the top-right sun/moon button to switch directly between Light and Dark.
You can also open the question-mark button > Appearance to select either mode.
The choice is remembered on the same browser or device when its preference
save succeeds. If an earlier
version saved the Flight Deck preference, this update opens Field Terminal
in Dark mode, matching the selected design direction.

Home, Plan, Map, Kit, and Group provide the same functions in either mode.
The fonts are bundled with the app; showing them does not require a separate
font download while using the app.

The app previously called Family Ready keeps the Black Box name introduced
in v0.2.2. The new Map tab uses the existing plan format and saved locations.

Existing shared plans and JSON backups use the same data format and storage
keys. Continue using your normal Chrome profile at http://127.0.0.1:54321.
Older Family Ready JSON backups remain supported.

Upload the contents of the extracted black_box_starter.zip into the existing
family-ready GitHub repository on the same build branch. Keep assets, lib,
scripts, test, and web as folders beside pubspec.yaml and codemagic.yaml.
Include ALL files in lib and test, the updated pubspec.yaml and scripts, and
everything in assets/fonts, preserving their folder hierarchy. Include the
new lib/help_content.dart and lib/help_page.dart with the updated main.dart.
Keep lib/field_surfaces.dart with the existing theme and screen files. Keep the
suggested-items, catalog, affiliate-config, and personal-repository files
in lib, plus test/suggested_catalog_check.dart. Keep the existing guide
platform files too, even when testing in Chrome. Keep NEXT_FEATURES.txt and
AMAZON_AFFILIATE_SETUP.txt with the top-level documents. Upload the extracted
contents, not the ZIP or
an extra enclosing folder. scripts/configure_ios.py still applies the Black Box
iPhone display name during a build.

The existing package, repository, storage, and build identifiers retain their
original family_ready/family-ready names. The proposed Apple bundle identifier
remains com.dennisrogers.familyready. These technical names are separate from
the visible Black Box name and keep the working setup consistent.

CURRENT STATUS
---------------
You reported that v0.7.0+10 passed ios-compile-check with a green result and
that it rendered great. This is user-reported confirmation of the
previous release, not runtime testing performed in this preparation workspace.
Your Apple Developer enrollment was last reported pending. Apple signing and
TestFlight follow after the membership becomes active.

This v0.8.0+11 tutorial update has not been Flutter-compiled or tested
in a browser or on a phone here. Run a new ios-compile-check after uploading
it, and try the tour, Help search, Open buttons, and Appearance access in
both modes. Preparation checks are limited to standalone Dart formatting,
source review, and content/navigation review.

The planned access model lets free readers view complete shared plans and
download them for offline use, with subscriptions for contributing and editing.
This local prototype has no accounts, subscriptions, or payment restrictions.
The full future feature and business requirements are in NEXT_FEATURES.txt.

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
v0.8.0+11 app for an unsigned iOS compile check and, after your Apple account setup,
an internal TestFlight build. Offline routing remains a future feature.
If v0.2 is already working in Chrome, continue with that cloud guide; you do
not need to repeat the browser installation steps below.


This update builds on the v0.7.0+10 app you reported as rendering well with a
green compile check. It adds in-app help while retaining the rugged design,
suggested supplies, ownership/packing,
the personal checklist, local guide-file storage, Map tab, and existing
shared-plan backup/restore format.

UPDATE FROM YOUR EXISTING VERSION
---------------------------------
1. Before updating, use Group > Download backup in your working browser app
   and keep the JSON file. Also use Copy plan text (or Copy plan in an older
   version) and paste that readable text into Notepad as an extra copy.
   Use Copy list text for a separate personal-list copy and keep your original
   guide files; neither is included in the group JSON backup.
2. Click the running app's terminal window and press q to stop it. Close
   its browser tab too.
3. Download black_box_starter.zip. Choose Extract All and use a NEW folder,
   such as Documents\BlackBox_v080. Keep your old source folder.
4. Open the extracted folder containing START_HERE.cmd and pubspec.yaml.
5. Double-click START_HERE.cmd and keep its terminal window open. It downloads
   the required Flutter packages and compiles the updated app; internet is needed.
6. When the terminal says the app is being served, open your normal Chrome
   profile and go to this exact address:

   http://127.0.0.1:54321

7. Confirm the app shows Black Box. Open the question-mark button, then
   Appearance > About Black Box & licenses to check that it says Prototype
   0.8.0. If the old screen is still visible, press Ctrl+Shift+R to reload it.
   Do NOT clear site data.
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
HELP AND TUTORIAL
- Optional Home introduction with Start quick tour and Not now.
- Six short tour chapters with Back, Next, Skip, Done, and a final Open Plan
  action. Replay it from Help whenever you want.
- Ten searchable help topics with expandable steps and direct Open buttons.
- Question-mark header button opens Help; Appearance moves into Help. The
  guide-book and sun/moon shortcuts remain in the main header.
- Instructions explain actual local/offline behavior and the differences
  between the shared kit, personal pack, guide files, and backup copies.
- Bundled text requires no network or media download to read after opening
  the app. Reading progress does not mark any real setup task complete.
- A separate optional preference remembers introduction dismissal. Existing
  models, storage, tests, build scripts, dependencies, fonts, and shopping
  configuration are unchanged.

RUGGED DESIGN RETAINED
- Static ripstop/grain backdrops, matte chamfered panels, double edges, and
  small recessed fastener details across the main screens and guide library.
- Larger condensed headings, stronger button borders/depth, and clearer
  selected navigation. Text fields and controls keep solid readable fills.
- Dark olive/sage/cream and Light sand/forest palettes, with amber accents.
- Header branding simplifies at narrow widths or large text settings.
- No new assets or dependencies. Appearance IDs and saved data are unchanged.

SUGGESTIONS AND OWNERSHIP
- Kit > Suggested and Home > Browse suggested items open the six-item catalog.
  Four links lead to product pages; two lead to searches. Shopping needs internet.
- Add to My pack saves a suggestion without opening a store. I have this
  explicitly confirms possession without marking the item packed.
- Add & shop on Amazon saves first, then offers Open Amazon or Open Amazon
  search. Existing catalog entries keep their edited details and status.
- My pack tracks Owned separately from Packed. Packed implies Owned;
  clearing Owned also clears Packed. No Amazon order detection is implemented.
- Ordinary shopping links work in the Chrome preview. Phone shopping stays
  disabled until Amazon approves that mobile app; installed desktop shopping
  is unavailable. Affiliate configuration starts empty and disabled.
- All inventory functions work for supplies obtained from any retailer.
  See AMAZON_AFFILIATE_SETUP.txt before configuring approved affiliate links.

PERSONAL PACK AND GUIDES
- Kit > My pack: separate free checklist; add/edit quantities and notes,
  mark ownership/packing, filter, and copy readable text.
- Home > Open guides or the top book button: import actual PDF/video files,
  see saved-copy status and sizes, search/filter, rename, open, or remove.
- Shared-kit changes still use the existing plan. Personal pack items and
  guide files do not enter that plan or its JSON backup.
- No cloud guide upload, forum, moderator role, or paid access is active yet.

CURRENT PLAN MAP
- Map is now its own tab between Plan and Kit.
- It shows the current local plan's primary and backup locations by their
  saved names. Select either saved marker to review its local details.
- Existing controls let you edit a place or choose/change its map pin.
- Map imagery requires internet. Saved names, written details and coordinates
  are part of the existing local plan; map imagery is not in its JSON backup.
- Multiple plans, account groups, cloud sharing, a forum, an inbox, and paid
  subscriptions are planned features, not functions added by this update.

APPEARANCE AND NAVIGATION
- Field Terminal opens in Dark mode by default. Use the top-right sun/moon
  button to switch directly to Light mode or back to Dark. Both options are
  also in Help > Appearance, and the selected mode is stored locally.
- Light uses sand/canvas surfaces with forest-green controls; Dark uses
  olive-black panels, sage controls, and cream text. Both retain the texture.
- Home shows the plan overview; Plan contains meeting places; Map displays
  those locations; Kit contains supplies; Group contains the local roster,
  backup/restore, and readable copies.
- Barlow, Barlow Condensed, and IBM Plex Mono are bundled font assets. Their
  open font license notices are included with the app.
- Appearance does not change the saved-plan schema, storage keys, or backups.

EXISTING FUNCTIONS RETAINED
--------------------------
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
- In the browser and on supported desktop targets, Download backup creates
  a JSON file containing your whole plan: members,
  locations, coordinates, supplies, quantities, assignments, notes, and checks.
- Restore backup validates the file and shows its group name and counts before
  you decide whether to replace the current plan. It does not merge two plans.
- A previous local copy is retained during upgrade/restore. A separate recovery
  copy protects the selected backup if a restore is interrupted or a write fails.
- Group provides previews when those local copies are present. Download
  controls are available on the browser and supported desktop targets.
- In the browser and on supported desktop targets, Download text plan creates
  a readable .txt file you can open in Notepad and
  print with Ctrl+P. Copy plan text is also available.
- Text copies are for reading and printing. Restore backup accepts the JSON
  backup, up to 2 MiB. JSON files are plain and unencrypted; keep them private.
- A browser download message means the download was requested. Check Chrome's
  Downloads list and confirm the file exists where you expect.
- Native mobile file export/sharing is not implemented. On the iPhone, the UI
  provides Copy plan text and Restore backup without unsupported download
  buttons. A readable text copy cannot be used as a JSON restore backup.

A QUICK WALKTHROUGH
-------------------
For a guided introduction, choose Start quick tour on Home. You can also open
the question-mark button > Quick tour. Skip or Done returns to the app without
changing any plan information. The steps below let you check actual actions.

1. Use the top-right sun/moon button to try Field Terminal in Light and Dark.
   Check the same choices in Help > Appearance. Choose your preferred mode, then
   check it is remembered when you reopen the same browser URL.
2. Open Plan. Add a sample name/address, choose a map pin, and save.
3. Do the same for the backup location.
4. Open Map. Confirm the primary and backup markers use the names you saved.
   Select each marker and review its details. The map imagery needs internet.
5. Open Kit > Shared kit. Add "Flashlight", quantity "2", category "Light & power",
   assign someone, and add a note such as "Hall cupboard".
6. Mark it packed and try the filters. Use Clear filters to show everything.
7. Wait for the saved status, refresh the page, and check that the fields remain.
8. In the browser, open Group > Download backup. Check the file is present.
9. To try restore safely, change one sample item, then select the backup file.
   Review the preview and choose Replace current plan. Confirm the older value
   comes back. Group > Preview previous copy lets you review the replaced plan.
10. In the browser, download a text plan and open it in Notepad to inspect the
   readable copy. On the phone, use Copy plan text for a readable copy instead.
11. Open Kit > My pack. Add a personal item, set its quantity, mark it packed,
    switch tabs, and reopen. Refresh/restart and confirm its saved state.
    Check that Packed also set Owned. Clear Owned and confirm Packed clears;
    then mark it Owned without marking it Packed.
    Confirm the same action did not alter any Shared kit item.
12. Open guides and import a small PDF and video you own. Wait for saved-copy
    status, rename one, and try PDFs/Videos/search. Open both saved files.
    On Chrome, use the second Open saved file button to open the new tab.
13. Reopen the app and confirm both saved guides are still listed. On the
    installed iPhone, close the app, disable Wi-Fi and cellular, reopen it,
    and open the PDF and video. Check multiple PDF pages and video seeking.
    The phone test remains necessary; a green compile is not this test.
14. Open Suggested from Kit or Home. Add a new item to My pack, edit its name
    or note, then add that catalog item again. Check that it reuses the entry
    without replacing your edits. Use I have this to confirm possession.
15. In the Chrome preview, choose Add & shop on Amazon for another new item.
    Check that it saves as unowned, then use the explicit Open Amazon action.
    Return without buying anything. Confirm it remains unowned and unpacked.
    Search suggestions use Open Amazon search. No test purchase is needed.
16. On a phone build without Amazon approval, check that suggestions and
    inventory work while Amazon shopping controls remain unavailable.
17. Open Help and search for "offline", "packed", or "backup". Expand a topic,
    read its numbered steps, and use its Open button. Confirm the intended
    tab or guide library opens and that your existing plan is unchanged.
18. Replay Quick tour from Help. Try Back, Next, and Skip; on the final page,
    try Done and then replay to try Open Plan. If the Home introduction is
    still visible, choose Not now and reopen to check that it stays dismissed.
    Help remains available from the question-mark button in either case.

WHAT WORKS OFFLINE, AND WHAT IS STILL BEING BUILT
------------------------------------------------
The current browser prototype stores written plan details and coordinates in
this browser. It runs from the development server on your Windows computer.
This is not yet an installed phone app with verified offline startup.

The Map tab and pin picker use online OpenStreetMap tiles. They have no offline
map package, address search, directions, road closures, or live hazard data.
Its tile service allows ordinary interactive viewing but prohibits bulk/offline
map downloading. This prototype requests only the area you actively view.
The JSON backup stores pin coordinates, not map imagery.
Bundled fonts and a saved appearance do not provide downloaded map data.

There are no accounts, account-based groups/invitations, multiple-plan storage,
cloud sharing, family synchronization, community forum, asynchronous inbox,
subscriptions, live member locations, or bundled survival-guide content in
this version. You can import your own local PDF/video guides. Adding a name
only changes the local roster. A save time
is not a synchronization time or evidence that another device received a plan.
NEXT_FEATURES.txt describes the planned features; it is not a list of working
online services in this release.

The suggested catalog is bundled data, so reading its notes does not require
Amazon. Shopping requires internet and the platform's shopping permission.
There is no Amazon order integration, verified purchase detection, or active
affiliate account in this package.

Help and the quick tour are also bundled text, with no online service or media
required to read them once the app is open. This does not change the browser
preview's need for its launcher, the online map imagery, or the need to test
saved information and imported guide files on the installed phone offline.

The shared plan and checklist still need a more durable primary database and
device verification before emergency use. Imported guide files use persistent
Documents storage on native devices. The native emergency app needs a map provider
that permits offline packages, per-device download/sync status, and actual
phone restart tests in airplane mode. This prototype is for development and
feedback, not emergency reliance.

The Black Box name is a flight-recorder metaphor. It does not certify
physical ruggedness or data security. App-level encrypted local storage is
not implemented. Those reliability and storage requirements, along with
offline maps and routing, must be addressed before a go-bag release.

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

The same original group-plan browser storage key is retained. Version 1 plans remain
readable; new writes use version 2. Before the first version-2 save, the exact
old stored record is retained as the previous copy. Opening an old source
version after upgrading is not a supported downgrade path: the old code cannot
read version-2 plans. Keep the updated code with your downloaded backups.

The separate personal-list key is also retained. This update reads personal
schema versions 1 and 2 and writes version 2 with ownership and catalog IDs.
Previously packed personal items become Owned and Packed; unchecked older
items remain unconfirmed as owned. The shared-plan schema is not changed by
this personal-list migration. Use the updated app with its updated data.

The prototype still uses shared_preferences for plan/checklist data,
appearance, and the separate optional help-introduction preference
black_box.help_intro_dismissed.v1. Dismissing the introduction does not write
to a plan or change its save status. Its maintainers do not recommend
shared_preferences for critical data; primary
plan/checklist storage will be replaced and tested before an emergency-ready
release. PDF/video bytes use native Documents storage or browser IndexedDB,
not shared_preferences, and are excluded from group-plan JSON backups.

PROJECT FILES
-------------
lib/main.dart          Screens, local saving, backup preview, and recovery UI.
lib/help_content.dart  Bundled quick-tour chapters and searchable task instructions.
lib/help_page.dart     Help search, expandable topics, and optional tour screens.
lib/black_box_theme.dart Field Terminal appearance and color definitions.
lib/field_surfaces.dart Static textures, chamfered panels, and field-style headings.
lib/plan_models.dart   Data model, version migration, validation, readable export.
lib/plan_dialogs.dart  Meeting-place and supply editors.
lib/meeting_map.dart   Interactive online map and coordinate picker.
lib/plan_map.dart      Map tab for the current local plan's named locations.
lib/plan_files.dart    File import, browser download, and desktop save helpers.
lib/plan_store.dart    Restore journal and ordered persistence writes.
lib/personal_packlist.dart Personal checklist screen and saved-state controls.
lib/personal_packlist_models.dart Ownership/packing model, migration, and queued store.
lib/personal_packlist_repository.dart Shared personal-list access across Kit views.
lib/suggested_catalog.dart Six suggestions, destination validation, and platform gates.
lib/suggested_items.dart Suggested-item screen and explicit shopping handoff.
lib/amazon_affiliate_config.dart Disabled-by-default approval and full-link settings.
lib/guide_library.dart Personal PDF/video library screen.
lib/guide_files.dart   File picker and conditional platform entry point.
lib/guide_models.dart  Guide metadata, limits, and basic header validation.
lib/guide_store.dart   Storage interface and operation queue.
lib/guide_store_native.dart Transactional native file-copy storage.
lib/guide_platform_native.dart Device paths and local-file viewer handoff.
lib/guide_platform_web.dart Browser IndexedDB storage and local Blob opening.
lib/guide_platform_stub.dart Unsupported-platform fallback.
test/                  Pure Dart model, restore, checklist, catalog/link, and guide checks.
test/suggested_catalog_check.dart Catalog and shopping-link validation checks.
assets/fonts/          Bundled font files and their open font license notices.
pubspec.yaml           Version, pinned dependencies, font and asset declarations.
web/index.html         Browser entry point.
START_HERE.cmd         Windows launcher.
README.txt             Browser prototype guide.
START_IPHONE_CLOUD.txt  Windows-to-iPhone build and TestFlight instructions.
NEXT_FEATURES.txt       Planned product features, access model, and requirements.
AMAZON_AFFILIATE_SETUP.txt Shopping behavior, approved-link setup, catalog, and sources.
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
- Amazon shopping is unavailable on a phone: this is expected before Amazon
  approves that mobile app. The Apple/TestFlight setup is separate. Inventory
  still works; see AMAZON_AFFILIATE_SETUP.txt for the activation requirements.
- A shopping link will not open: confirm internet access and use the explicit
  Open Amazon button after the item saves. Check My pack before retrying.

VERIFICATION
------------
You confirmed that version 0.2 looks good and works on your Windows computer.
Earlier prototype preparation included Dart parsing/formatting, pure-model
static analysis, migration/model/roundtrip checks, and checking map/file APIs
against their official packages.

A full Flutter build/browser test has not run in the preparation environment.
Automatic approval review previously rejected Flutter startup
because it attempted to contact a cloud instance metadata endpoint. That
blocked path was not retried or bypassed. Your earlier Windows run provides
the v0.2 browser check. You subsequently reported a green ios-compile-check
run for v0.2.2, covering its configured analysis, data checks, and unsigned
iPhone compilation, including the Black Box rename.

Version 0.3.0+5 passed standalone Dart formatting and source review during
preparation. Its existing 62 model/migration/backup/validation checks and all
six restore-failure scenarios passed with standalone Dart. You have not
reported a v0.3.0 Flutter build result.

For v0.3.1+6, standalone Dart formatting of lib/main.dart and
lib/black_box_theme.dart passed with no changes. A focused source review
checked the default mode, older-preference handling, shared appearance
callback, direct toggle, and retention of the plan and selected tab. The
Light palette received source review and numerical contrast checks for
selected text/control combinations.

For v0.4.0+7, standalone Dart formatting passed for main.dart and plan_map.dart.
A focused source review checked Map navigation, location selection, and reuse
of the existing edit/save callbacks. Runtime layout, native builds, and device
interaction remain unverified.

The existing group model and storage files are unchanged, so the earlier 62-check and
six-scenario results are carried forward; those checks have not been rerun
for this update. No widget or native UI tests were run.

For v0.5.0+8, 27 new standalone checklist model/store checks and 38 native guide
file-storage checks passed. Guide tests used real temporary files with an
injected directory/opener, covering cold reopen, copy failures, incomplete
imports, malformed metadata, rename/remove isolation, and queued operations.
They do not test iOS plugins, browser IndexedDB, PDF/video decoding, or widgets.
Standalone Dart formatting passed for all 22 Dart source/test files.
Source review checked navigation, storage boundaries, viewer handoff, browser
transaction completion, and local-file status wording. The updated build
check script passed shell syntax validation.

For v0.6.0+9, all 52 standalone personal-checklist model/store checks passed,
covering the added ownership behavior and personal-list migration.
All 182 standalone catalog/link-policy checks passed, including the default
disabled configuration and shopping destination/platform validation. Source
review and standalone Dart formatting also completed. You subsequently
reported a green ios-compile-check and that everything is working for v0.6.0+9.
That is historical user-reported confirmation, not workspace-run browser or
native-device QA, and it does not establish every offline scenario.

For v0.7.0+10, preparation checks were limited to source review, standalone
formatting, and numerical contrast review of the palette. The 52 personal-list
and 182 catalog/link checks above are historical v0.6.0 results; they have not been
rerun for the visual update. No new model or UI test suite was added. You then
reported that v0.7.0+10 rendered great and passed ios-compile-check. This is the
latest user-reported baseline; no browser or native-device QA ran here.

For v0.8.0+11, checks are limited to standalone Dart formatting, source review,
and review of help content/navigation. The existing model/storage/test files,
build scripts, dependencies, fonts, and shopping configuration are unchanged.
No new automated tests were added; the earlier 52/182-check results have not
been rerun. No Flutter compilation, browser QA, or native-device QA was
performed here. The earlier automatic approval restriction on Flutter startup
remains in place. Check this release with the Windows launcher and a new
ios-compile-check build, including Help and tour controls, both appearances,
small widths, larger text, and the existing screen actions.
Installation and behavior on the physical iPhone still need testing after
Apple signing is configured.

Optional developer checks (after Dart is available in your terminal):
  dart test/plan_models_check.dart
  dart test/plan_store_check.dart
  dart test/personal_packlist_check.dart
  dart test/guide_store_check.dart
  dart test/suggested_catalog_check.dart

NEXT DEVELOPMENT MILESTONE
--------------------------
See NEXT_FEATURES.txt for the agreed direction: account-based groups and
invitations, multiple plans, user-controlled sharing, an online community
forum, and an asynchronous inbox. The inbox is not real-time chat or SMS.
Free readers should be able to view and download complete shared plans for
offline access; subscribers should be able to contribute and edit. Online
information about saved areas is a later addition. These are requirements
for future work, not implemented services or purchase options in this build.

Installation on the test phone, durable storage, proper offline map packages,
and real restart tests without connectivity remain necessary milestones.

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
Local guide storage and viewers:
https://pub.dev/packages/path_provider
https://pub.dev/packages/open_filex
https://pub.dev/packages/web
https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria
Local preferences limitations:
https://pub.dev/packages/shared_preferences
Font sources and licenses:
https://github.com/google/fonts/tree/main/ofl/barlow
https://github.com/google/fonts/tree/main/ofl/barlowcondensed
https://github.com/google/fonts/tree/main/ofl/ibmplexmono
Apple accessibility design guidance:
https://developer.apple.com/design/human-interface-guidelines/accessibility
