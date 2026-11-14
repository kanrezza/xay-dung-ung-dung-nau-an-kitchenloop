import 'dart:typed_data';

/// Video hướng dẫn được cắt thành nhiều mẩu để lưu trong Firestore (spec 006): Cloud Storage của
/// project bị khoá, còn một tài liệu Firestore tối đa 1 MiB. Các giới hạn khớp firestore.rules.
const videoChunkBytes = 750000;
const maxVideoChunks = 28;
const maxVideoBytes = videoChunkBytes * maxVideoChunks; // ~20 MB
const maxVideoDuration = Duration(minutes: 3);

/// Tên tài liệu của mẩu thứ [index]: "{videoId}_07" (đánh số 2 chữ số để sắp xếp đúng).
String videoChunkId(String videoId, int index) => '${videoId}_${index.toString().padLeft(2, '0')}';

/// Cắt [bytes] thành các mẩu ≤ [videoChunkBytes]. Ném [ArgumentError] nếu rỗng hoặc quá lớn.
List<Uint8List> splitVideo(Uint8List bytes) {
  if (bytes.isEmpty) throw ArgumentError('Video rỗng');
  if (bytes.length > maxVideoBytes) throw ArgumentError('Video vượt $maxVideoBytes byte');
  return [
    for (var start = 0; start < bytes.length; start += videoChunkBytes)
      Uint8List.sublistView(bytes, start, start + videoChunkBytes > bytes.length ? bytes.length : start + videoChunkBytes),
  ];
}

/// Ghép các mẩu (đúng thứ tự) thành video.
Uint8List joinVideoChunks(List<Uint8List> chunks) {
  final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final c in chunks) {
    out.setRange(offset, offset + c.length, c);
    offset += c.length;
  }
  return out;
}
