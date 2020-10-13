import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedChevron extends AnimatedWidget {
  final Widget chevron;

  AnimatedChevron(
      {Key key, AnimationController controller, Widget this.chevron})
      : super(key: key, listenable: controller);

  Animation<double> get _progress => listenable;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
        angle: _progress.value * math.pi / 2, child: chevron);
  }
}

// TODO don't violate immutability
class TreeView extends StatefulWidget {
  Widget child;
  List<Widget> subChildren;
  bool collapsed;
  TreeView({Key key, this.child, this.subChildren, this.collapsed = true})
      : super(key: key == null ? UniqueKey() : key);
  @override
  TreeViewState createState() => TreeViewState();
}

class TreeViewState extends State<TreeView> with TickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: Duration(milliseconds: 250), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed)
      _controller.reverse();
    else
      _controller.forward();
    Widget chevron = AnimatedChevron(
        controller: _controller,
        chevron: IconButton(
            icon: Icon(Icons.chevron_right),
            splashRadius: 20,
            tooltip: widget.collapsed ? 'Expand' : 'Collapse',
            onPressed: () {
              setState(() {
                widget.collapsed = !widget.collapsed;
              });
            }));
    return Container(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
          Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [chevron, widget.child]),
          if (!widget.collapsed)
            Container(
                padding: EdgeInsets.only(left: 40),
                alignment: Alignment.topLeft,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.subChildren))
        ]));
  }
}
