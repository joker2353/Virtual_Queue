import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'widgets/virtual_queue_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create assets/icon directory
  final iconDir = Directory('assets/icon');
  if (!iconDir.existsSync()) {
    iconDir.createSync(recursive: true);
  }

  runApp(MaterialApp(home: IconGenerator()));
}

class IconGenerator extends StatefulWidget {
  @override
  _IconGeneratorState createState() => _IconGeneratorState();
}

class _IconGeneratorState extends State<IconGenerator> {
  final _mainIconKey = GlobalKey();
  final _foregroundIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateIcons());
  }

  Future<void> _generateIcons() async {
    // Generate main icon
    await _captureIcon(_mainIconKey, 'assets/icon/icon.png');

    // Generate foreground icon
    await _captureIcon(_foregroundIconKey, 'assets/icon/icon_foreground.png');

    // Exit the app after generating icons
    exit(0);
  }

  Future<void> _captureIcon(GlobalKey key, String outputPath) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final file = File(outputPath);
      file.writeAsBytesSync(byteData.buffer.asUint8List());
      print('Generated: $outputPath');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main icon with background
          RepaintBoundary(
            key: _mainIconKey,
            child: Container(
              width: 1024,
              height: 1024,
              color: Colors.deepPurple,
              child: Center(
                child: SizedBox(
                  width: 720,
                  height: 720,
                  child: VirtualQueueLogo(
                    size: 720,
                    showText: false,
                    primaryColor: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ),
          ),
          // Foreground icon (transparent background)
          RepaintBoundary(
            key: _foregroundIconKey,
            child: Container(
              width: 1024,
              height: 1024,
              color: Colors.transparent,
              child: Center(
                child: SizedBox(
                  width: 720,
                  height: 720,
                  child: VirtualQueueLogo(
                    size: 720,
                    showText: false,
                    primaryColor: Colors.deepPurple,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
