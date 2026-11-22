import 'suggested_catalog.dart';

// No affiliate account or approved links have been supplied. These settings
// intentionally enable no commissions. Read AMAZON_AFFILIATE_SETUP.txt first.
// Amazon app approval is separate from Apple Developer/App Store approval.
const approvedIosApp = false;
const approvedAndroidApp = false;

// Exact registered HTTPS origins, with no path or trailing slash. Localhost
// and IP-address previews cannot activate affiliate links.
const approvedWebOrigins = <String>{};

// Full Amazon-generated Special Links keyed by catalog ID. Do not invent a
// tag, put customer IDs in links, or add API secrets. Supported IDs:
// flashlight, weather_radio, manual_can_opener, water_container, whistle,
// duct_tape. Empty entries use ordinary links only where shopping is enabled.
const amazonSpecialLinks = <String, String>{};

const amazonLinkSettings = AmazonLinkSettings(
  approvedIosApp: approvedIosApp,
  approvedAndroidApp: approvedAndroidApp,
  approvedWebOrigins: approvedWebOrigins,
  specialLinks: amazonSpecialLinks,
);
