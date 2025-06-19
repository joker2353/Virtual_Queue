import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // Android icon specifications
  final androidIcons = {
    'mdpi': 48, // 1x
    'hdpi': 72, // 1.5x
    'xhdpi': 96, // 2x
    'xxhdpi': 144, // 3x
    'xxxhdpi': 192, // 4x
  };

  // Create a base icon image (purple circle with white border)
  final baseIcon = _createBaseIcon(1024);

  // Save the base icon
  final iconDir = Directory('assets/icon');
  if (!iconDir.existsSync()) {
    iconDir.createSync(recursive: true);
  }

  File('${iconDir.path}/icon.png').writeAsBytesSync(img.encodePng(baseIcon));
  print('Generated: ${iconDir.path}/icon.png');

  // Create foreground icon (just the logo without background)
  final foregroundIcon = _createForegroundIcon(1024);
  File(
    '${iconDir.path}/icon_foreground.png',
  ).writeAsBytesSync(img.encodePng(foregroundIcon));
  print('Generated: ${iconDir.path}/icon_foreground.png');

  // Generate Android icons
  final resDir = Directory('android/app/src/main/res');
  for (final entry in androidIcons.entries) {
    final dpi = entry.key;
    final size = entry.value;

    final iconDir = Directory('${resDir.path}/mipmap-$dpi');
    if (!iconDir.existsSync()) {
      iconDir.createSync(recursive: true);
    }

    // Resize and save the icon
    final resizedIcon = img.copyResize(baseIcon, width: size, height: size);
    File(
      '${iconDir.path}/ic_launcher.png',
    ).writeAsBytesSync(img.encodePng(resizedIcon));
    print('Generated: ${iconDir.path}/ic_launcher.png');

    // Generate adaptive icon components
    final resizedForeground = img.copyResize(
      foregroundIcon,
      width: size,
      height: size,
    );
    File(
      '${iconDir.path}/ic_launcher_foreground.png',
    ).writeAsBytesSync(img.encodePng(resizedForeground));
    print('Generated: ${iconDir.path}/ic_launcher_foreground.png');

    // Create solid purple background
    final background = img.Image(width: size, height: size);
    img.fill(background, color: img.ColorRgba8(103, 58, 183, 255)); // #673AB7
    File(
      '${iconDir.path}/ic_launcher_background.png',
    ).writeAsBytesSync(img.encodePng(background));
    print('Generated: ${iconDir.path}/ic_launcher_background.png');
  }
}

img.Image _createBaseIcon(int size) {
  final icon = img.Image(width: size, height: size);

  // Fill with transparent background
  img.fill(icon, color: img.ColorRgba8(0, 0, 0, 0));

  // Draw purple circle
  img.fillCircle(
    icon,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: size ~/ 2,
    color: img.ColorRgba8(103, 58, 183, 255), // #673AB7
  );

  // Draw stylized "VQ" text
  _drawText(icon, 'VQ', size);

  return icon;
}

img.Image _createForegroundIcon(int size) {
  final icon = img.Image(width: size, height: size);

  // Fill with transparent background
  img.fill(icon, color: img.ColorRgba8(0, 0, 0, 0));

  // Draw stylized "VQ" text in purple
  _drawText(icon, 'VQ', size, color: img.ColorRgba8(103, 58, 183, 255));

  return icon;
}

void _drawText(
  img.Image image,
  String text,
  int size, {
  img.ColorRgba8? color,
}) {
  final textColor = color ?? img.ColorRgba8(255, 255, 255, 255);

  // Draw text centered using drawString utility
  img.drawString(
    image,
    text,
    font: img.arial24,
    x: size ~/ 4,
    y: size ~/ 4,
    color: textColor,
  );
}
