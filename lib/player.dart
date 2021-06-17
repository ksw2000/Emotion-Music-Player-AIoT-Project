import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;
import 'dart:async';

class VideoPlayer extends StatefulWidget {
  VideoPlayer(this.videoPath,
      {this.child,
      this.video = true,
      this.autoPlay = false,
      this.onEnd,
      this.onError});
  final String videoPath;
  final bool autoPlay, video;
  final Widget? child;
  final Function? onEnd;
  final Function? onError;
  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController _controller;
  Duration? _duration, _position;
  bool _isPlaying = false, _isEnd = false;
  String oldPath = '';

  vp.VideoPlayerController initController() {
    vp.VideoPlayerController _newController =
        vp.VideoPlayerController.network("${widget.videoPath}");
    _newController.addListener(() {
      if (_newController.value.hasError) {
        if (mounted) {
          if (widget.onError != null) {
            widget.onError!();
            print(_newController.value.errorDescription);
          }
          setState(() {});
        }
      }

      if (_newController.value.isInitialized) {
        final bool isPlaying = _newController.value.isPlaying;
        if (isPlaying != _isPlaying) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }

        setState(() {
          _duration = _newController.value.duration;
        });

        Timer.run(() {
          setState(() {
            _position = _newController.value.position;
            if (_position != null) {
              if (_duration?.compareTo(_position!) == 0 ||
                  _duration?.compareTo(_position!) == -1) {
                if (widget.onEnd != null) {
                  _isEnd = true;
                  widget.onEnd!();
                }
              } else {
                _isEnd = false;
              }
            }
          });
        });
      }
    });

    _newController.initialize().then((_) {
      oldPath = widget.videoPath;
      // Ensure the first frame is shown after the video is initialized,
      // even before the play button has been pressed.
      if (mounted) {
        if (widget.autoPlay) {
          _newController.seekTo(Duration(seconds: 0));
          _newController.play();
        } else {}
        setState(() {});
      }
    });

    return _newController;
  }

  void initState() {
    super.initState();
    _controller = initController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void reInitialize() async {
    if (_controller.value.isInitialized) {
      await _controller.dispose();
    }
    _controller = initController();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoPath != oldPath) {
      print("Controller update new url: ${widget.videoPath}");
      if (_controller != null && _controller.value.isInitialized) {
        reInitialize();
      }
    }

    if (_controller.value.hasError) {
      return Icon(Icons.error);
    } else if (_controller.value.isInitialized) {
      return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, minWidth: 250),
          child: Column(children: [
            (widget.video)
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: vp.VideoPlayer(_controller),
                  )
                : Container(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: _controller.value.isPlaying && !_isEnd
                    ? Icon(Icons.pause)
                    : Icon(Icons.play_arrow),
                iconSize: 18.0,
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      // if is end, replay
                      if (_isEnd) {
                        _controller.seekTo(Duration(seconds: 0));
                      }
                      _controller.play();
                    }
                  });
                },
              ),
              SizedBox(width: 10),
              // From more info about videoProgressIndicator
              // Head on: https://pub.dev/documentation/video_player/latest/video_player/VideoProgressIndicator-class.html
              Expanded(
                child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: vp.VideoProgressIndicator(_controller,
                        colors: vp.VideoProgressColors(
                          playedColor: Colors.lightGreen,
                          bufferedColor: Colors.lightGreen[100]!,
                          backgroundColor: Colors.grey[300]!,
                        ),
                        allowScrubbing: true)),
              ),
              SizedBox(width: 10),
              Text(
                  '${durationFormatter(_position)} / ${durationFormatter(_duration)}'),
              SizedBox(width: 10),
              widget.child ?? SizedBox(),
            ])
          ]));
    } else {
      return Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: CircularProgressIndicator()));
    }
  }
}

String durationFormatter(Duration? d) {
  if (d == null) return "";
  return (d.inHours == 0)
      ? "${d.inMinutes.remainder(60).toString().padLeft(2, "0")}:${(d.inSeconds.remainder(60)).toString().padLeft(2, "0")}"
      : "${d.inHours.toString().padLeft(2, "0")}:${d.inMinutes.remainder(60).toString().padLeft(2, "0")}:${(d.inSeconds.remainder(60)).toString().padLeft(2, "0")}";
}
