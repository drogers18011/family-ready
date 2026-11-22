/// Bundled app instructions. Reading these pages does not change a plan,
/// confirm preparedness, contact anyone, or require a network request.
enum HelpDestination {
  home,
  plan,
  map,
  sharedKit,
  personalPack,
  suggested,
  group,
  guides,
  appearance,
}

class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
    this.note,
    this.destination,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> steps;
  final String? note;
  final HelpDestination? destination;
  final String? actionLabel;
}

const quickTour = <HelpTopic>[
  HelpTopic(
    id: 'tour_welcome',
    title: 'Your plan, close at hand',
    summary:
        'Keep meeting instructions, packing lists, and reference files '
        'together in Black Box.',
    steps: [
      'Home gives you a quick view of the meeting plan and shared kit.',
      'Start in Group: replace the example names and add the people in your plan.',
    ],
    note:
        'This version keeps one local plan. Adding a person does not send '
        'an invitation or update their phone.',
    destination: HelpDestination.group,
    actionLabel: 'Open Group',
  ),
  HelpTopic(
    id: 'tour_places',
    title: 'Choose where to meet',
    summary: 'Use Plan for a primary meeting place and a backup place.',
    steps: [
      'Give each place a name, a written address or landmark, and clear instructions.',
      'Choose a map pin separately, then check that it matches the written location.',
      'Use Map to review your saved locations by name.',
    ],
    note:
        'Map imagery needs internet. Written details and coordinates are '
        'kept locally after a successful save.',
    destination: HelpDestination.plan,
    actionLabel: 'Open Plan',
  ),
  HelpTopic(
    id: 'tour_kit',
    title: 'Organize what to bring',
    summary:
        'Kit has a shared list, your personal pack, and suggested supplies.',
    steps: [
      'Shared kit: add supplies, quantities, and the person who brings each item.',
      'My pack: mark Owned when you have an item and Packed when it is in your kit.',
      'Suggested: save ideas to My pack or mark something you already own.',
    ],
    note:
        'Opening a shopping link never confirms a purchase or marks an '
        'item owned.',
    destination: HelpDestination.sharedKit,
    actionLabel: 'Open Shared kit',
  ),
  HelpTopic(
    id: 'tour_guides',
    title: 'Carry your reference files',
    summary: 'Use the book button to keep PDFs and videos in Offline guides.',
    steps: [
      'Choose Import PDF or video and wait for the file to finish saving.',
      'Open the saved copy to check that its pages or video play correctly.',
      'Keep the original file as a separate backup.',
    ],
    note:
        'A file stored only in a cloud service must download before it can '
        'be imported.',
    destination: HelpDestination.guides,
    actionLabel: 'Open guides',
  ),
  HelpTopic(
    id: 'tour_offline',
    title: 'Practice before you need it',
    summary:
        'Check your installed phone app while you still have time to prepare.',
    steps: [
      'Finish saving your plan, personal list, and imported guides.',
      'Turn on airplane mode, turn off Wi-Fi, then close and reopen the app.',
      'Read the plan and open a saved PDF or video to check your offline copies.',
    ],
    note:
        'Map images and shopping need internet. The Windows browser preview '
        'also needs its launcher running to reopen; it is not an installed '
        'offline app.',
    destination: HelpDestination.home,
    actionLabel: 'Open Home',
  ),
  HelpTopic(
    id: 'tour_keep_copy',
    title: 'Keep a copy and keep learning',
    summary: 'Use Group for plan copies and the question-mark button for help.',
    steps: [
      'Group has Backup & restore and Copy plan text.',
      'My pack has its own Copy list text; keep original PDFs and videos separately.',
      'Reopen Help anytime to search instructions or replay this tour.',
    ],
    note:
        'Finishing this tour does not check or change your plan. Review your '
        'actual information and supplies yourself.',
    destination: HelpDestination.group,
    actionLabel: 'Open Group',
  ),
];

