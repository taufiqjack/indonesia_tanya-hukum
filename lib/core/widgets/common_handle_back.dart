import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:indonesia_law/core/components/toast.dart';

const _exitWindow = Duration(seconds: 2);
DateTime? _lastBackPressedAt;
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

void handleBack(BuildContext context, bool didPop) {
  if (didPop) return;

  // `canPop: false` swallows the pop the drawer would normally consume, so
  // close it here instead of warning about exit.
  final scaffold = _scaffoldKey.currentState;
  if (scaffold != null && scaffold.isDrawerOpen) {
    scaffold.closeDrawer();
    return;
  }

  final now = DateTime.now();
  final last = _lastBackPressedAt;
  if (last != null && now.difference(last) < _exitWindow) {
    SystemNavigator.pop();
    exit(0);
  }

  _lastBackPressedAt = now;
  toast(context, 'Tekan sekali lagi untuk keluar');
}
