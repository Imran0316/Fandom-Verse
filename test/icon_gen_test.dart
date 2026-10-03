import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/* ------------------------------ PNG encoder ------------------------------ */

int _crcUpdate(int c, List<int> bytes) {
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c;
}

final List<int> _crcTable = List<int>.generate(256, (i) {
  var c = i;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

void _chunk(BytesBuilder out, String type, List<int> data) {
  final len = data.length;
  out.add([len >> 24 & 255, len >> 16 & 255, len >> 8 & 255, len & 255]);
  final t = type.codeUnits;
  out.add(t);
  out.add(data);
  final crc = _crcUpdate(_crcUpdate(0xFFFFFFFF, t), data) ^ 0xFFFFFFFF;
  out.add([crc >> 24 & 255, crc >> 16 & 255, crc >> 8 & 255, crc & 255]);
}

/// Encodes straight (non-premultiplied) RGBA pixels as an 8-bit PNG.
Uint8List encodePng(int w, int h, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    raw.add(Uint8List.sublistView(rgba, y * w * 4, (y + 1) * w * 4));
  }
  final idat = ZLibEncoder(level: 9).convert(raw.toBytes());

  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = BytesBuilder()
    ..add([w >> 24 & 255, w >> 16 & 255, w >> 8 & 255, w & 255])
    ..add([h >> 24 & 255, h >> 16 & 255, h >> 8 & 255, h & 255])
    ..add(const [8, 6, 0, 0, 0]); // 8-bit RGBA
  _chunk(out, 'IHDR', ihdr.toBytes());
  _chunk(out, 'IDAT', idat);
  _chunk(out, 'IEND', const []);
  return out.toBytes();
}

/* ------------------------------ image ops -------------------------------- */

Future<(int, int, Uint8List)> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (img.width, img.height, bd!.buffer.asUint8List());
}

/// Area-average downscale in premultiplied space (no dark halos around the
/// transparent emblem). Only used for shrink-to-fit, never upscale.
Uint8List _resize(int sw, int sh, Uint8List src, int dw, int dh) {
  final out = Uint8List(dw * dh * 4);
  for (var dy = 0; dy < dh; dy++) {
    final sy0 = dy * sh / dh;
    final sy1 = (dy + 1) * sh / dh;
    for (var dx = 0; dx < dw; dx++) {
      final sx0 = dx * sw / dw;
      final sx1 = (dx + 1) * sw / dw;
      final iy0 = sy0.floor();
      final iy1 = sy1.ceil().clamp(0, sh);
      final ix0 = sx0.floor();
      final ix1 = sx1.ceil().clamp(0, sw);
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0, area = 0.0;
      for (var sy = iy0; sy < iy1; sy++) {
        final yw = (sy1 < sy + 1 ? sy1 : sy + 1) - (sy0 > sy ? sy0 : sy);
        if (yw <= 0) continue;
        for (var sx = ix0; sx < ix1; sx++) {
          final xw = (sx1 < sx + 1 ? sx1 : sx + 1) - (sx0 > sx ? sx0 : sx);
          if (xw <= 0) continue;
          final wgt = xw * yw;
          final i = (sy * sw + sx) * 4;
          final alpha = src[i + 3] / 255.0;
          r += src[i] * alpha * wgt;
          g += src[i + 1] * alpha * wgt;
          b += src[i + 2] * alpha * wgt;
          a += alpha * wgt;
          area += wgt;
        }
      }
      if (area == 0 || a <= 0) continue;
      final o = (dy * dw + dx) * 4;
      out[o] = (r / a).round().clamp(0, 255);
      out[o + 1] = (g / a).round().clamp(0, 255);
      out[o + 2] = (b / a).round().clamp(0, 255);
      out[o + 3] = (a / area * 255).round().clamp(0, 255);
    }
  }
  return out;
}

/// Alpha-composites [fg] (straight RGBA) at ([ox], [oy]) over [canvas].
void _blit(Uint8List canvas, int cw, Uint8List fg, int fw, int fh, int ox, int oy) {
  for (var y = 0; y < fh; y++) {
    final cy = oy + y;
    if (cy < 0 || cy >= cw) continue;
    for (var x = 0; x < fw; x++) {
      final cx = ox + x;
      if (cx < 0 || cx >= cw) continue;
      final fi = (y * fw + x) * 4;
      final sa = fg[fi + 3];
      if (sa == 0) continue;
      final ci = (cy * cw + cx) * 4;
      final s = sa / 255.0;
      final da = canvas[ci + 3] / 255.0;
      final inv = 1 - s;
      final outA = s + da * inv;
      if (outA <= 0) continue;
      // Straight-alpha over: (Cs*As + Cd*Ad*(1-As)) / Ao.
      canvas[ci] = ((fg[fi] * s + canvas[ci] * da * inv) / outA).round();
      canvas[ci + 1] = ((fg[fi + 1] * s + canvas[ci + 1] * da * inv) / outA).round();
      canvas[ci + 2] = ((fg[fi + 2] * s + canvas[ci + 2] * da * inv) / outA).round();
      canvas[ci + 3] = (outA * 255).round();
    }
  }
}

