import 'package:flutter/material.dart';

class InstrumentData {
  final String name;
  final String iconAsset;
  final Color color;
  // New field for the audio file path
  final String audioAsset;

  InstrumentData({
    required this.name,
    required this.iconAsset,
    required this.color,
    required this.audioAsset,
  });
}
