import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:virtual_queue/widgets/virtual_queue_logo.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

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

    // Generate icons
    await generateIcon(
      size: size,
      outputPath: '${iconDir.path}/ic_launcher.png',
      isAdaptive: false,
    );

    await generateIcon(
      size: size,
      outputPath: '${iconDir.path}/ic_launcher_background.png',
      isAdaptive: true,
      isBackground: true,
    );

    await generateIcon(
      size: size,
      outputPath: '${iconDir.path}/ic_launcher_foreground.png',
      isAdaptive: true,
      isForeground: true,
    );
  }

  print('Icon generation completed!');
}

Future<void> generateIcon({
  required double size,
  required String outputPath,
  required bool isAdaptive,
  bool isBackground = false,
  bool isForeground = false,
}) async {
  final padding = isAdaptive ? size * 0.2 : 0.0;
  final logoSize = size - (padding * 2);

  final widget = Material(
    color: Colors.transparent,
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
            primaryColor: isBackground ? Colors.transparent : Colors.deepPurple,
          ),
        ),
      ),
    ),
  );

  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());

  final view = View.of(WidgetsBinding.instance.rootElement!);
  final renderView = RenderView(
    view: view,
    configuration: ViewConfiguration(devicePixelRatio: view.devicePixelRatio),
  );

  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: renderView,
    child: widget,
  ).attachToRenderTree(buildOwner);

  buildOwner.buildScope(rootElement);
  buildOwner.finalizeTree();

  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();

  final renderObject = rootElement.renderObject as RenderRepaintBoundary;
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
