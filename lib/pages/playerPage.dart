import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import '../classifier.dart';
import '../imageConvert.dart';
import '../preprocessing.dart';
import '../player.dart';

const facialModel = 'fe93.tflite';
const facialLabel = ['驚喜', '害怕', '噁心', '開心', '傷心', '生氣', '無'];

class PlayerPage extends StatefulWidget {
  PlayerPage({required this.camera});
  final CameraDescription camera;
  _PlayerPageState createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late CameraController cameraCtrl;

  @override
  void initState() {
    cameraCtrl = CameraController(widget.camera, ResolutionPreset.low);
    super.initState();
  }

  @override
  void dispose() {
    cameraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: cameraCtrl.initialize(),
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Player(
              cameraCtrl,
              refresh: refresh,
            );
          } else if (snapshot.connectionState == ConnectionState.active) {
            return Center(child: CircularProgressIndicator());
          }
          return TextButton(
              onPressed: () {
                refresh();
              },
              child: Center(child: Text('重新整埋')));
        });
  }

  void refresh() {
    setState(() {
      cameraCtrl = CameraController(widget.camera, ResolutionPreset.low);
    });
  }
}

class Player extends StatefulWidget {
  Player(this.cameraCtrl, {this.refresh});
  final CameraController cameraCtrl;
  final Function? refresh;
  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late FaceDetector faceDetector;
  String emotion = '';

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
    return Column(children: [
      SizedBox(height: 15),
      Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'カヌレ.mp3',
            style: TextStyle(fontSize: 18),
          )),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: VideoPlayer('https://had.name/data/daily-music/aud/ENq3c.mp3',
              video: false)),
      Text('$emotion'),
      Spacer(),
      Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
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
                      icon: Icon(Icons.camera, color: Colors.white, size: 30),
                      onPressed: () async {
                        if (mounted) _detect();
                      },
                    ))),
    ]);
  }

  Future _stopDetect() async {
    if (mounted) {
      if (widget.cameraCtrl.value.isStreamingImages) {
        widget.cameraCtrl.stopImageStream();
      }
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

          if (faces.length == 0) {
            setState(() {
              emotion = "無人臉";
            });
          }

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
              setState(() {
                emotion = facialLabel[output];
              });
            } else {
              print("interpreter is null");
            }
          }
          lock = false;
        }
      });
    } catch (e) {
      print("----------------------------------------");
      if (widget.refresh != null) {
        widget.refresh!();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('camera controll is null'),
          action: SnackBarAction(
              label: 'close',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              })));
    }
  }
}
