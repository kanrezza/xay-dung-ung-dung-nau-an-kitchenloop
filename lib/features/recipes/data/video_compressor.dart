import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// Kết quả nén: file để tải lên và thời lượng (nếu đọc được).
class CompressedVideo {
  const CompressedVideo(this.file, this.durationMs);
  final File file;
  final int? durationMs;
}

/// Nén video trước khi tải lên (spec 006, FR-004). Tách riêng để test thay bằng bản giả.
abstract class VideoCompressor {
  Future<CompressedVideo> compress(File input);
}

class NativeVideoCompressor implements VideoCompressor {
  @override
  Future<CompressedVideo> compress(File input) async {
    try {
      final info = await VideoCompress.compressVideo(
        input.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final out = info?.file;
      // Nén thất bại hoặc ra file lớn hơn (video vốn đã nhỏ): dùng bản gốc.
      if (out == null || out.lengthSync() >= input.lengthSync()) {
        final meta = await VideoCompress.getMediaInfo(input.path);
        return CompressedVideo(input, meta.duration?.round());
      }
      return CompressedVideo(out, info?.duration?.round());
    } catch (_) {
      return CompressedVideo(input, null);
    }
  }
}
