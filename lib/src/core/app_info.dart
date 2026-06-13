import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App package info (name, version, build number). Loaded once, async.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Publisher details for the About screen.
class Publisher {
  const Publisher._();

  static const String name = 'Võ Đông Hà';
  static const String website = 'https://vodongha.id.vn';
}
