// Generates every launcher icon from the app's own mascot artwork.
//
// Run from the repository root:
//
//   flutter test tool/generate_app_icons.dart
//
// Why `flutter test`: it is the only headless way to get Flutter's real
// rendering pipeline (dart:ui) without a device, so the icons are drawn by the
// same `ChameleonMascot` widget the home screen shows. This file is not a test.
// Plain `flutter test` only scans test/, so CI never runs it; re-run it by hand
// whenever the mascot or the brand colour changes, then commit the results.
//
// Why no icon package: the team keeps third-party dependencies to a minimum,
// and everything needed here (rasterising, PNG encoding) is small enough to do
// with Flutter itself plus dart:io's zlib.
//
// The script writes:
//   * Android legacy icons (mipmap-*/ic_launcher.png) for API < 26;
//   * an Android adaptive icon (API 26+): a foreground PNG per density plus a
//     background colour resource, wired by mipmap-anydpi-v26/ic_launcher.xml;
//   * the iOS AppIcon.appiconset PNGs (opaque, no alpha channel, because App
//     Store Connect rejects icons with transparency);
//   * the web favicon and PWA icons, including the maskable variants.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/game/widgets/game_widgets.dart';

/// Icon background. The home screen shows the mascot on this purple card, and
/// web/manifest.json already uses it as the theme colour.
const Color iconBackground = AppColors.purple;

/// ChameleonMascot's own logical size (see its SizedBox in game_widgets.dart).
const Size mascotSize = Size(280, 165);

/// Every icon is composed on this logical square, then rasterised at
/// pixelRatio = pixels / canvasSide. Drawing the vector art directly at each
/// target size keeps small icons crisp instead of downscaling one bitmap.
const double canvasSide = 1024;

enum Alpha { keep, forbid }

/// How one family of icons looks. [contentWidth] is the fraction of the icon
/// width the mascot's visible pixels span; [circleSafeZone], when set,
/// overrides it with the largest size whose bounding box fits inside a centred
/// circle of that diameter fraction (the platform's mask-safe zone).
class IconStyle {
  const IconStyle({
    this.background,
    this.cornerRadius = 0,
    this.contentWidth = 0.8,
    this.circleSafeZone,
    required this.alpha,
  });

  final Color? background;
  final double cornerRadius; // Fraction of the side; 0 = square corners.
  final double contentWidth;
  final double? circleSafeZone;
  final Alpha alpha;
}

/// Rounded purple tile; the corners stay transparent.
const tile = IconStyle(
  background: iconBackground,
  cornerRadius: 0.2,
  alpha: Alpha.keep,
);

/// Full-bleed opaque square: iOS applies its own corner mask.
const iosSquare = IconStyle(background: iconBackground, alpha: Alpha.forbid);

/// Android adaptive foreground: 108dp canvas, launchers may crop anything
/// outside the central 66dp circle.
const adaptiveForeground = IconStyle(
  circleSafeZone: 66 / 108,
  alpha: Alpha.keep,
);

/// Web maskable icon: the safe zone is a circle of 80% of the icon's width.
const maskable = IconStyle(
  background: iconBackground,
  circleSafeZone: 0.8,
  alpha: Alpha.keep,
);

class IconSpec {
  const IconSpec(this.path, this.pixels, this.style);
  final String path;
  final int pixels;
  final IconStyle style;
}

const androidRes = 'android/app/src/main/res';
const iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// Android densities and their scale relative to mdpi.
const androidDensities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// iOS files already listed in AppIcon.appiconset/Contents.json, with sizes.
const iosFiles = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

List<IconSpec> allIcons() => [
  for (final MapEntry(key: density, value: scale) in androidDensities.entries)
    IconSpec(
      '$androidRes/mipmap-$density/ic_launcher.png',
      (48 * scale).round(),
      tile,
    ),
  for (final MapEntry(key: density, value: scale) in androidDensities.entries)
    IconSpec(
      '$androidRes/mipmap-$density/ic_launcher_foreground.png',
      (108 * scale).round(),
      adaptiveForeground,
    ),
  for (final MapEntry(key: name, value: pixels) in iosFiles.entries)
    IconSpec('$iosIcons/$name', pixels, iosSquare),
  const IconSpec('web/favicon.png', 16, tile),
  const IconSpec('web/icons/Icon-192.png', 192, tile),
  const IconSpec('web/icons/Icon-512.png', 512, tile),
  const IconSpec('web/icons/Icon-maskable-192.png', 192, maskable),
  const IconSpec('web/icons/Icon-maskable-512.png', 512, maskable),
];

void main() {
  testWidgets('generate app icons', (tester) async {
    // Paths below are relative to the package root, which is where
    // `flutter test` runs. Refuse to scatter files anywhere else.
    if (!File('pubspec.yaml').existsSync() ||
        !Directory(androidRes).existsSync()) {
      fail('Run this from the repository root.');
    }

    tester.view.physicalSize = const Size(canvasSide, canvasSide);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The painter's 280x165 box has empty margins, so centre and size the
    // icon on the pixels actually drawn rather than on the box.
    final visible = await measureVisibleArt(tester);
    debugPrint('Mascot visible bounds (logical): $visible');

    for (final icon in allIcons()) {
      final image = await capture(
        tester,
        composeIcon(icon.style, visible),
        pixelRatio: icon.pixels / canvasSide,
      );
      final png = await encodeImage(tester, image, icon.style.alpha, icon.path);
      File(icon.path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png);
      debugPrint('wrote ${icon.path} (${image.width}x${image.height})');
      image.dispose();
    }

    // The adaptive icon's background layer is a colour resource. Generate it
    // from the same constant so the PNGs and the XML cannot drift apart.
    final colorFile = File('$androidRes/values/ic_launcher_background.xml');
    colorFile.writeAsStringSync(
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<!-- Generated by tool/generate_app_icons.dart from AppColors.purple. -->\n'
      '<resources>\n'
      '    <color name="ic_launcher_background">#${rgbHex(iconBackground)}</color>\n'
      '</resources>\n',
    );
    debugPrint('wrote ${colorFile.path}');
  });
}

