import 'package:audioplayers/audioplayers.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal() {
    print('MusicService singleton oluşturuldu');
  }
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  bool _isPlaying = false;
  static const double _fixedMusicVolume = 0.5; // Sabit müzik ses seviyesi

  // Müzik durumu getters
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isPlaying => _isPlaying;
  // Müzik açma/kapama
  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    print('Müzik durumu değiştirildi: $_isMusicEnabled');
    if (!enabled && _isPlaying) {
      stopBackgroundMusic();
    } else if (enabled && !_isPlaying) {
      playBackgroundMusic();
    }
  }
  
  // Ses efektleri açma/kapama
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
    print('Ses efekti durumu değiştirildi: $_isSoundEnabled');
  }
    // Arka plan müziği başlat
  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) {
      print('Müzik devre dışı, çalmayacak');
      return;
    }
    
    if (_isPlaying) {
      print('Müzik zaten çalıyor');
      return;
    }

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(_fixedMusicVolume);
      await _audioPlayer.play(AssetSource('music/arkaplan ses.mp3'));
      _isPlaying = true;
      print('Arka plan müziği başlatıldı: arkaplan ses.mp3');
    } catch (e) {
      print('Müzik çalarken hata: $e');
      // Alternatif dosya deneme
      try {
        await _audioPlayer.play(AssetSource('music/background.mp3'));
        _isPlaying = true;
        print('Alternatif müzik dosyası çalıyor');
      } catch (e2) {
        print('Alternatif müzik de çalmadı: $e2');
        // Eğer hiçbir müzik dosyası çalmazsa, durum güncellemesi yapma
        _isPlaying = false;
      }
    }
  }
  // Müziği durdur
  Future<void> stopBackgroundMusic() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      print('Arka plan müziği durduruldu');
    } catch (e) {
      print('Müzik durdurulurken hata: $e');
      _isPlaying = false; // Hata olsa bile durumu güncelle
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
