import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<(int, int, Uint8List)> _load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (img.width, img.height, bd!.buffer.asUint8List());
}

/// Downsamples the image to [cols] x [rows] and prints an ASCII map:
/// ' ' transparent, '.' light/white, '#' red/dark mid, '@' dark solid.
void _printMap(int w, int h, Uint8List px, {int cols = 72, int rows = 26}) {
  final cellW = w / cols;
  final cellH = h / rows;
  for (var ry = 0; ry < rows; ry++) {
    final buf = StringBuffer();
    for (var cx = 0; cx < cols; cx++) {
      var a = 0, r = 0, g = 0, b = 0, n = 0;
      final x0 = (cx * cellW).floor(), x1 = (((cx + 1) * cellW).ceil()).clamp(0, w);
      final y0 = (ry * cellH).floor(), y1 = (((ry + 1) * cellH).ceil()).clamp(0, h);
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          if (px[i + 3] > 40) {
            a += px[i + 3];
            r += px[i];
            g += px[i + 1];
            b += px[i + 2];
            n++;
          }
        }
      }
      if (n == 0) {
        buf.write(' ');
        continue;
      }
      final ar = a / n, rr = r / n, gr = g / n, br = b / n;
      final coverage = ar / 255;
      final redish = rr > 110 && rr > gr + 40 && rr > br + 40;
      final bright = rr + gr + br > 600;
      if (coverage < 0.15) {
        buf.write(bright ? '.' : ':');
      } else if (redish) {
        buf.write(coverage > 0.7 ? 'R' : 'r');
      } else if (bright) {
        buf.write(coverage > 0.7 ? '#' : '+');
      } else {
        buf.write(coverage > 0.7 ? '@' : 'o');
      }
    }
    // ignore: avoid_print
    print('MAP |$buf|');
  }
}

void main() {
  test('probe icon assets', () async {
    const paths = [
      'debug_t4.png',
      'debug_t8.png',
      'debug_t13.png',
      'debug_t20.png',
    ];
    for (final path in paths) {
      if (!File(path).existsSync()) continue;
      final (w, h, px) = await _load(path);
      // ignore: avoid_print
      print('=== $path ($w x $h) ===');
      _printMap(w, h, px);
    }
  });
}
