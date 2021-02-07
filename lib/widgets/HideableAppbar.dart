
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:LoliSnatcher/SearchGlobals.dart';

class HideableAppBar extends StatefulWidget implements PreferredSizeWidget {
  String title;
  List<Widget> actions;
  SearchGlobals searchGlobals;
  bool autoHide;
  HideableAppBar(this.title, this.actions, this.searchGlobals, this.autoHide);

  double defaultHeight = kToolbarHeight; //56.0
  @override
  Size get preferredSize => Size.fromHeight(defaultHeight);

  @override
  _HideableAppBarState createState() => _HideableAppBarState();
}

class _HideableAppBarState extends State<HideableAppBar> {
  Function setSt;
  @override
  void initState() {
    super.initState();
    setSt = () {
      setState(() {});
    };
    widget.searchGlobals.displayAppbar.value = !widget.autoHide;
    widget.searchGlobals.displayAppbar.addListener(setSt);
  }

  @override
  void dispose() {
    widget.searchGlobals.displayAppbar.removeListener(setSt);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.linear,
      height:
          widget.searchGlobals.displayAppbar.value ? widget.defaultHeight : 0.0,
      child: AppBar(
        // toolbarHeight: widget.defaultHeight,
        leading: IconButton(
          // to ignore icon change
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
        actions: widget.actions,
      ),
    );
  }
}
