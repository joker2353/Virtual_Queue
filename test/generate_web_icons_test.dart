import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_queue/widgets/virtual_queue_logo.dart';

void main() {
  testWidgets('Generate web icons', (WidgetTester tester) async {
    // Create web directory if it doesn't exist
    final webDir = Directory('web');
    if (!webDir.existsSync()) {
      webDir.createSync();
    }

    // Create icons directory if it doesn't exist
    final iconsDir = Directory('${webDir.path}/icons');
    if (!iconsDir.existsSync()) {
      iconsDir.createSync();
    }

    // List of icon sizes to generate
    final sizes = [16, 32, 192, 512];

    // Generate favicon
    await _generateIcon(tester, 32, '${webDir.path}/favicon.png');

    // Generate regular and maskable icons
    for (final size in sizes) {
      // Regular icon
      await _generateIcon(
        tester,
        size.toDouble(),
        '${iconsDir.path}/Icon-$size.png',
      );

      // Maskable icon (with padding)
      await _generateIcon(
        tester,
        size.toDouble(),
        '${iconsDir.path}/Icon-maskable-$size.png',
        isMaskable: true,
      );
    }
  });
}

Future<void> _generateIcon(
  WidgetTester tester,
  double size,
  String outputPath, {
  bool isMaskable = false,
}) async {
  // Clear the test widget tree
  await tester.pumpWidget(Container());

  // Calculate actual logo size (smaller for maskable icons to add padding)
  final logoSize = isMaskable ? size * 0.8 : size;

  final repaintKey = GlobalKey();

  // Create a widget with our logo
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        color: isMaskable ? Colors.deepPurple : Colors.transparent,
        child: Center(
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: VirtualQueueLogo(size: logoSize, showText: false),
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
    // Write the image to a file
    final file = File(outputPath);
    file.writeAsBytesSync(byteData.buffer.asUint8List());
    print('Generated: $outputPath');
  }
}