final GlobalKey _boundaryKey = GlobalKey();

/// Pumps [child] inside a repaint boundary and rasterises that boundary.
Future<ui.Image> capture(
  WidgetTester tester,
  Widget child, {
  required double pixelRatio,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: _boundaryKey, child: child),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  return boundary.toImageSync(pixelRatio: pixelRatio);
}

/// Finds the rectangle, in the mascot's own 280x165 coordinates, that holds
/// every visibly drawn pixel. Rendered on a transparent background at 8x so
/// the measurement is accurate to an eighth of a logical pixel.
Future<Rect> measureVisibleArt(WidgetTester tester) async {
  const scale = 8.0;
  final image = await capture(
    tester,
    SizedBox.fromSize(size: mascotSize, child: const ChameleonMascot()),
    pixelRatio: scale,
  );
  final rgba = await readRgba(tester, image);
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      // Ignore faint anti-aliasing fringes when deciding what is "drawn".
      if (rgba[(y * image.width + x) * 4 + 3] > 16) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  image.dispose();
  if (maxX < 0) fail('The mascot rendered no visible pixels.');
  return Rect.fromLTRB(
    minX / scale,
    minY / scale,
    (maxX + 1) / scale,
    (maxY + 1) / scale,
  );
}

/// Lays the mascot out on a [canvasSide] square according to [style].
Widget composeIcon(IconStyle style, Rect visible) {
  var widthFraction = style.contentWidth;
  final safe = style.circleSafeZone;
  if (safe != null) {
    // A box of width w and height w*r fits in a circle of diameter d when its
    // diagonal w*sqrt(1 + r^2) <= d. The art's corners are not empty (the
    // branch runs the full width), so fit the whole box, not just the body.
    final aspect = visible.height / visible.width;
    widthFraction = safe / math.sqrt(1 + aspect * aspect);
  }
  // Mascot units to canvas units.
  final k = widthFraction * canvasSide / visible.width;
  final center = visible.center;
  final background = style.background;
  return SizedBox.square(
    dimension: canvasSide,
    child: Stack(
      children: [
        if (background != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(
                  style.cornerRadius * canvasSide,
                ),
              ),
            ),
          ),
        Positioned(
          left: canvasSide / 2 - center.dx * k,
          top: canvasSide / 2 - center.dy * k,
          width: mascotSize.width * k,
          height: mascotSize.height * k,
          child: const FittedBox(child: ChameleonMascot()),
        ),
      ],
    ),
  );
}

/// Unpremultiplied RGBA bytes. Reading pixels back is real async work, so it
/// must escape the test's fake-async zone.
Future<Uint8List> readRgba(WidgetTester tester, ui.Image image) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  if (data == null) fail('Could not read back rendered pixels.');
  return data.buffer.asUint8List();
}

Future<Uint8List> encodeImage(
  WidgetTester tester,
  ui.Image image,
  Alpha alpha,
  String path,
) async {
  final rgba = await readRgba(tester, image);
  if (alpha == Alpha.forbid) {
    // Guard: an opaque icon must really be opaque before the alpha channel is
    // dropped, or transparent pixels would silently turn black.
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 255) fail('$path has a non-opaque pixel at byte $i.');
    }
  }
  return encodePng(
    image.width,
    image.height,
    rgba,
    keepAlpha: alpha == Alpha.keep,
  );
}

/// Minimal PNG encoder: 8-bit RGB or RGBA, no filtering, zlib from dart:io.
/// dart:ui can encode PNG itself but always writes an alpha channel, which the
/// iOS icons must not have; one encoder for everything keeps output uniform
/// and byte-for-byte reproducible between runs.
Uint8List encodePng(
  int width,
  int height,
  Uint8List rgba, {
  required bool keepAlpha,
}) {
  final channels = keepAlpha ? 4 : 3;
  final raw = Uint8List(height * (1 + width * channels));
  var o = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 0; // Filter type 0 (None) for this scanline.
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw[o++] = rgba[i];
      raw[o++] = rgba[i + 1];
      raw[o++] = rgba[i + 2];
      if (keepAlpha) raw[o++] = rgba[i + 3];
    }
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // Bit depth.
    ..setUint8(9, keepAlpha ? 6 : 2) // Colour type: 6 = RGBA, 2 = RGB.
    ..setUint8(10, 0) // Compression: deflate.
    ..setUint8(11, 0) // Filter method: adaptive (per-scanline byte above).
    ..setUint8(12, 0); // No interlace.

  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _writeChunk(out, 'IHDR', header.buffer.asUint8List());
  _writeChunk(out, 'IDAT', ZLibEncoder(level: 9).convert(raw));
  _writeChunk(out, 'IEND', const []);
  return out.takeBytes();
}

void _writeChunk(BytesBuilder out, String type, List<int> data) {
  final typeBytes = type.codeUnits;
  out
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(typeBytes)
    ..add(data)
    ..add(
      (ByteData(
        4,
      )..setUint32(0, _crc32([...typeBytes, ...data]))).buffer.asUint8List(),
    );
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

String rgbHex(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();
