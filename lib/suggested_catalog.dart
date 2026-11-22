/// Original planning notes and ordinary links. No downloaded Amazon content,
/// prices, availability, ratings, images, account data, or order history.
class SuggestedItem {
  const SuggestedItem({
    required this.id,
    required this.name,
    required this.category,
    required this.example,
    required this.note,
    required this.amazonUrl,
    this.asin,
    this.searchTerm,
  });

  final String id;
  final String name;
  final String category;
  final String example;
  final String note;
  final String amazonUrl;
  final String? asin;
  final String? searchTerm;

  bool get isSearch => searchTerm != null;
}

// Categories informed by Ready.gov's emergency kit checklist. Brands below are
// examples, not Ready.gov endorsements or a complete kit. Links checked
// November 22, 2026. Keep IDs stable: personal items refer to these IDs.
const suggestedItems = <SuggestedItem>[
  SuggestedItem(
    id: 'flashlight',
    name: 'Flashlight',
    category: 'Light',
    example: 'Energizer Vision HD flashlight',
    note:
        'Keep a working light and matching spare batteries. Check the '
        'battery type and test the light before packing it.',
    amazonUrl: 'https://www.amazon.com/dp/B06X9TV75K',
    asin: 'B06X9TV75K',
  ),
  SuggestedItem(
    id: 'weather_radio',
    name: 'Weather radio',
    category: 'Communications',
    example: 'Midland ER310 weather radio',
    note:
        'Test local reception and learn the power and alert settings '
        'before you need the radio.',
    amazonUrl: 'https://www.amazon.com/dp/B015QIC1PW',
    asin: 'B015QIC1PW',
  ),
  SuggestedItem(
    id: 'manual_can_opener',
    name: 'Manual can opener',
    category: 'Food tools',
    example: 'OXO Good Grips manual can opener',
    note:
        'Keep an opener with your canned food. Check that it is comfortable '
        'to use and works with the cans you store.',
    amazonUrl: 'https://www.amazon.com/dp/B00004OCJW',
    asin: 'B00004OCJW',
  ),
  SuggestedItem(
    id: 'water_container',
    name: 'Home water container',
    category: 'Home water',
    example: 'Reliance Aqua-Tainer, 7 gallon',
    note:
        'An example for home water storage, not a lightweight go-bag. '
        'Check the filled weight and storage space. A container does not '
        'purify water.',
    amazonUrl: 'https://www.amazon.com/dp/B001QC31G6',
    asin: 'B001QC31G6',
  ),
  SuggestedItem(
    id: 'whistle',
    name: 'Signaling whistle',
    category: 'Signaling',
    example: 'Pealess signaling whistles',
    note:
        'Keep a whistle where you can reach it and test it before packing. '
        'Compare attachment options and ease of use.',
    amazonUrl: 'https://www.amazon.com/s?k=pealess+emergency+whistle',
    searchTerm: 'pealess emergency whistle',
  ),
  SuggestedItem(
    id: 'duct_tape',
    name: 'Duct tape',
    category: 'Repairs',
    example: 'Duct tape options',
    note:
        'Choose a roll size and adhesive suitable for your intended small '
        'repairs. Include it where it is easy to find in your kit.',
    amazonUrl: 'https://www.amazon.com/s?k=duct+tape',
    searchTerm: 'duct tape',
  ),
];

enum ShoppingSurface { web, ios, android, other }

class AmazonShoppingLink {
  const AmazonShoppingLink({required this.uri, required this.isAffiliate});

  final Uri uri;
  final bool isAffiliate;
}

/// Deployment settings, never a per-user entitlement or tracking identifier.
/// URL checks cannot prove Amazon generated a link; the administrator must
/// provide full, approved Special Links from Amazon's own linking tools.
class AmazonLinkSettings {
  const AmazonLinkSettings({
    this.approvedIosApp = false,
    this.approvedAndroidApp = false,
    this.approvedWebOrigins = const {},
    this.specialLinks = const {},
  });

  final bool approvedIosApp;
  final bool approvedAndroidApp;
  final Set<String> approvedWebOrigins;
  final Map<String, String> specialLinks;

  // Installed desktop apps do not fall within Amazon's mobile-app exception.
  // Unapproved mobile builds do not fall back to ordinary Amazon links.
  bool canShop(ShoppingSurface surface) => switch (surface) {
    ShoppingSurface.web => true,
    ShoppingSurface.ios => approvedIosApp,
    ShoppingSurface.android => approvedAndroidApp,
    ShoppingSurface.other => false,
  };

