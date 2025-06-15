import 'package:audioplayers/audioplayers.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  bool _isPlaying = false;

  // Müzik durumu getters
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isPlaying => _isPlaying;

  // Müzik açma/kapama
  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    if (!enabled && _isPlaying) {
      stopBackgroundMusic();
    } else if (enabled && !_isPlaying) {
      playBackgroundMusic();
    }
  }

  // Ses efektleri açma/kapama
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  // Arka plan müziği başlat
  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.3); // Düşük ses seviyesi
      await _audioPlayer.play(AssetSource('music/background.mp3'));
      _isPlaying = true;
    } catch (e) {
      print('Müzik çalarken hata: $e');
    }
  }

  // Müziği durdur
  Future<void> stopBackgroundMusic() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      print('Müzik durdurulurken hata: $e');
    }
  }

  // Müziği pause et
  Future<void> pauseBackgroundMusic() async {
    if (_isPlaying) {
      try {
        await _audioPlayer.pause();
        _isPlaying = false;
      } catch (e) {
        print('Müzik pause edilirken hata: $e');
      }
    }
  }

  // Müziği resume et
  Future<void> resumeBackgroundMusic() async {
    if (_isMusicEnabled && !_isPlaying) {
      try {
        await _audioPlayer.resume();
        _isPlaying = true;
      } catch (e) {
        print('Müzik resume edilirken hata: $e');
      }
    }
  }

  // Ses efekti çal
  Future<void> playSoundEffect(String soundName) async {
    if (!_isSoundEnabled) return;

    try {
      final AudioPlayer effectPlayer = AudioPlayer();
      await effectPlayer.setVolume(0.5);
      await effectPlayer.play(AssetSource('music/$soundName.mp3'));
      
      // Ses efekti bittikinde player'ı temizle
      effectPlayer.onPlayerComplete.listen((event) {
        effectPlayer.dispose();
      });
    } catch (e) {
      print('Ses efekti çalarken hata: $e');
    }
  }

  // Kaynakları temizle
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  // Uygulama arka plana gittiğinde
  Future<void> onAppPaused() async {
    if (_isPlaying) {
      await pauseBackgroundMusic();
    }
  }

  // Uygulama ön plana geldiğinde
  Future<void> onAppResumed() async {
    if (_isMusicEnabled && !_isPlaying) {
      await resumeBackgroundMusic();
    }
  }
}
