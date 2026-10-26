import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const maxPhotoBytes = 15 * 1024 * 1024;

img.Image decodeLeafPhoto(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > maxPhotoBytes) {
    throw const FormatException('Choose a photo smaller than 15 MB.');
  }
  final decoder = img.findDecoderForData(bytes);
  if (decoder is! img.JpegDecoder && decoder is! img.PngDecoder) {
    throw const FormatException('Choose a JPEG or PNG photo.');
  }
  final info = decoder!.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > 12000 ||
      info.height > 12000 ||
      info.width * info.height > 24000000) {
    throw const FormatException('Choose a valid photo up to 24 megapixels.');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) {
    throw const FormatException('This photo could not be decoded.');
  }
  return img.bakeOrientation(decoded);
}

Uint8List leafPreview(img.Image image) {
  final preview = img.copyResize(
    image,
    width: image.width >= image.height ? math.min(image.width, 512) : null,
    height: image.height > image.width ? math.min(image.height, 512) : null,
  );
  return Uint8List.fromList(img.encodeJpg(preview, quality: 85));
}

Uint8List previewPhoto(Uint8List bytes) => leafPreview(decodeLeafPhoto(bytes));
void validateCameraFrame(Uint8List bytes) {
  decodeLeafPhoto(bytes);
}

/// Bound snapshot storage while retaining more detail than the list preview.
Uint8List alertSnapshot(Uint8List bytes) {
  final image = decodeLeafPhoto(bytes);
  final resized = math.max(image.width, image.height) > 1600
      ? img.copyResize(
          image,
          width: image.width >= image.height ? 1600 : null,
          height: image.height > image.width ? 1600 : null,
        )
      : image;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
}
