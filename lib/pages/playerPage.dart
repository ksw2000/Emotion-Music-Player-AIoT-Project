import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import "dart:async";
import "dart:convert" as convert;
import '../classifier.dart';
import '../imageConvert.dart';
import '../preprocessing.dart';
import '../player.dart';
import 'package:http/http.dart' as http;

// model label
// '驚喜', '害怕', '噁心', '開心', '傷心', '生氣', '無'
// music server label
// 1, 0, 3, 1, 2, 3, 4
const facialModel = 'fe93.tflite';
const facialLabel = [1, 0, 3, 1, 2, 3, 4];
const musicServerLabel = ['害怕', '開心', '難過', '生氣', '無表情'];
const noFace = 4;

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
  String musicName = 'カヌレ';
  String musicPath = 'https://had.name/data/daily-music/aud/ENq3c.mp3';
  bool autoPlay = false; // preset is false

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
            musicName,
            style: TextStyle(fontSize: 18),
          )),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: VideoPlayer(
            musicPath,
            autoPlay: autoPlay,
            video: false,
            onEnd: () {
              _detect();
            },
            onError: () {
              snackBar("音樂網址錯誤！瑋哥快去修！", context);
            },
          )),
      Spacer(),
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
                        await _stopDetect([]);
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

  // give each label's number
  Future _stopDetect(score) async {
    if (widget.cameraCtrl.value.isStreamingImages) {
      await widget.cameraCtrl.stopImageStream();
      if (score.length > 0) {
        print(score);
        int maxLabel = 0;
        for (var i = 1; i < score.length; i++) {
          if (score[i] > score[maxLabel]) {
            maxLabel = i;
          }
        }
        print("$maxLabel");
        setState(() {
          if (maxLabel == noFace) {
            emotion = "沒有偵測到您的表情，為您隨機點播";
          } else {
            emotion = "正在為您推薦「${musicServerLabel[maxLabel]}」適合聽的歌";
          }
        });
        await getMusic(maxLabel);
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

    // the numbers of each label
    List score = [0, 0, 0, 0, 0]; // 0 - 4

    try {
      // timeout
      // try to predict in 5 seconds
      new Timer(Duration(seconds: 5), () {
        if (widget.cameraCtrl.value.isStreamingImages) {
          print("5秒到了");
          lock = true;
          _stopDetect(score);
        }
      });

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
              emotion = musicServerLabel[noFace];
              score[noFace] += 1;
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
              if (!lock) {
                setState(() {
                  score[facialLabel[output]] += 1;
                  emotion = musicServerLabel[facialLabel[output]];
                });
              }
            } else {
              print("interpreter is null");
            }
          }
          lock = false;
        }
      });
    } catch (e) {
      widget.refresh!();
      snackBar('$e', context);
    }
  }

  Future getMusic(int label) async {
    var url = Uri.parse(
        'https://listen-with-emotion.herokuapp.com/predict?label=$label');
    var res = await http.get(url);
    if (res.statusCode == 200) {
      try {
        Map data = convert.jsonDecode(res.body);
        print(data);
        setState(() {
          musicName = data["filename"];
          musicPath = data["url"];
          autoPlay = true;
        });
      } catch (e) {
        snackBar('伺服器錯誤', context);
      }
    } else {
      snackBar('網路錯誤 ${res.statusCode}', context);
    }
  }
}

void snackBar(String msg, BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(
          label: 'close',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          })));
}
