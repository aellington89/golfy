// Just enough PNG reading for the branding tests (#71): the IHDR size, and the
// colour of a 1x1 RGB/RGBA image (the splash background bitmaps). No image
// package needed: a PNG is a signature then length-prefixed chunks, and IDAT
// is plain zlib.
import 'dart:io';
import 'dart:typed_data';

const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

class PngInfo {
  PngInfo(this.width, this.height, this.colorType, this.idat);

  final int width;
  final int height;

  /// 2 = RGB, 6 = RGBA (the two the generators write).
  final int colorType;

  /// Every IDAT chunk's data, concatenated (still zlib-compressed).
  final Uint8List idat;

  /// The colour of a 1x1, 8-bit RGB or RGBA image as `#RRGGBB`.
  String get singlePixelHex {
    if (width != 1 || height != 1) {
      throw StateError('not a 1x1 image: ${width}x$height');
    }
    // One scanline: a filter-type byte, then the pixel. A lone pixel has no
    // neighbour to the left or above, so every filter (None, Sub, Up,
    // Average, Paeth) predicts 0 and leaves its bytes unchanged.
    final row = zlib.decode(idat);
    if (row[0] > 4) throw StateError('invalid PNG filter ${row[0]}');
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${hex(row[1])}${hex(row[2])}${hex(row[3])}';
  }
}

PngInfo readPng(File file) {
  final bytes = file.readAsBytesSync();
  for (var i = 0; i < _signature.length; i++) {
    if (bytes[i] != _signature[i]) {
      throw FormatException('not a PNG: ${file.path}');
    }
  }
  final data = ByteData.sublistView(bytes);
  int? width, height, colorType;
  final idat = BytesBuilder();
  var offset = _signature.length;
  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    final body = offset + 8;
    if (type == 'IHDR') {
      width = data.getUint32(body);
      height = data.getUint32(body + 4);
      colorType = bytes[body + 9];
    } else if (type == 'IDAT') {
      idat.add(Uint8List.sublistView(bytes, body, body + length));
    } else if (type == 'IEND') {
      break;
    }
    offset = body + length + 4; // + CRC
  }
  if (width == null) throw FormatException('no IHDR: ${file.path}');
  return PngInfo(width, height!, colorType!, idat.toBytes());
}
