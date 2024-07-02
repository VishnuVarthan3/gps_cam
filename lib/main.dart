import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'cam.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(MyApp(cameras: _cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("GPS Camera"),
        ),
        body: CameraApp(cameras: cameras),
      
      ),
    );
  }
}
