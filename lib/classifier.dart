import 'package:tflite_flutter/tflite_flutter.dart';

class Classifier {
  var _inputShape;
  var _outputShape;
  var _interpreter;
  var _outputSize = 1;

  dynamic get inputShape => _inputShape;
  dynamic get outputShape => _outputShape;
  dynamic get interpreter => _interpreter;
  dynamic get outputSize => _outputSize;

  Future<Interpreter> loadModel(String path) async {
    try {
      if (_interpreter != null) return _interpreter;
      _interpreter = await Interpreter.fromAsset(path);
      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;

      _outputShape.forEach((e) {
        _outputSize *= e as int;
      });

      return _interpreter;
    } catch (e) {
      throw ('Unable to create interpreter, Caught Exception: $e');
    }
  }

  int run(input) {
    var output = List.filled(_outputSize, 0).reshape(_outputShape);
    _interpreter.run(input, output);
    return _max(output[0]);
  }

  int _max(List<num> list) {
    if (list == null || list.length == 0) {
      throw ("List is empty");
    }
    int index = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i] > list[index]) {
        index = i;
      }
    }
    return index;
  }
}
