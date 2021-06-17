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
        home: InitialCamera(camera: camera));
  }
}

class InitialCamera extends StatefulWidget {
  InitialCamera({required this.camera});
  final CameraDescription camera;
  _InitialCameraState createState() => _InitialCameraState();
}

class _InitialCameraState extends State<InitialCamera> {
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
            return Home(
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
              child: Center(child: Text('重新整理')));
        });
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}

class Home extends StatelessWidget {
  Home(this.cameraCtrl, {required this.refresh});
  final CameraController cameraCtrl;
  final Function refresh;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: AppBar(
              bottom: TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.play_arrow, color: Colors.white)),
                  Tab(icon: Icon(Icons.camera_alt, color: Colors.white)),
                ],
              ),
              title: Text(
                "Emotion music player",
                style: TextStyle(color: Colors.white),
              ),
            ),
            body: TabBarView(
              children: [
                Player(cameraCtrl, refresh: refresh),
                MyCameraPreview(cameraCtrl, refresh: refresh),
              ],
            ),
            floatingActionButton: Ink(
                decoration: BoxDecoration(
                  color: Colors.cyan,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.favorite, color: Colors.white),
                  onPressed: () {
                    refresh();
                  },
                ))));
  }
}
