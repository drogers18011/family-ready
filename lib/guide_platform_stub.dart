import 'guide_store.dart';

GuideRepository createGuideRepository() => throw const GuideException(
  'Local guide storage is unavailable on this platform.',
);