void _printMap(Uint8List px, int w, int h, {int cols = 64, int rows = 24}) {
  final cellW = w / cols, cellH = h / rows;
  for (var ry = 0; ry < rows; ry++) {
    final buf = StringBuffer();
    for (var cx = 0; cx < cols; cx++) {
      final x0 = (cx * cellW).floor(), x1 = ((cx + 1) * cellW).ceil().clamp(0, w);
      final y0 = (ry * cellH).floor(), y1 = ((ry + 1) * cellH).ceil().clamp(0, h);
      var n = 0, rs = 0, gs = 0, bs = 0, as = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          n++;
          as += px[i + 3];
          rs += px[i];
          gs += px[i + 1];
          bs += px[i + 2];
        }
      }
      final a = as / n;
      final r = rs / n, g = gs / n, b = bs / n;
      if (a < 30) {
        buf.write(' ');
      } else if (r > 110 && r > g + 40 && r > b + 40) {
        buf.write('R');
      } else if (r + g + b > 600) {
        buf.write('#');
      } else if (r + g + b < 120) {
        buf.write('.');
      } else {
        buf.write('o');
      }
    }
    // ignore: avoid_print
    print('ICO |$buf|');
  }
}

/* --------------------------------- main ---------------------------------- */

void main() {
  test('generate launcher icons', () async {
    const source = 'lib/assets/images/fanVerseLogoF.png';
    final (sw, sh, emblem) = await _decode(source);
    // ignore: avoid_print
    print('source $source: ${sw}x$sh');
    final aspect = sw / sh;

    const bg = [0x05, 0x05, 0x08]; // AppColors.backgroundDeep

    // Adaptive-icon foreground: transparent canvas, emblem centred so its
    // outermost ink stays inside the maskable safe zone (radius 33/108).
    const fgDensities = {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };
    for (final entry in fgDensities.entries) {
      final s = entry.value;
      final fw = (0.48 * s).round();
      final fh = (0.48 * s / aspect).round();
      final scaled = _resize(sw, sh, emblem, fw, fh);
      final canvas = Uint8List(s * s * 4);
      _blit(canvas, s, scaled, fw, fh, (s - fw) ~/ 2, (s - fh) ~/ 2);
      final dir = Directory('android/app/src/main/res/drawable-${entry.key}');
      dir.createSync(recursive: true);
      File('${dir.path}/ic_launcher_foreground.png')
          .writeAsBytesSync(encodePng(s, s, canvas));
      // ignore: avoid_print
      print('wrote ${dir.path}/ic_launcher_foreground.png (${s}x$s, art ${fw}x$fh)');
    }

    // Legacy (API <= 25) launcher icons: solid brand background + emblem.
    const legacyDensities = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    Uint8List? preview;
    for (final entry in legacyDensities.entries) {
      final s = entry.value;
      final fw = (0.62 * s).round();
      final fh = (0.62 * s / aspect).round();
      final scaled = _resize(sw, sh, emblem, fw, fh);
      final canvas = Uint8List(s * s * 4);
      for (var i = 0; i < canvas.length; i += 4) {
        canvas[i] = bg[0];
        canvas[i + 1] = bg[1];
        canvas[i + 2] = bg[2];
        canvas[i + 3] = 255;
      }
      _blit(canvas, s, scaled, fw, fh, (s - fw) ~/ 2, (s - fh) ~/ 2);
      if (entry.key == 'xxhdpi') preview = canvas;
      File('android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png')
          .writeAsBytesSync(encodePng(s, s, canvas));
      // ignore: avoid_print
      print('wrote mipmap-${entry.key}/ic_launcher.png (${s}x$s)');
    }

    // Validation: ink radius of the adaptive foreground, in 108-unit space.
    final check = await _decode(
      'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
    );
    final (cw, ch, cpix) = check;
    var maxR = 0.0;
    for (var y = 0; y < ch; y++) {
      for (var x = 0; x < cw; x++) {
        if (cpix[(y * cw + x) * 4 + 3] > 16) {
          final dx = x - cw / 2, dy = y - ch / 2;
          final r = math.sqrt(dx * dx + dy * dy);
          if (r > maxR) maxR = r;
        }
      }
    }
    final units = maxR * 108 / cw;
    // ignore: avoid_print
    print('foreground ink radius = ${units.toStringAsFixed(1)} / 33 units (safe zone)');
    expect(units, lessThan(33.0), reason: 'art must fit the maskable safe zone');

    // ignore: avoid_print
    print('=== legacy xxhdpi preview (dark bg "." art "#" / "R") ===');
    _printMap(preview!, 144, 144);
  });
}
