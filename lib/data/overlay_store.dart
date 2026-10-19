import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OverlayStore {
  Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'overlays'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(String fileName) async {
    final dir = await _dir();
    return File(p.join(dir.path, fileName));
  }

  Future<String> savePickedBytes(List<int> bytes, String suggestedName) async {
    final safe = suggestedName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_$safe';
    final file = await fileFor(name);
    await file.writeAsBytes(bytes, flush: true);
    return name;
  }
}
