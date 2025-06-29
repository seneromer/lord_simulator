import 'package:flutter/services.dart';
import 'audio_service.dart';

class VibrationHelper {
  static Future<void> vibrateOnTap() async {
    await AudioSettings.loadSettings();
    if (!AudioSettings.isVibrationEnabled) return;
    // HapticFeedback ile kısa titreşim
    HapticFeedback.mediumImpact();
  }
}