const helpTopics = <HelpTopic>[
  HelpTopic(
    id: 'getting_started',
    title: 'Start your group plan',
    summary: 'Replace the example names and supplies with information for your people.',
    steps: [
      'Open Group. Use the pencil beside the group name to rename your plan.',
      'Tap a member name to edit it, or choose Add member. Member actions lets '
          'you edit or remove a name.',
      'Open Plan to enter your primary and backup meeting places.',
      'Open Kit > Shared kit to review the example supplies and add your own.',
      'After editing, check the shared-plan save message at the bottom of the '
          'main screen. If saving fails, use Retry save or Copy plan.',
    ],
    note:
        'Group is a local roster, not an account or invitation system. '
        'Shared kit does not sync to other phones. Multiple plans, online '
        'groups, forum posts, and inbox messaging are still in development.',
    destination: HelpDestination.group,
    actionLabel: 'Open Group',
  ),
  HelpTopic(
    id: 'meeting_plan',
    title: 'Add meeting places',
    summary: 'Save a primary place, a backup place, and instructions that make sense without a map.',
    steps: [
      'Open Plan. Tap the pencil for Primary meeting place or Backup meeting place.',
      'Enter a Location name and Written address or landmark.',
      'Add Meeting instructions, such as the exact entrance and when to use '
          'the backup place.',
      'Choose on map to add a pin, or View / change pin to adjust one. Check '
          'its position, choose Use selected pin, then Save meeting place.',
      'Review both places and wait for the shared plan to show that it is saved.',
    ],
    note:
        'Typing or changing an address does not place or move a pin. Check '
        'the written location and the pin together after either changes.',
    destination: HelpDestination.plan,
    actionLabel: 'Open Plan',
  ),
  HelpTopic(
    id: 'map',
    title: 'Use the location map',
    summary:
        'See the names and saved details of your primary and backup locations.',
    steps: [
      'Open Map and select a named marker or a location in the list below it.',
      'Read Selected location for the address, coordinates, and meeting instructions.',
      'Use Choose pin or Change pin to select a spot. You can also enter '
          'Latitude and Longitude, choose Use coordinates, and then Use selected pin.',
      'Use Show all to bring the saved pins into view. If the images fail '
          'while online, try Retry map imagery.',
    ],
    note:
        'The map does not provide offline map downloads, route directions, '
        'current road closures, or live hazards. Saved written details and '
        'coordinates remain separate from the online map imagery.',
    destination: HelpDestination.map,
    actionLabel: 'Open Map',
  ),
  HelpTopic(
    id: 'shared_kit',
    title: 'Assign supplies in Shared kit',
    summary: 'Keep one list of what the group plans to bring and who is responsible.',
    steps: [
      'Open Kit > Shared kit and choose Add supply.',
      'Enter the Supply name, quantity, category, Who brings it?, and any notes. '
          'Choose Save supply.',
      'Tap an item or choose Edit / assign from its actions to change the details.',
      'Check Packed when that item is actually in the kit. Use search and the '
          'category, person, or packing filters to review the list.',
    ],
    note:
        'These checks belong to the shared plan on this device. My pack is '
        'a separate personal list with its own Owned and Packed controls.',
    destination: HelpDestination.sharedKit,
    actionLabel: 'Open Shared kit',
  ),
  HelpTopic(
    id: 'personal_pack',
    title: 'Track Owned and Packed in My pack',
    summary: 'Keep your personal equipment list separate from the shared kit.',
    steps: [
      'Open Kit > My pack and choose Add personal item. Add a name, quantity, '
          'and notes, then choose Save item.',
      'Mark Owned when you have the item available. Mark Packed when it is '
          'in your kit.',
      'Marking Packed also marks Owned. Clearing Owned clears Packed; '
          'clearing Packed keeps Owned.',
      'To buy shows items not yet marked owned. To pack shows owned items '
          'that are not packed.',
      'Check the save message inside My pack. Use Copy list text for a '
          'separate readable copy, especially if a save needs to be retried.',
    ],
    note:
        'The main screen footer reports the shared plan, not this personal '
        'list. Older unchecked items are unconfirmed, so review what you '
        'already own. Group backups do not include My pack.',
    destination: HelpDestination.personalPack,
    actionLabel: 'Open My pack',
  ),
  HelpTopic(
    id: 'suggested_items',
    title: 'Add suggested supplies',
    summary: 'Browse starter ideas and add useful items to My pack.',
    steps: [
      'Open Kit > Suggested, then search or choose a category.',
      'Choose Add to My pack to save an idea without shopping. Choose I have '
          'this only when you already have the item available.',
      'Where shopping is enabled, Add & shop on Amazon saves the item first. '
          'Then choose Open Amazon or Open Amazon search to leave the app.',
      'After you receive an item, mark it Owned in My pack. Mark Packed '
          'separately when it is in your kit.',
    ],
    note:
        'A shopping link cannot confirm a purchase or delivery. Inventory '
        'works for items from any store. Shopping needs internet and may be '
        'unavailable in your build. The starter suggestions are not a complete kit.',
    destination: HelpDestination.suggested,
    actionLabel: 'Open Suggested',
  ),
  HelpTopic(
    id: 'offline_guides',
    title: 'Save PDFs and videos',
    summary: 'Import the actual file so you can open a local copy later.',
    steps: [
      'Tap the book button or Home > Open guides, then Import PDF or video.',
      'Choose a PDF, MP4, MOV, or M4V file. Let cloud files download first. '
          'On iPhone, a video in Photos may need Share > Save to Files before import.',
      'Wait for Saved on this device or Saved in this browser. Then choose '
          'Open PDF or Open video to check the copy.',
      'In the browser preview, choose Open saved file after preparation. '
          'The browser may download a file it cannot preview.',
      'Use Guide actions to Rename or Remove copy. Keep the original file; '
          'Remove copy deletes only the copy held by Black Box.',
    ],
    note:
        'The import limit is 1 GiB per file on a device and 100 MiB in the '
        'browser preview. Playback depends on the file format. On the phone, '
        'test the saved files in airplane mode with Wi-Fi off. Guides are '
        'personal files and are not included in group backups or cloud sharing.',
    destination: HelpDestination.guides,
    actionLabel: 'Open guides',
  ),
  HelpTopic(
    id: 'backups',
    title: 'Keep and restore plan copies',
    summary: 'Use a backup file for restoring and a text copy for reading or printing.',
    steps: [
      'Open Group > Backup & restore. In the browser or desktop app, choose '
          'Download backup and keep the JSON file somewhere you can find again.',
      'On a phone, use Copy plan text for a readable copy. The phone build '
          'can restore a JSON file, but does not yet create or share backup files.',
      'To restore, choose Restore backup and select a Black Box JSON file. '
          'Review its preview before choosing Replace current plan.',
      'Copy plan text and Download text plan make readable copies. They '
          'cannot be used with Restore backup.',
      'Keep My pack separately with Copy list text, and keep your original '
          'PDFs and videos. Group JSON does not include these or map images.',
    ],
    note:
        'Restoring replaces the current local group plan and does not update '
        'another device. Backup files contain your entered details without '
        'encryption, so keep them private. Keep a separate copy before replacing a plan.',
    destination: HelpDestination.group,
    actionLabel: 'Open Group',
  ),
  HelpTopic(
    id: 'offline_access',
    title: 'Check your offline access',
    summary: 'A successful save and a real offline check are different steps.',
    steps: [
      'Check the shared-plan save message and the separate save message in '
          'My pack. Finish importing any guide files before disconnecting.',
      'On the installed phone app, turn on airplane mode and turn off Wi-Fi. '
          'Close and reopen Black Box, read your plan, and open a saved guide.',
      'Map imagery, Amazon pages, and downloading cloud-only files require '
          'internet. Offline map downloads and route directions are not included yet.',
      'In the Windows browser preview, keep START_HERE.cmd running and use '
          'the same Chrome profile at http://127.0.0.1:54321. Reopening that '
          'preview depends on the launcher; it is not an installed offline app.',
    ],
    note:
        'Clearing browser or app storage, uninstalling, or browser storage '
        'reclamation can remove local copies. Keep backups and original guide '
        'files. This Help section is bundled with the app and can be read offline.',
    destination: HelpDestination.home,
    actionLabel: 'Open Home',
  ),
  HelpTopic(
    id: 'appearance',
    title: 'Change appearance or find app information',
    summary: 'Choose the light or dark field terminal and reopen instructions anytime.',
    steps: [
      'Use the sun/moon button in the main screen header to switch Light and Dark.',
      'For both appearance choices, open Help with the question-mark button '
          'and choose Appearance.',
      'In Appearance, choose About Black Box & licenses to see the app version '
          'and font licenses.',
      'Return to Help whenever you want to search a topic or replay the quick tour.',
    ],
    note:
        'The appearance choice is remembered on the same browser or device '
        'when saving the preference succeeds.',
    destination: HelpDestination.appearance,
    actionLabel: 'Open Appearance',
  ),
];
