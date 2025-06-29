import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global ses ayarları
class AudioSettings {
  static bool isVibrationEnabled = true;

  static Future<void> saveVibrationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isVibrationEnabled = enabled;
      await prefs.setBool('vibration_enabled', enabled);
    } catch (e) {
      print('Titreşim ayarı kaydedilemedi: $e');
    }
  }
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
      isVibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
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
  // AudioPlayer instance'ı artık nullable
  AudioPlayer? _backgroundMusicPlayer;
  bool _isBackgroundMusicPlaying = false;
  bool _isInitialized = false;

  // Initialization
  Future<void> initialize() async {
    if (_isInitialized && _backgroundMusicPlayer != null) return;

    // Önce eski player dispose edilmişse yeni bir tane oluştur
    _backgroundMusicPlayer?.dispose();
    _backgroundMusicPlayer = AudioPlayer();

    // 7.x ile: Arka plan müziği için context ayarla (mixWithOthers)
    await _backgroundMusicPlayer!.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await _backgroundMusicPlayer!.setReleaseMode(ReleaseMode.loop);
    await _backgroundMusicPlayer!.setVolume(0.1);

    _isInitialized = true;
  }
  // Arkaplan müziği başlatma fonksiyonu
  Future<void> startBackgroundMusic() async {
    // Müzik ayarı kapalı ise çalma
    if (!AudioSettings.isMusicEnabled) {
      return;
    }

    if (!_isInitialized || _backgroundMusicPlayer == null) {
      await initialize();
    }

    try {
      // Eğer müzik zaten çalıyorsa, yeniden başlatma
      if (_backgroundMusicPlayer!.state == PlayerState.playing) {
        _isBackgroundMusicPlaying = true;
        return;
      }

      // Müziği başlat
      await _backgroundMusicPlayer!.play(AssetSource('music/arkaplan_ses.mp3'));
      _isBackgroundMusicPlaying = true;
    } catch (e) {
      // Hata durumunda sessizce devam et
      _isBackgroundMusicPlaying = false;
    }
  }
  // Arkaplan müziğini durdur
  Future<void> stopBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer?.stop();
      _isBackgroundMusicPlaying = false;
    } catch (e) {
      // Hata durumunda sessizce devam et
      _isBackgroundMusicPlaying = false;
    }
  }
  Future<void> playFailureSound() async {
    if (!AudioSettings.isSoundEffectsEnabled) {
      return;
    }
    try {
      // 7.x ile: Efektler için context ayarla (mixWithOthers)
      final AudioPlayer failurePlayer = AudioPlayer();
      await failurePlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await failurePlayer.setVolume(0.3);
      await failurePlayer.play(AssetSource('music/basarisizlik_sesi.mp3'));
      failurePlayer.onPlayerComplete.listen((event) async {
        await failurePlayer.dispose();
      });
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  Future<void> playLevelUpSound() async {
    if (!AudioSettings.isSoundEffectsEnabled) {
      return;
    }
    try {
      // 7.x ile: Efektler için context ayarla (mixWithOthers)
      final AudioPlayer levelUpPlayer = AudioPlayer();
      await levelUpPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await levelUpPlayer.setVolume(0.4);
      await levelUpPlayer.play(AssetSource('music/seviye_sesi.mp3'));
      levelUpPlayer.onPlayerComplete.listen((event) async {
        await levelUpPlayer.dispose();
      });
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }
  // Müzik durumunu kontrol et ve güncelle
  Future<void> controlBackgroundMusic() async {
    if (AudioSettings.isMusicEnabled) {
      // Müzik ayarı açık ama çalmıyorsa başlat
      if (!_isBackgroundMusicPlaying || _backgroundMusicPlayer == null || _backgroundMusicPlayer!.state != PlayerState.playing) {
        await startBackgroundMusic();
      }
    } else {
      // Müzik ayarı kapalıysa durdur
      await stopBackgroundMusic();
    }
  }

  // Dispose - kaynak temizleme
  void dispose() {
    _backgroundMusicPlayer?.dispose();
    _backgroundMusicPlayer = null;
    _isBackgroundMusicPlaying = false;
    _isInitialized = false;
  }
}
