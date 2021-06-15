import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;
import 'dart:async';

class VideoPlayer extends StatefulWidget {
  VideoPlayer(this.videoPath,
      {this.child, this.video = true, this.autoPlay = false, this.refresh});
  final String videoPath;
  final bool autoPlay, video;
  final Widget? child;
  final Function? refresh;
  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  vp.VideoPlayerController? _controller;
  Duration? _duration, _position;
  bool _isPlaying = false, _isEnd = false, _video = true;

  void initState() {
    super.initState();
    _video = widget.video;
    _controller = vp.VideoPlayerController.network("${widget.videoPath}")
      ..addListener(() {
        final bool isPlaying = _controller!.value.isPlaying;
        if (isPlaying != _isPlaying) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }
        Timer.run(() {
          this.setState(() {
            _position = _controller!.value.position;
          });
        });
        setState(() {
          _duration = _controller!.value.duration;
        });
        if (_position != null) {
          _duration?.compareTo(_position!) == 0 ||
                  _duration?.compareTo(_position!) == -1
              ? this.setState(() {
                  _isEnd = true;
                })
              : this.setState(() {
                  _isEnd = false;
                });
        }
      })
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        if (widget.autoPlay) {
          _controller!.play();
        }
        print("初始化完成");

        if (widget.refresh != null) {
          widget.refresh!();
        }
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: _controller!.value.isInitialized
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 640, minWidth: 250),
                child: Column(children: [
                  (_video)
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: vp.VideoPlayer(_controller!),
                        )
                      : Container(),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(
                      icon: _controller!.value.isPlaying && !_isEnd
                          ? Icon(Icons.pause)
                          : Icon(Icons.play_arrow),
                      iconSize: 18.0,
                      onPressed: () {
                        setState(() {
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play();
                        });
                      },
                    ),
                    SizedBox(width: 10),
                    // From more info about videoProgressIndicator
                    // Head on: https://pub.dev/documentation/video_player/latest/video_player/VideoProgressIndicator-class.html
                    Expanded(
                      child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: vp.VideoProgressIndicator(_controller!,
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
                ]))
            : Container());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

String durationFormatter(Duration? d) {
  if (d == null) return "";
  return (d.inHours == 0)
      ? "${d.inMinutes.remainder(60).toString().padLeft(2, "0")}:${(d.inSeconds.remainder(60)).toString().padLeft(2, "0")}"
      : "${d.inHours.toString().padLeft(2, "0")}:${d.inMinutes.remainder(60).toString().padLeft(2, "0")}:${(d.inSeconds.remainder(60)).toString().padLeft(2, "0")}";
}
