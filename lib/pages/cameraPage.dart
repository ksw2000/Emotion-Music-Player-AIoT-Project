import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import '../classifier.dart';
import '../imageConvert.dart';
import '../preprocessing.dart';
import '../box.dart';

const facialModel = 'fe93.tflite';
const facialLabel = ['驚喜', '害怕', '噁心', '開心', '傷心', '生氣', '無'];

class MyCameraPreview extends StatefulWidget {
  MyCameraPreview(this.cameraCtrl, {this.refresh});
  final CameraController cameraCtrl;
  final Function? refresh;
  @override
  _MyCameraPreviewState createState() => _MyCameraPreviewState();
}

class _MyCameraPreviewState extends State<MyCameraPreview> {
  late FaceDetector faceDetector;
  List<Widget> boxList = [];

  @override
  void initState() {
    super.initState();
    faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions());
  }

  @override
  void dispose() {
    faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      CameraPreview(widget.cameraCtrl),
      Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
              padding: EdgeInsets.all(10),
              child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.cyan,
                    shape: BoxShape.circle,
                  ),
                  child: (widget.cameraCtrl.value.isStreamingImages)
                      ? IconButton(
                          icon: Icon(Icons.stop, color: Colors.white, size: 30),
                          onPressed: () async {
                            await _stopDetect();
                            setState(() {});
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.radio_button_checked,
                              color: Colors.white, size: 30),
                          onPressed: () async {
                            if (mounted) _detect();
                          },
                        )))),
    ];
    children.addAll(boxList);

    return Stack(children: children);
  }

  Future _stopDetect() async {
    if (widget.cameraCtrl.value.isStreamingImages) {
      await widget.cameraCtrl.stopImageStream();
      widget.refresh!();
    }
  }

  Future _detect() async {
    bool lock = false;
    Classifier cls = Classifier();
    try {
      await cls.loadModel(facialModel);
    } catch (e) {
      print(e);
    }

    try {
      widget.cameraCtrl.startImageStream((CameraImage cameraImg) async {
        setState(() {});
        if (!lock) {
          lock = true;
          final WriteBuffer allBytes = WriteBuffer();
          for (Plane plane in cameraImg.planes) {
            allBytes.putUint8List(plane.bytes);
          }
          final InputImage visionImage = InputImage.fromBytes(
              bytes: allBytes.done().buffer.asUint8List(),
              inputImageData: InputImageData(
                  size: Size(
                      cameraImg.width.toDouble(), cameraImg.height.toDouble()),
                  imageRotation: InputImageRotation.Rotation_90deg));
          final List<Face> faces = await faceDetector.processImage(visionImage);

          img.Image convertedImg = ImageUtils.convertCameraImage(cameraImg);
          img.Image rotationImg = img.copyRotate(convertedImg, 90);

          boxList = [];
          for (Face face in faces) {
            final Rect boundingBox = face.boundingBox;
            double faceRange = boundingBox.bottom - boundingBox.top;

            if (cls.interpreter != null) {
              img.Image croppedImage = img.copyCrop(
                  rotationImg,
                  boundingBox.left.toInt(),
                  boundingBox.top.toInt(),
                  faceRange.toInt(),
                  faceRange.toInt());

              img.Image resultImage = img.copyResize(croppedImage,
                  width: cls.inputShape[1], height: cls.inputShape[2]);

              var input = ImagePrehandle.uint32ListToRGB3D(resultImage);
              var output = cls.run([input]);
              print(facialLabel[output]);

              boxList.add(Box.square(
                  x: boundingBox.left,
                  y: boundingBox.top,
                  side: boundingBox.bottom - boundingBox.top,
                  ratio: MediaQuery.of(context).size.width / cameraImg.height,
                  child: Positioned(
                      top: -25,
                      left: 0,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${facialLabel[output]}",
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    backgroundColor: Colors.cyan))
                          ]))));
            } else {
              print("interpreter is null");
            }
          }
          lock = false;
        }
      });
    } on CameraException catch (e) {
      print("----------------------------------------");
      if (widget.refresh != null) {
        widget.refresh!();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          action: SnackBarAction(
              label: 'close',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              })));
    }
  }
}
