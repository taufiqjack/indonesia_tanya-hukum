import 'package:flutter/material.dart';
import 'package:indonesia_law/core/components/colors_custom.dart';

class CommonText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final TextAlign? textAlign;
  final TextOverflow? textOverflow;
  final bool? softWrap;
  final double? letterSpace;
  final TextDecoration? textDecoration;

  const CommonText({
    super.key,
    required this.text,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.textAlign,
    this.textOverflow,
    this.softWrap,
    this.textDecoration,
    this.letterSpace,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      overflow: textOverflow,
      text,
      textAlign: textAlign,
      softWrap: softWrap,
      style: TextStyle(
        decoration: textDecoration,
        color: color ?? blackNavy,
        fontSize: fontSize,
        fontFamily: fontFamily,
        letterSpacing: letterSpace,
        fontWeight: fontWeight,
      ),
    );
  }
}
