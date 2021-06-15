import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'pages/cameraPage.dart';
import 'pages/playerPage.dart';
import 'package:flutter/services.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  CameraDescription camera = cameras.first;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(MyApp(camera: camera));
  });
}

class MyApp extends StatelessWidget {
  MyApp({required this.camera});
  final CameraDescription camera;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Emotion music player',
        theme: ThemeData(
          primarySwatch: Colors.cyan,
        ),
        home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.play_arrow)),
                    Tab(icon: Icon(Icons.camera_alt)),
                  ],
                ),
                title: Text("Emotion music player",
                    style: TextStyle(color: Colors.white)),
              ),
              body: TabBarView(
                children: [
                  PlayerPage(camera: camera),
                  CameraPage(camera: camera),
                ],
              ),
            )));
  }
}
