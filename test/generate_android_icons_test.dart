import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_queue/widgets/virtual_queue_logo.dart';

void main() {
  testWidgets('Generate Android icons', (WidgetTester tester) async {
    // Android icon specifications
    final androidIcons = {
      'mdpi': 48, // 1x
      'hdpi': 72, // 1.5x
      'xhdpi': 96, // 2x
      'xxhdpi': 144, // 3x
      'xxxhdpi': 192, // 4x
    };

    // Base directory for Android resources
    final resDir = Directory('android/app/src/main/res');
    if (!resDir.existsSync()) {
      print('Creating Android resource directory');
      resDir.createSync(recursive: true);
    }

    // Generate icons for each density
    for (final entry in androidIcons.entries) {
      final dpi = entry.key;
      final size = entry.value.toDouble();

      // Create mipmap directory for this density
      final iconDir = Directory('${resDir.path}/mipmap-$dpi');
      if (!iconDir.existsSync()) {
        print('Creating directory: ${iconDir.path}');
        iconDir.createSync(recursive: true);
      }

      print('Generating icons for $dpi (${size.toInt()}x${size.toInt()})');

      // Generate regular icon
      await _generateAndroidIcon(
        tester,
        size,
        '${iconDir.path}/ic_launcher.png',
        false,
      );

      // Generate adaptive icon background
      await _generateAndroidIcon(
        tester,
        size,
        '${iconDir.path}/ic_launcher_background.png',
        true,
        isBackground: true,
      );

      // Generate adaptive icon foreground
      await _generateAndroidIcon(
        tester,
        size,
        '${iconDir.path}/ic_launcher_foreground.png',
        true,
        isForeground: true,
      );
    }

    // Also generate anydpi-v26 icons for adaptive icon support
    final anydpiDir = Directory('${resDir.path}/mipmap-anydpi-v26');
    if (!anydpiDir.existsSync()) {
      print('Creating directory: ${anydpiDir.path}');
      anydpiDir.createSync(recursive: true);
    }

    // Generate the largest size icons for anydpi
    final size = androidIcons['xxxhdpi']!.toDouble();

    print('Generating adaptive icons for anydpi-v26');

    // Generate background and foreground for adaptive icons
    await _generateAndroidIcon(
      tester,
      size,
      '${anydpiDir.path}/ic_launcher_background.png',
      true,
      isBackground: true,
    );

    await _generateAndroidIcon(
      tester,
      size,
      '${anydpiDir.path}/ic_launcher_foreground.png',
      true,
      isForeground: true,
    );
  });
}

Future<void> _generateAndroidIcon(
  WidgetTester tester,
  double size,
  String outputPath,
  bool isAdaptive, {
  bool isBackground = false,
  bool isForeground = false,
}) async {
  // Clear the test widget tree
  await tester.pumpWidget(Container());

  final repaintKey = GlobalKey();
  final padding = isAdaptive ? size * 0.2 : 0.0;
  final logoSize = size - (padding * 2);

  // Create widget with our logo
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: RepaintBoundary(
            key: repaintKey,
            child: Container(
              width: size,
              height: size,
              color: isBackground ? Colors.deepPurple : Colors.transparent,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: VirtualQueueLogo(
                    size: logoSize,
                    showText: false,
                    primaryColor:
                        isBackground ? Colors.transparent : Colors.deepPurple,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Wait for any animations to complete
  await tester.pumpAndSettle();

  // Capture the widget as an image
  final finder = find.byKey(repaintKey);
  final element = tester.element(finder);
  final renderObject = element.renderObject as RenderRepaintBoundary;
  final image = await renderObject.toImage();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    // Create parent directories if they don't exist
    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    // Write the image to a file
    file.writeAsBytesSync(byteData.buffer.asUint8List());
    print('Generated: $outputPath');
  } else {
    print('Failed to generate: $outputPath');
  }
}
