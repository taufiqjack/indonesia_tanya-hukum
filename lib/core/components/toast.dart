import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indonesia_law/core/components/colors_custom.dart';
import 'package:indonesia_law/core/widgets/common_text.dart';

void toast(BuildContext ctx, String text) async {
  FToast fToast = FToast();
  fToast.init(ctx);
  fToast.showToast(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: greyLightFour.withValues(alpha: 0.8))],
      ),
      child: CommonText(text: text, color: black),
    ),
  );
}
