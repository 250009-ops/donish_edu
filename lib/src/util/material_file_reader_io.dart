import 'dart:io';

Future<List<int>?> readBytesFromPath(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    final f = File(path);
    if (await f.exists()) {
      return await f.readAsBytes();
    }
  } catch (_) {}
  return null;
}
