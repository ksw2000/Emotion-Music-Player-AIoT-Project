import 'package:flutter/material.dart';

class Box extends StatelessWidget {
  Box(
      {required this.x,
      required this.y,
      required this.width,
      required this.height,
      this.child,
      this.ratio = 1.0}); // screen width : photo width

  Box.square(
      {required this.x,
      required this.y,
      required double side,
      this.child,
      this.ratio = 1.0})
      : width = side,
        height = side;

  final double x;
  final double y;
  final double width;
  final double height;
  final double ratio;
  final Widget? child;
  Widget build(BuildContext context) {
    return Positioned(
        left: x * ratio,
        top: y * ratio,
        width: width * ratio,
        height: height * ratio,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
              decoration: BoxDecoration(
            border: Border.all(
              color: Colors.cyan,
              width: 3,
            ),
          )),
          child ?? Container()
        ]));
  }
}
