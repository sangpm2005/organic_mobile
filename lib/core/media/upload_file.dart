import 'dart:typed_data';

class UploadFile {
  final String name, contentType;
  final Uint8List bytes;
  const UploadFile(this.name, this.contentType, this.bytes);
  bool get isImage => contentType.startsWith('image/');
}
