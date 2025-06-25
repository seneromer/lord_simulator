import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global ses ayarları
class AudioSettings {
  static bool isMusicEnabled = true;
  static bool isSoundEffectsEnabled = true; // Ses efektleri toggle'ı
  static bool isTutorialToggleEnabled = true; // Tutorial toggle butonu aktif mi?
  
  // Ayarları yükle
  static Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isMusicEnabled = prefs.getBool('music_enabled') ?? true;
      isSoundEffectsEnabled = prefs.getBool('sound_effects_enabled') ?? true;
      isTutorialToggleEnabled = prefs.getBool('tutorial_toggle_enabled') ?? true;
    } catch (e) {
      print('Ayarlar yüklenemedi: $e');
    }
  }
  
  // Müzik ayarını kaydet
  static Future<void> saveMusicSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isMusicEnabled = enabled;
      await prefs.setBool('music_enabled', enabled);
    } catch (e) {
      print('Müzik ayarı kaydedilemedi: $e');
    }
  }
  
  // Ses efektleri ayarını kaydet
  static Future<void> saveSoundEffectsSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isSoundEffectsEnabled = enabled;
      await prefs.setBool('sound_effects_enabled', enabled);
    } catch (e) {
      print('Ses efektleri ayarı kaydedilemedi: $e');
    }
  }

  // Tutorial toggle ayarını kaydet
  static Future<void> saveTutorialToggleSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isTutorialToggleEnabled = enabled;
      await prefs.setBool('tutorial_toggle_enabled', enabled);
    } catch (e) {
      print('Tutorial toggle ayarı kaydedilemedi: $e');
    }
  }
}

// Ses yönetimi servisi
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();
  // AudioPlayer instance'ları
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
    // Initialization
  Future<void> initialize() async {
    // Newer audioplayers version doesn't need setPlayerMode
    // Just initialize the player
  }
  // Arkaplan müziği başlatma fonksiyonu
  Future<void> startBackgroundMusic() async {
    // Müzik ayarı kapalı ise çalma
    if (!AudioSettings.isMusicEnabled) {
      return;
    }
      try {
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundMusicPlayer.setVolume(0.1); // Ses seviyesi %10'a düşürüldü
      // Play the background music with AssetSource
      await _backgroundMusicPlayer.play(AssetSource('music/arkaplan_ses.mp3'));
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  // Arkaplan müziğini durdur
  Future<void> stopBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.stop();
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }
  // Başarısızlık sesi çal (oyun bittiğinde)
  Future<void> playFailureSound() async {
    // Ses efektleri ayarı kapalı ise çalma
    if (!AudioSettings.isSoundEffectsEnabled) {
      return;
    }
    
    try {
      final AudioPlayer failurePlayer = AudioPlayer();
      await failurePlayer.setVolume(0.3); // Ses seviyesi %30
      await failurePlayer.play(AssetSource('music/basarisizlik_sesi.mp3'));
      
      // Ses bittikten sonra player'ı dispose et
      failurePlayer.onPlayerComplete.listen((event) {
        failurePlayer.dispose();
      });
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  // Seviye atlama sesi çal
  Future<void> playLevelUpSound() async {
    // Ses efektleri ayarı kapalı ise çalma
    if (!AudioSettings.isSoundEffectsEnabled) {
      return;
    }
    
    try {
      final AudioPlayer levelUpPlayer = AudioPlayer();
      await levelUpPlayer.setVolume(0.4); // Ses seviyesi %40
      await levelUpPlayer.play(AssetSource('music/seviye_sesi.mp3'));
      
      // Ses bittikten sonra player'ı dispose et
      levelUpPlayer.onPlayerComplete.listen((event) {
        levelUpPlayer.dispose();
      });
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  // Müzik durumunu kontrol et ve güncelle
  Future<void> controlBackgroundMusic() async {
    if (AudioSettings.isMusicEnabled) {
      // Müzik çalmıyorsa başlat
      await startBackgroundMusic();
    } else {
      // Müzik çalıyorsa durdur
      await stopBackgroundMusic();
    }
  }
  // Dispose - kaynak temizleme
  void dispose() {
    _backgroundMusicPlayer.dispose();
  }
}
