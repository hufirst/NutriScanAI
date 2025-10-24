import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

/// Service for camera operations
///
/// Handles camera initialization, image capture, and temporary storage
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  /// Initialize camera
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw CameraException('NO_CAMERA', 'No cameras available on this device');
      }

      // Use back camera (index 0 usually)
      final camera = _cameras.first;

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize().timeout(
        AppConstants.cameraTimeout,
        onTimeout: () {
          throw CameraException(
            'TIMEOUT',
            'Camera initialization timeout after ${AppConstants.cameraTimeout.inSeconds}s',
          );
        },
      );

      _isInitialized = true;
      debugPrint('Camera initialized successfully');
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Capture image and save to temporary storage
  ///
  /// Returns the file path of the captured image
  Future<String> captureImage() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      throw CameraException('NOT_INITIALIZED', 'Camera is not initialized');
    }

    try {
      // Capture image
      final XFile image = await _controller!.takePicture();

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'nutrition_scan_$timestamp.jpg';
      final filePath = '${tempDir.path}/$fileName';

      // Copy to temporary location
      await File(image.path).copy(filePath);

      debugPrint('Image captured: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Image capture error: $e');
      rethrow;
    }
  }

  /// Get camera controller for preview
  CameraController? get controller => _controller;

  /// Check if camera is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose camera controller
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      debugPrint('Camera disposed');
    }
  }
}
