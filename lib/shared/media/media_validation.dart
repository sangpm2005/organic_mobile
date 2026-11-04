import '../../core/media/upload_file.dart';
import '../../core/network/api_exception.dart';

void validateMedia(
  List<UploadFile> files, {
  bool imagesOnly = false,
  bool required = false,
}) {
  if (required && files.isEmpty) {
    throw const ApiException('Vui lòng thêm ít nhất một ảnh minh chứng.');
  }
  var images = 0, videos = 0;
  for (final file in files) {
    final image = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ].contains(file.contentType);
    final video = ['video/mp4', 'video/webm'].contains(file.contentType);
    if (!image && (!video || imagesOnly)) {
      throw ApiException(
        imagesOnly
            ? 'Chỉ nhận ảnh JPG, PNG hoặc WebP.'
            : 'Chỉ nhận ảnh JPG, PNG, WebP hoặc video MP4, WebM.',
      );
    }
    if (file.bytes.isEmpty ||
        file.bytes.length > (image ? 5 : 50) * 1024 * 1024) {
      throw ApiException(
        image
            ? 'Mỗi ảnh phải có nội dung và tối đa 5 MB.'
            : 'Mỗi video phải có nội dung và tối đa 50 MB.',
      );
    }
    if (image) {
      images++;
    } else {
      videos++;
    }
  }
  if (images > 5 || videos > 1) {
    throw const ApiException('Mỗi nội dung tối đa 5 ảnh và 1 video.');
  }
}
