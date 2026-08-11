import 'package:shared_preferences/shared_preferences.dart';

/// One-time migration guard: runs [migrate] at most once per (uid, key)
/// pair, so a device's old SharedPreferences data is copied into Firestore
/// exactly once per account.
class LocalToCloudMigration {
  static Future<void> runOnce({
    required String uid,
    required String key,
    required Future<void> Function() migrate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = 'migrated_${key}_$uid';
    if (prefs.getBool(flagKey) == true) return;
    await migrate();
    await prefs.setBool(flagKey, true);
  }
}
