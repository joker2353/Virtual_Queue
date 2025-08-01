import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Create directories
  final iconDir = Directory('assets/icon');
  final resDir = Directory('android/app/src/main/res');

  for (var dir in [iconDir, resDir]) {
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  // Create a simple icon (purple circle)
  final baseIcon = _createIcon(1024);

  // Save high-res icons for launcher_icons
  File('${iconDir.path}/icon.png').writeAsBytesSync(img.encodePng(baseIcon));
  File(
    '${iconDir.path}/icon_foreground.png',
  ).writeAsBytesSync(img.encodePng(baseIcon));

  // Generate Android icons
  final sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  sizes.forEach((dpi, size) {
    final targetDir = Directory('${resDir.path}/mipmap-$dpi');
    targetDir.createSync(recursive: true);

    final resized = img.copyResize(baseIcon, width: size, height: size);
    File(
      '${targetDir.path}/ic_launcher.png',
    ).writeAsBytesSync(img.encodePng(resized));
    print('Generated: ${targetDir.path}/ic_launcher.png');
  });

  print('Icons generated successfully!');
}

img.Image _createIcon(int size) {
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

  return icon;
}
