import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// CameraApp is the Main Application.
class CameraApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  /// Default Constructor
  const CameraApp({super.key, required this.cameras});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  bool isCameraInitialized = false;
  Position? _currentPosition;
  String _currentAddress = '';

  // 

  @override
  void initState() {
    super.initState();
    initializeCamera();
    _requestPermissions();
  }

  Future<void> initializeCamera() async {
    controller = CameraController(widget.cameras[0], ResolutionPreset.max);
    try {
      await controller.initialize();
    } catch (e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      isCameraInitialized = true;
    });
  }

  void _requestPermissions() async {
    if (await Permission.camera.request().isGranted &&
        await Permission.storage.request().isGranted &&
        await Permission.location.request().isGranted) {
      print('All permissions granted');
    } else {
      print('Permission denied');
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    } 

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _getAddressFromLatLng();
  }

  Future<void> _getAddressFromLatLng() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      Placemark place = placemarks[0];
      setState(() {
        _currentAddress = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}";
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> takePicture() async {
    if (!controller.value.isInitialized || _currentPosition == null) {
      return;
    }
    // Ensure the camera is not taking another picture
    if (controller.value.isTakingPicture) {
      return;
    }

    try {
      // Capture the picture and get the file
      final XFile picture = await controller.takePicture();

      // Add watermark to the picture
      File watermarkedImage = await addWatermark(picture);

      // Save the watermarked picture to the gallery
      await GallerySaver.saveImage(watermarkedImage.path);
      print('Picture saved to gallery at ${watermarkedImage.path}');
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<File> addWatermark(XFile picture) async {
    final bytes = await picture.readAsBytes();
    img.Image originalImage = img.decodeImage(Uint8List.fromList(bytes))!;

    // Define watermark text
    String watermarkText =
        'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}\n$_currentAddress';

    // Define font size and padding
    int fontSize = 20;
    int padding = 200;

    // Calculate the size of the text
    int textWidth = watermarkText.length * fontSize;
    int textHeight = fontSize * 2; // Assuming 2 lines of text

    // Calculate the position for the watermark text
    int x = originalImage.width - padding - textWidth;
    int y = originalImage.height - padding - textHeight;

    // Draw background rectangle for the watermark text
    img.fillRect(
      originalImage,
      x - padding,
      y - padding,
      x + textWidth + padding,
      y + textHeight + padding,
      img.getColor(0, 0, 0, 128), // Black background with 50% opacity
    );

    // Draw the watermark text on the image
    img.drawString(
      originalImage,
      img.arial_48,
      x,
      y,
      watermarkText,
      color: img.getColor(255, 255, 255), // White text
      // fontSize: fontSize,
      
    );

    // Get the directory to store pictures
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = join(dirPath, '${DateTime.now().millisecondsSinceEpoch}_watermarked.jpg');

    // Save the modified image to a file
    File watermarkedImageFile = File(filePath);
    watermarkedImageFile.writeAsBytesSync(img.encodeJpg(originalImage));

    return watermarkedImageFile;
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized) {
      return Container();
    }
    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(controller),
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lat: ${_currentPosition?.latitude ?? ""}, Lon: ${_currentPosition?.longitude ?? ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    backgroundColor: Colors.black,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _currentAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    backgroundColor: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _getCurrentLocation();
          await takePicture();
        },
        child: const Icon(Icons.camera),
      ),
    );
  }
}
