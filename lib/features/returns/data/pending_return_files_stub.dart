import '../../../core/media/upload_file.dart';
import '../../../core/network/api_exception.dart';

class ReturnDraftFiles {
  static final Map<String, List<UploadFile>> _files = {};
  Future<void> put(String key, List<UploadFile> files) async {
    _files[key] = List.of(files);
  }

  Future<List<UploadFile>> read(String key) async {
    final files = _files[key];
    if (files == null) {
      throw const ApiException(
        'Không tìm thấy ảnh lần gửi trước. Hãy kiểm tra danh sách yêu cầu trước khi gửi lại.',
      );
    }
    return List.of(files);
  }

  Future<void> remove(String key) async {
    _files.remove(key);
  }
}
