import 'package:flutter/material.dart';

Color hexToColor(String hex) {
  var cleaned = hex.replaceAll('#', '');
  if (cleaned.length == 6) cleaned = 'FF$cleaned';
  return Color(int.parse(cleaned, radix: 16));
}

String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}

/// একটি কালারের ওপর টেক্সট সাদা না কালো হবে তা নির্ধারণ করে
Color contrastingTextColor(Color background) {
  final luminance = background.computeLuminance();
  return luminance > 0.5 ? Colors.black87 : Colors.white;
}
