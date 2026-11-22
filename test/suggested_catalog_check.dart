import '../lib/amazon_affiliate_config.dart' as config;
import '../lib/suggested_catalog.dart';

// Run with standalone Dart. No Flutter, test package, network, or browser is
// used. The .example origins and fixture tag below are fictional test data,
// never live approval settings or an Amazon-assigned Associate identity.
const _fixtureOrigin = 'https://blackbox.example';
const _fixtureTag = 'fixture-only-not-live-20';
int _checks = 0;
final _failures = <String>[];

void check(bool condition, String description) {
  _checks++;
  if (!condition) {
    _failures.add(description);
    print('FAIL: $description');
  }
}

String fixtureLink(SuggestedItem item) => item.isSearch
    ? '${item.amazonUrl}&tag=$_fixtureTag&linkCode=ll2'
    : '${item.amazonUrl}?tag=$_fixtureTag&linkCode=ll1'
          '&creativeASIN=${item.asin}&linkId=static-catalog-fixture';

void main() {
  const expectedIds = {
    'flashlight',
    'weather_radio',
    'manual_can_opener',
    'water_container',
    'whistle',
    'duct_tape',
  };
  final actualIds = suggestedItems.map((item) => item.id).toSet();
  check(
    suggestedItems.length == 6 &&
        actualIds.length == suggestedItems.length &&
        actualIds.containsAll(expectedIds),
    'six stable, unique catalog identities preserve saved checklist references',
  );
  for (final item in suggestedItems) {
    final uri = Uri.parse(item.amazonUrl);
    check(
      item.name.trim().isNotEmpty &&
          item.category.trim().isNotEmpty &&
          item.example.trim().isNotEmpty &&
          item.note.trim().isNotEmpty,
      '${item.id}: original catalog fields are present',
    );
    check(
      uri.scheme == 'https' &&
          const {'amazon.com', 'www.amazon.com'}.contains(uri.host) &&
          uri.userInfo.isEmpty &&
          !uri.hasPort &&
          !uri.hasFragment &&
          !uri.queryParameters.containsKey('tag') &&
          ((item.asin != null) != (item.searchTerm != null)),
      '${item.id}: base link is ordinary US HTTPS with one destination identity',
    );
    check(
      item.asin != null
          ? RegExp(r'^[A-Z0-9]{10}$').hasMatch(item.asin!) &&
                uri.path == '/dp/${item.asin}' &&
                !uri.hasQuery
          : uri.path == '/s' &&
                uri.queryParameters.length == 1 &&
                uri.queryParameters['k'] == item.searchTerm,
      '${item.id}: ordinary link matches the documented product or search',
    );
  }

  final product = suggestedItems.firstWhere((item) => item.id == 'flashlight');
  final search = suggestedItems.firstWhere((item) => item.id == 'whistle');
  final fixtureLinks = {
    for (final item in suggestedItems) item.id: fixtureLink(item),
  };
  const defaults = AmazonLinkSettings();
  final unapprovedWithLinks = AmazonLinkSettings(specialLinks: fixtureLinks);
  for (final settings in [defaults, unapprovedWithLinks]) {
    for (final item in suggestedItems) {
      final web = settings.linkFor(
        item,
        surface: ShoppingSurface.web,
        webOrigin: _fixtureOrigin,
      );
      check(
        web != null && !web.isAffiliate && web.uri.toString() == item.amazonUrl,
        '${item.id}: default web shopping never silently activates commissions',
      );
      for (final surface in [
        ShoppingSurface.ios,
        ShoppingSurface.android,
        ShoppingSurface.other,
      ]) {
        check(
          !settings.canShop(surface) &&
              settings.linkFor(item, surface: surface) == null,
          '${item.id}: unapproved $surface has no Amazon link, tagged or ordinary',
        );
      }
    }
  }

  final enabled = AmazonLinkSettings(
    approvedIosApp: true,
    approvedAndroidApp: true,
    approvedWebOrigins: {_fixtureOrigin},
    specialLinks: fixtureLinks,
  );
  for (final item in suggestedItems) {
    for (final surface in [
      ShoppingSurface.ios,
      ShoppingSurface.android,
      ShoppingSurface.web,
    ]) {
      final link = enabled.linkFor(
        item,
        surface: surface,
        webOrigin: _fixtureOrigin,
      );
      check(
        link != null &&
            link.isAffiliate &&
            link.uri.toString() == fixtureLinks[item.id],
        '${item.id}: approved $surface preserves the supplied static link',
      );
    }
    check(
      !enabled.canShop(ShoppingSurface.other) &&
          enabled.linkFor(item, surface: ShoppingSurface.other) == null,
      '${item.id}: mobile and web approval never enables installed desktop links',
    );
  }

  final iosOnly = AmazonLinkSettings(
    approvedIosApp: true,
    specialLinks: fixtureLinks,
  );
  final androidOnly = AmazonLinkSettings(
    approvedAndroidApp: true,
    specialLinks: fixtureLinks,
  );
  check(
    iosOnly.linkFor(product, surface: ShoppingSurface.android) == null &&
        androidOnly.linkFor(product, surface: ShoppingSurface.ios) == null,
    'approval for one mobile platform does not approve the other',
  );
  for (final supplied in <String?>[
    null,
    '',
    'https://example.invalid/product',
  ]) {
    final settings = AmazonLinkSettings(
      approvedIosApp: true,
      approvedAndroidApp: true,
      approvedWebOrigins: {_fixtureOrigin},
      specialLinks: supplied == null ? {} : {product.id: supplied},
    );
    for (final surface in [
      ShoppingSurface.ios,
      ShoppingSurface.android,
      ShoppingSurface.web,
    ]) {
      final link = settings.linkFor(
        product,
        surface: surface,
        webOrigin: _fixtureOrigin,
      );
      check(
        link != null &&
            !link.isAffiliate &&
            link.uri.toString() == product.amazonUrl,
        'approved $surface uses the ordinary link for missing or invalid config',
      );
    }
  }

  // Exact registration matters even for a syntactically valid remote origin.
  for (final origin in <String?>[
    null,
    'https://other.example',
    'https://blackbox.example.evil.example',
    'https://preview.blackbox.example',
    'https://blackbox.example:8443',
  ]) {
    final link = enabled.linkFor(
      product,
      surface: ShoppingSurface.web,
      webOrigin: origin,
    );
    check(
      link != null && !link.isAffiliate,
      'unregistered origin $origin cannot use an affiliate link',
    );
  }

  // Deliberately include these in the configured set: invalid/local origins
  // must remain disabled even when an administrator accidentally lists them.
  const blockedOrigins = [
    'http://blackbox.example',
    'https://blackbox.example/',
    'https://blackbox.example/path',
    'https://blackbox.example?preview=1',
    'https://blackbox.example#preview',
    'https://user:password@blackbox.example',
    'file:///blackbox.example',
    'http://localhost:8080',
    'https://localhost',
    'https://preview.localhost',
    'https://preview.local',
    'https://localhost.',
    'https://preview.localhost.',
    'https://preview.local.',
    'https://127.0.0.1',
    'https://192.168.1.7',
    'https://8.8.8.8',
    'https://127.1',
    'https://2130706433',
    'https://127.0.0.1.',
    'https://0x7f000001',
    'https://[::1]',
    'https://[::ffff:127.0.0.1]',
    'https://[2001:db8::1]',
    'https://[2001:4860:4860::8888]',
    'not an origin',
  ];
  final badOriginSettings = AmazonLinkSettings(
    approvedWebOrigins: blockedOrigins.toSet(),
    specialLinks: fixtureLinks,
  );
  for (final origin in blockedOrigins) {
    final link = badOriginSettings.linkFor(
      product,
      surface: ShoppingSurface.web,
      webOrigin: origin,
    );
    check(
      link != null &&
          !link.isAffiliate &&
          link.uri.toString() == product.amazonUrl,
      'invalid, local, or IP origin $origin cannot activate affiliate links',
    );
  }

  final asin = product.asin!;
  final productBase = 'https://www.amazon.com/dp/$asin';
  final tagged = '$productBase?tag=$_fixtureTag';
  final validVariants = [
    tagged,
    'https://amazon.com/dp/$asin?tag=$_fixtureTag',
    'https://www.amazon.com/Example-Product_Title/dp/$asin'
        '?tag=$_fixtureTag&linkCode=ll1',
    'https://www.amazon.com/gp/product/$asin/ref=as_li_tl'
        '?tag=$_fixtureTag&linkCode=ll1&camp=1789&creative=9325',
    '$productBase/?tag=$_fixtureTag&language=en_US',
    fixtureLink(product),
  ];
  for (final raw in validVariants) {
    check(
      validateAmazonSpecialLink(product, raw)?.toString() == raw,
      'supported supplied product link is preserved: $raw',
    );
  }

  final invalidProducts = <String, String>{
    'empty': '',
    'whitespace': '$tagged\n',
    'oversized': '$tagged&ref=${'a' * 4096}',
    'wrong host': 'https://example.invalid/dp/$asin?tag=$_fixtureTag',
    'host suffix spoof':
        'https://www.amazon.com.evil.example/dp/$asin?tag=$_fixtureTag',
    'non-US marketplace': 'https://www.amazon.co.uk/dp/$asin?tag=$_fixtureTag',
    'HTTP': 'http://www.amazon.com/dp/$asin?tag=$_fixtureTag',
    'userinfo': 'https://user@www.amazon.com/dp/$asin?tag=$_fixtureTag',
    'password': 'https://user:secret@www.amazon.com/dp/$asin?tag=$_fixtureTag',
    'explicit default port':
        'https://www.amazon.com:443/dp/$asin?tag=$_fixtureTag',
    'nondefault port': 'https://www.amazon.com:8443/dp/$asin?tag=$_fixtureTag',
    'fragment': '$tagged#details',
    'empty fragment': '$tagged#',
    'missing tag': productBase,
    'blank tag': '$productBase?tag=',
    'malformed tag': '$productBase?tag=not%20a%20tag',
    'malformed escape': '$productBase?tag=%E0%A4%A',
    'duplicate tag': '$tagged&tag=another-fixture-20',
    'encoded duplicate tag': '$tagged&%74ag=another-fixture-20',
    'duplicate known parameter': '$tagged&linkCode=ll1&linkCode=ll2',
    'wrong ASIN': 'https://www.amazon.com/dp/B000000000?tag=$_fixtureTag',
    'lowercase ASIN':
        'https://www.amazon.com/dp/${asin.toLowerCase()}?tag=$_fixtureTag',
    'wrong creative ASIN': '$tagged&creativeASIN=B000000000',
    'product replaced with search':
        'https://www.amazon.com/s?k=flashlight&tag=$_fixtureTag',
    'product with search override': '$tagged&k=another+product',
    'unexpected path':
        'https://www.amazon.com/redirect/extra/dp/$asin?tag=$_fixtureTag',
    'extra path tail': '$productBase/extra/path?tag=$_fixtureTag',
    'invalid path tail': '$productBase/arbitrary?tag=$_fixtureTag',
    'unknown query parameter': '$tagged&unexpected=1',
    'user ID': '$tagged&user_id=customer-123',
    'camel-case user ID': '$tagged&userId=customer-123',
    'customer ID': '$tagged&customerId=customer-123',
    'subtag': '$tagged&subtag=customer-123',
    'subid': '$tagged&ascsubtag=customer-123',
    'redirect query': '$tagged&url=https%3A%2F%2Fexample.invalid',
  };
  for (final entry in invalidProducts.entries) {
    check(
      validateAmazonSpecialLink(product, entry.value) == null,
      'product Special Link rejects ${entry.key}',
    );
  }

  final searchLink = fixtureLink(search);
  check(
    validateAmazonSpecialLink(search, searchLink)?.toString() == searchLink,
    'exact catalog search is accepted without changing its tagging',
  );
  final encodedSearch =
      'https://www.amazon.com/s?k=pealess%20emergency%20whistle'
      '&tag=$_fixtureTag';
  check(
    validateAmazonSpecialLink(search, encodedSearch)?.toString() ==
        encodedSearch,
    'equivalent encoded search spaces preserve the supplied URL',
  );
  final invalidSearches = {
    'wrong search': 'https://www.amazon.com/s?k=duct+tape&tag=$_fixtureTag',
    'missing search': 'https://www.amazon.com/s?tag=$_fixtureTag',
    'duplicate search': '$searchLink&k=duct+tape',
    'search path suffix':
        'https://www.amazon.com/s/extra?k=pealess+emergency+whistle'
        '&tag=$_fixtureTag',
    'unexpected creative ASIN': '$searchLink&creativeASIN=$asin',
    'per-user data': '$searchLink&customer_id=customer-123',
    'product instead of search': tagged,
  };
  for (final entry in invalidSearches.entries) {
    check(
      validateAmazonSpecialLink(search, entry.value) == null,
      'search Special Link rejects ${entry.key}',
    );
  }

  // Future real release settings may be enabled. Validate supplied entries
  // instead of requiring the checked-in configuration to remain empty forever.
  for (final entry in config.amazonSpecialLinks.entries) {
    final matches = suggestedItems.where((item) => item.id == entry.key);
    check(
      matches.length == 1,
      'release Special Link ${entry.key} names a known unique catalog item',
    );
    if (matches.length == 1) {
      check(
        validateAmazonSpecialLink(matches.single, entry.value) != null,
        'release Special Link ${entry.key} passes validation',
      );
    }
  }
  print(
    'Release settings: iOS=${config.approvedIosApp}, '
    'Android=${config.approvedAndroidApp}, '
    'web origins=${config.approvedWebOrigins.length}, '
    'Special Links=${config.amazonSpecialLinks.length}.',
  );
  print(
    'Suggested catalog checks: ${_checks - _failures.length}/$_checks passed; '
    '${_failures.length} failed.',
  );
  if (_failures.isNotEmpty) {
    throw StateError('${_failures.length} suggested catalog checks failed.');
  }
}
