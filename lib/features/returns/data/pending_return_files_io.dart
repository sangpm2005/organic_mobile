import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/media/upload_file.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

class ReturnDraftFiles {
  Future<Directory> _directory(String key) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw const ApiException('Mã lần gửi chưa hợp lệ.');
    }
    final base = await getApplicationSupportDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}organicfood_return_$key',
    );
  }

  Future<void> put(String key, List<UploadFile> files) async {
    final dir = await _directory(key);
    await dir.create(recursive: true);
    final manifest = <Json>[];
    for (var i = 0; i < files.length; i++) {
      await File('${dir.path}/$i.bin')
          .writeAsBytes(files[i].bytes, flush: true);
      manifest.add({
        'name': files[i].name,
        'contentType': files[i].contentType,
      });
    }
    await File('${dir.path}/manifest.json')
        .writeAsString(jsonEncode(manifest), flush: true);
  }

  Future<List<UploadFile>> read(String key) async {
    try {
      final dir = await _directory(key), files = <UploadFile>[];
      final manifest = objects(
        jsonDecode(await File('${dir.path}/manifest.json').readAsString()),
      );
      for (var i = 0; i < manifest.length; i++) {
        final m = manifest[i];
        files.add(
          UploadFile(
            '${m['name']}',
            '${m['contentType']}',
            await File('${dir.path}/$i.bin').readAsBytes(),
          ),
        );
      }
      return files;
    } catch (_) {
      throw const ApiException(
        'Chưa đọc được ảnh của lần gửi trước. Hãy kiểm tra danh sách yêu cầu trước khi gửi mới.',
      );
    }
  }

  Future<void> remove(String key) async {
    final dir = await _directory(key);
    if (!await dir.exists()) return;
    // Delete only fixed files in this validated, app-owned draft directory.
    for (var i = 0; i < 5; i++) {
      final file = File('${dir.path}/$i.bin');
      if (await file.exists()) await file.delete();
    }
    final manifest = File('${dir.path}/manifest.json');
    if (await manifest.exists()) await manifest.delete();
    await dir.delete();
  }
}
