import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TireClassifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isLoaded = false;

  // Model input dimensions - adjust these to match YOUR model
  // Most MobileNet-based models use 224x224 or 128x128
  static const int inputSize = 224;

  bool get isLoaded => _isLoaded;

  /// Load the TFLite model and labels
  Future<void> loadModel() async {
    try {
      // Load model bytes from asset bundle
      final modelData = await rootBundle.load('assets/model.tflite');
      final buffer = modelData.buffer.asUint8List();
      
      // Create interpreter from buffer
      _interpreter = Interpreter.fromBuffer(buffer);
      
      // Print model info for debugging
      final inputTensor = _interpreter.getInputTensor(0);
      final outputTensor = _interpreter.getOutputTensor(0);
      print('Model loaded successfully!');
      print('Input shape: ${inputTensor.shape}');
      print('Input type: ${inputTensor.type}');
      print('Output shape: ${outputTensor.shape}');
      print('Output type: ${outputTensor.type}');

      // Load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      print('Labels loaded: $_labels');

      _isLoaded = true;
    } catch (e, stackTrace) {
      print('Error loading model: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Classify an image from bytes
  /// Returns a map of label -> confidence score
  Map<String, double> classifyImage(Uint8List imageBytes) {
    if (!_isLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    // Decode the image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image.');
    }

    // Resize to model input size
    final resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    // Get model input/output info
    final inputTensor = _interpreter.getInputTensor(0);
    final outputTensor = _interpreter.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final outputShape = outputTensor.shape;

    // Prepare input: normalize pixel values to [0, 1] or [-1, 1]
    // depending on your model. Most models use [0, 1].
    final input = _prepareInput(resizedImage, inputShape);

    // Prepare output buffer
    final outputSize = outputShape.last;
    var output = List.filled(outputSize, 0.0).reshape([1, outputSize]);

    // Run inference
    _interpreter.run(input, output);

    // Process results
    final results = <String, double>{};
    final outputList = (output as List)[0] as List;
    
    for (int i = 0; i < outputList.length && i < _labels.length; i++) {
      results[_labels[i]] = (outputList[i] as num).toDouble();
    }

    return results;
  }

  /// Prepare input tensor from image
  List _prepareInput(img.Image image, List<int> inputShape) {
    // inputShape is typically [1, height, width, 3]
    final height = inputShape[1];
    final width = inputShape[2];

    // Create a 4D list [1][height][width][3]
    var input = List.generate(
      1,
      (_) => List.generate(
        height,
        (y) => List.generate(
          width,
          (x) {
            final pixel = image.getPixel(x, y);
            // Normalize to [0, 1] - change to /127.5 - 1 if your model uses [-1, 1]
            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// Get the top prediction label and confidence
  MapEntry<String, double> getTopPrediction(Map<String, double> results) {
    return results.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
  }

  /// Dispose resources
  void dispose() {
    if (_isLoaded) {
      _interpreter.close();
      _isLoaded = false;
    }
  }
}
