import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable per-install device id for the 3-device account limit.
class DeviceIdStore {
  DeviceIdStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static final DeviceIdStore instance = DeviceIdStore();

  static const _deviceIdKey = 'device_id';

  final FlutterSecureStorage _storage;

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.length >= 8) {
      return existing;
    }

    final created = _generateId();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }

  String deviceLabel() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  String _generateId() {
    final rand = Random.secure();
    final part = List.generate(16, (_) => rand.nextInt(36).toRadixString(36)).join();
    return 'gotcha_$part';
  }
}
