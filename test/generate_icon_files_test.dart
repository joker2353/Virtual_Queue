import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_queue/widgets/virtual_queue_logo.dart';

void main() {
  testWidgets('Generate icon files for launcher icons', (
    WidgetTester tester,
  ) async {
    // Create assets/icon directory
    final iconDir = Directory('assets/icon');
    if (!iconDir.existsSync()) {
      iconDir.createSync(recursive: true);
    }

    // Generate main icon (1024x1024 for best quality)
    await _generateIcon(
      tester,
      1024.0,
      '${iconDir.path}/icon.png',
      showBackground: true,
    );

    // Generate foreground icon for adaptive icon
    await _generateIcon(
      tester,
      1024.0,
      '${iconDir.path}/icon_foreground.png',
      showBackground: false,
    );

    print('Icon files generated successfully!');
  });
}

Future<void> _generateIcon(
  WidgetTester tester,
  double size,
  String outputPath, {
  bool showBackground = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: RepaintBoundary(
          child: Container(
            width: size,
            height: size,
            color: showBackground ? Colors.deepPurple : Colors.transparent,
            child: Center(
              child: SizedBox(
                width: size * 0.7,
                height: size * 0.7,
                child: VirtualQueueLogo(
                  size: size * 0.7,
                  showText: false,
                  primaryColor:
                      showBackground
                          ? Colors.white.withOpacity(0.9)
                          : Colors.deepPurple,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final finder = find.byType(RepaintBoundary);
  final element = tester.element(finder);
  final renderObject = element.renderObject as RenderRepaintBoundary;
  final image = await renderObject.toImage();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsBytesSync(byteData.buffer.asUint8List());
    print('Generated: $outputPath');
  } else {
    print('Failed to generate: $outputPath');
  }
}
