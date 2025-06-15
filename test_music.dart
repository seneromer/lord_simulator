import 'package:flutter/material.dart';
import 'lib/music_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final MusicService _musicService = MusicService();
  bool _isMusicEnabled = true;

  @override
  void initState() {
    super.initState();
    print('Test ekranı başlatılıyor');
    _isMusicEnabled = _musicService.isMusicEnabled;
    if (_isMusicEnabled) {
      _musicService.playBackgroundMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Music Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Müzik Durumu: ${_isMusicEnabled ? "Açık" : "Kapalı"}'),
            Text('Müzik Çalıyor: ${_musicService.isPlaying ? "Evet" : "Hayır"}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isMusicEnabled = !_isMusicEnabled;
                  _musicService.setMusicEnabled(_isMusicEnabled);
                });
              },
              child: Text(_isMusicEnabled ? 'Müziği Kapat' : 'Müziği Aç'),
            ),
          ],
        ),
      ),
    );
  }
}