  AmazonShoppingLink? linkFor(
    SuggestedItem item, {
    required ShoppingSurface surface,
    String? webOrigin,
  }) {
    if (!canShop(surface)) return null;
    final affiliateAllowed = switch (surface) {
      ShoppingSurface.web => _approvedWebOrigin(webOrigin),
      ShoppingSurface.ios => approvedIosApp,
      ShoppingSurface.android => approvedAndroidApp,
      ShoppingSurface.other => false,
    };
    final supplied = specialLinks[item.id];
    final affiliate = affiliateAllowed && supplied != null
        ? validateAmazonSpecialLink(item, supplied)
        : null;
    if (affiliate != null) {
      // Preserve the supplied link; never append personal IDs or infer orders.
      return AmazonShoppingLink(uri: affiliate, isAffiliate: true);
    }
    return AmazonShoppingLink(
      uri: Uri.parse(item.amazonUrl),
      isAffiliate: false,
    );
  }

  bool _approvedWebOrigin(String? origin) {
    if (origin == null || !approvedWebOrigins.contains(origin)) return false;
    final uri = Uri.tryParse(origin);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.origin != origin) {
      return false;
    }
    final host = uri.host.toLowerCase();
    // Public registered DNS names only. This also rejects IPv6, numeric or
    // hexadecimal IP spellings, single-label hosts, and trailing-dot variants.
    final publicName =
        RegExp(
          r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$',
        ).hasMatch(host) &&
        RegExp(r'[a-z]').hasMatch(host.split('.').last);
    return publicName &&
        host != 'localhost' &&
        !host.endsWith('.localhost') &&
        !host.endsWith('.local') &&
        host != '::1' &&
        host != '[::1]' &&
        !RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(host);
  }
}

/// Validates a configured full US Special Link without opening it or changing
/// it. Unknown query parameters fail closed to the ordinary verified link.
/// No per-user values are accepted by or added to this function.
Uri? validateAmazonSpecialLink(SuggestedItem item, String raw) {
  if (raw.isEmpty || raw.length > 4096 || RegExp(r'\s').hasMatch(raw)) {
    return null;
  }
  // Uri removes an explicit default :443 port during normalization. Check
  // the supplied authority as well so unsupported forms cannot slip through.
  final rawAuthority = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]+)')
      .firstMatch(raw)
      ?.group(1);
  if (rawAuthority == null || rawAuthority.contains(':')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      !const {'amazon.com', 'www.amazon.com'}.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment) {
    return null;
  }
  try {
    final parameters = uri.queryParametersAll;
    const allowed = {
      'tag',
      'linkCode',
      'linkId',
      'camp',
      'creative',
      'creativeASIN',
      'ref',
      'ref_',
      'language',
      'psc',
      'th',
      'ie',
      'k',
    };
    if (parameters.entries.any(
      (entry) => !allowed.contains(entry.key) || entry.value.length != 1,
    ))
      return null;
    final tag = parameters['tag']?.single;
    if (tag == null ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{1,99}$').hasMatch(tag)) {
      return null;
    }
    final segments = uri.pathSegments;
    if (item.asin != null) {
      final productIndex = segments.length >= 2 && segments[0] == 'dp'
          ? 0
          : segments.length >= 3 &&
                ((segments[0] == 'gp' && segments[1] == 'product') ||
                    (segments[1] == 'dp' &&
                        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segments[0])))
          ? 1
          : -1;
      if (productIndex < 0 ||
          productIndex + 1 >= segments.length ||
          segments[productIndex + 1] != item.asin ||
          parameters.containsKey('k'))
        return null;
      final tail = segments.skip(productIndex + 2).toList();
      if (tail.length > 1 ||
          (tail.isNotEmpty &&
              tail.single.isNotEmpty &&
              !RegExp(r'^ref=[A-Za-z0-9_-]+$').hasMatch(tail.single))) {
        return null;
      }
      final creativeAsin = parameters['creativeASIN']?.single;
      if (creativeAsin != null && creativeAsin != item.asin) return null;
    } else if (item.searchTerm != null) {
      if (uri.path != '/s' ||
          parameters['k']?.single != item.searchTerm ||
          parameters.containsKey('creativeASIN'))
        return null;
    } else {
      return null;
    }
    return uri;
  } on FormatException {
    return null;
  }
}
