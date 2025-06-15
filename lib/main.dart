import 'package:flutter/material.dart';
import 'dart:math';
import 'game_data.dart';
import 'music_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {    return MaterialApp(
      title: 'Lord Simulator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const StartScreen(),
    );
  }
}

// Seviye sistemi için enum
enum GovernmentLevel {
  koyu("Köy", Icons.home),
  derebeylik("Derebeylik", Icons.castle),
  prenslik("Baronluk", Icons.account_balance),
  krallik("Krallık", Icons.diamond),
  imparatorluk("İmparatorluk", Icons.star);

  const GovernmentLevel(this.name, this.icon);
  final String name;
  final IconData icon;
}

// Oyun durumları için model
class GameState {
  int halk; // Halk memnuniyeti (0-100)
  int din; // Dini güç (0-100)
  int asker; // Askeri güç (0-100)
  int ekonomi; // Ekonomik durum (0-100)
  GovernmentLevel level; // Mevcut seviye
  int turnCount; // Oynanan olay sayısı
  int totalDays; // Toplam geçen gün sayısı
  int daysAtCurrentLevel; // Mevcut seviyede geçirilen gün sayısı
  List<String> usedEventTitles; // Kullanılan event kartlarının başlıkları
  Map<String, dynamic> eventFlags; // Zincirleme olaylar için flag'ler
  Set<String> completedChainStories; // Tamamlanan zincirleme hikayeler
  int maxChainStories; // Oyun başına maksimum zincirleme hikaye sayısı
  Map<String, int> advisorUsageCount; // Her danışman türünün kullanım sayısı
  GameState({
    this.halk = 35,
    this.din = 28,
    this.asker = 25,
    this.ekonomi = 40,
    this.level = GovernmentLevel.koyu,
    this.turnCount = 0,
    this.totalDays = 0,
    this.daysAtCurrentLevel = 0,
    List<String>? usedEventTitles,
    Map<String, dynamic>? eventFlags,
    Set<String>? completedChainStories,
    this.maxChainStories = 2,
    Map<String, int>? advisorUsageCount,
  }) : usedEventTitles = usedEventTitles ?? [],
       eventFlags = eventFlags ?? {},
       completedChainStories = completedChainStories ?? {},
       advisorUsageCount =
           advisorUsageCount ??
           {'mali': 0, 'askeri': 0, 'din': 0, 'diplomatik': 0, 'halk': 0};

  bool get isGameOver {
    // Seviye bazlı maksimum değerler
    int maxHalk, maxDin, maxAsker, maxEkonomi;

    switch (level) {
      case GovernmentLevel.koyu:
        maxHalk = 60;
        maxDin = 40;
        maxAsker = 40;
        maxEkonomi = 60;
        break;
      case GovernmentLevel.derebeylik:
        maxHalk = 70;
        maxDin = 50;
        maxAsker = 55;
        maxEkonomi = 70;
        break;
      case GovernmentLevel.prenslik:
        maxHalk = 75;
        maxDin = 60;
        maxAsker = 65;
        maxEkonomi = 80;
        break;
      case GovernmentLevel.krallik:
        maxHalk = 85;
        maxDin = 80;
        maxAsker = 85;
        maxEkonomi = 90;
        break;
      case GovernmentLevel.imparatorluk:
        maxHalk = 100;
        maxDin = 100;
        maxAsker = 100;
        maxEkonomi = 100;
        break;
    }

    return halk <= 0 ||
        din <= 0 ||
        asker <= 0 ||
        ekonomi <= 0 ||
        halk >= maxHalk ||
        din >= maxDin ||
        asker >= maxAsker ||
        ekonomi >= maxEkonomi;
  }

  bool get canLevelUp {
    // Önce temel seviye atlama koşullarını kontrol et
    bool meetsRequirements = false;    switch (level) {
      case GovernmentLevel.koyu:
        // Köyden derebeyliğe geçmek için koşullar: ekonomi ≥ 40, halk ≥ 10 ve 3 yıl (1095 gün)
        meetsRequirements = halk > 10 && ekonomi > 25 && daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.derebeylik:
        // Derebeylikten baronluğa geçmek için koşullar: halk > 30, ekonomi > 30, din > 40, asker >= 40 ve 3 yıl
        meetsRequirements =
            halk > 30 &&
            ekonomi > 30 &&
            din > 40 &&
            asker >= 40 &&
            daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.prenslik:
        // Baronluktan krallığa geçmek için koşullar: ekonomi ≥ 60, asker ≥ 30 ve baronlukta 3 yıl
        meetsRequirements = ekonomi >= 60 && asker >= 30 && daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.krallik:
        // Krallıktan imparatorluğa geçmek için koşullar: halk ≥ 60, asker ≥ 50 ve krallıkta en az 3 yıl
        meetsRequirements = halk >= 60 && asker >= 50 && daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.imparatorluk:
        return false;
    }

    // Temel koşullar sağlanmıyorsa false döndür
    if (!meetsRequirements) return false;

    // Seviye atlama güvenlik kontrolü yap
    return _isSafeLevelUp();
  }

  // Emekli olma koşullarını kontrol et
  bool get canRetire {
    return level == GovernmentLevel.imparatorluk &&
        halk >= 50 &&
        din >= 50 &&
        asker >= 50 &&
        ekonomi >= 50;
  }

  // En çok kullanılan danışman türünü belirle ve kişilik analizi yap
  Map<String, dynamic> getPersonalityAnalysis() {
    if (advisorUsageCount.values.every((count) => count == 0)) {
      return {
        'type': 'unknown',
        'name': 'Bilinmeyen Lider',
        'description': 'Henüz yeterli karar vermemişsiniz.',
        'traits': ['Kararsız'],
      };
    }

    // En çok kullanılan danışman türünü bul
    String mostUsedAdvisor = advisorUsageCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // İkinci en çok kullanılan danışmanı da bul (hibrit kişilik için)
    var sortedAdvisors =
        advisorUsageCount.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    String? secondMostUsed;
    if (sortedAdvisors.length > 1 &&
        sortedAdvisors[1].value >= (sortedAdvisors[0].value * 0.7)) {
      secondMostUsed = sortedAdvisors[1].key;
    }

    return _getPersonalityByAdvisorType(mostUsedAdvisor, secondMostUsed);
  }

  Map<String, dynamic> _getPersonalityByAdvisorType(
    String primaryType,
    String? secondaryType,
  ) {
    Map<String, Map<String, dynamic>> personalities = {
      'mali': {
        'name': 'Ekonomist Lider',
        'description':
            'Paranın gücüne inanan, hesaplı ve pragmatik bir yöneticisiniz. Her kararınızda kazanç-zarar analizi yapıyor, krallığınızı ekonomik refaha ulaştırmayı hedefliyorsunuz.',
        'traits': ['Hesaplı', 'Pragmatik', 'Ticaret Odaklı', 'Risk Analisti'],
        'icon': Icons.monetization_on,
        'color': Colors.orange,
      },
      'askeri': {
        'name': 'Savaşçı Lider',
        'description':
            'Güç ve disiplinle yönetmeyi tercih eden kararlı bir lidersiniz. Tehditlerle mücadelede sert tedbirler alıyor, krallığınızın güvenliğini her şeyin üstünde tutuyorsunuz.',
        'traits': ['Kararlı', 'Disiplinli', 'Güvenlik Odaklı', 'Sert'],
        'icon': Icons.security,
        'color': Colors.red,
      },
      'din': {
        'name': 'Ruhani Lider',
        'description':
            'Manevi değerlere öncelik veren, gelenekçi bir yöneticisiniz. Kararlarınızda ahlaki prensipleri ön planda tutarak, halkınızı ruhani bir zeminde birleştirmeye çalışıyorsunuz.',
        'traits': ['Gelenekçi', 'Ahlakçı', 'Ruhani', 'İlkeli'],
        'icon': Icons.brightness_2,
        'color': Colors.green,
      },
      'diplomatik': {
        'name': 'Diplomatik Lider',
        'description':
            'Barış ve uzlaşmayı tercih eden, sabırlı bir lidersiniz. Sorunları müzakereyle çözmeyi, dengeli politikalarla tüm tarafları memnun etmeyi hedefliyorsunuz.',
        'traits': ['Sabırlı', 'Uzlaşmacı', 'Dengeli', 'Barışçıl'],
        'icon': Icons.handshake,
        'color': Colors.blue,
      },
      'halk': {
        'name': 'Halkçı Lider',
        'description':
            'Halkın sesini dinleyen, sosyal adaleti önemseyen bir yöneticisiniz. Kararlarınızda sıradan insanların menfaatlerini gözetir, tabandan gelen taleplere kulak verirsiniz.',
        'traits': ['Halkçı', 'Sosyal', 'Empatik', 'Adalet Odaklı'],
        'icon': Icons.groups,
        'color': Colors.purple,
      },
    };

    var primary = personalities[primaryType] ?? personalities['mali']!;

    // Hibrit kişilik kontrolü
    if (secondaryType != null && secondaryType != primaryType) {
      var secondary = personalities[secondaryType]!;
      return {
        'type': '${primaryType}_$secondaryType',
        'name': 'Hibrit ${primary['name']}-${secondary['name']}',
        'description':
            'Çok yönlü bir lidersiniz. ${primary['description']} Aynı zamanda ${secondary['description'].toString().toLowerCase()}',
        'traits': [...primary['traits'], ...secondary['traits']],
        'icon': primary['icon'],
        'color': primary['color'],
        'isPrimaryType': primaryType,
        'isSecondaryType': secondaryType,
      };
    }

    return {'type': primaryType, ...primary};
  }

  // Seviye atlama öncesi güvenlik kontrolü
  bool _isSafeLevelUp() {
    // Geçici bir kopya oluştur ve seviye atlama maliyetlerini simüle et
    int tempHalk = halk;
    int tempDin = din;
    int tempAsker = asker;
    int tempEkonomi = ekonomi;
    GovernmentLevel tempLevel = level;

    // Seviye atlama maliyetlerini geçici değerlere uygula
    switch (level) {
      case GovernmentLevel.koyu:
        // Köyden derebeyliğe geçiş maliyeti
        tempEkonomi -= 25;
        tempHalk -= 10;
        tempAsker += 10;
        tempLevel = GovernmentLevel.derebeylik;
        break;
      case GovernmentLevel.derebeylik:
        // Derebeylikten baronluğa geçiş maliyeti
        tempHalk -= 30;
        tempEkonomi -= 30;
        tempDin -= 40;
        tempAsker += 15;
        tempLevel = GovernmentLevel.prenslik;
        break;
      case GovernmentLevel.prenslik:
        // Baronluktan krallığa geçiş maliyeti
        if (tempHalk < 40) {
          tempHalk -= 10;
        } else {
          tempHalk += 10;
        }
        if (tempDin < 40) {
          tempDin -= 10;
        } else {
          tempDin += 10;
        }
        if (tempAsker < 40) {
          tempAsker -= 10;
        } else {
          tempAsker += 10;
        }
        tempEkonomi -= 30;
        tempLevel = GovernmentLevel.krallik;
        break;
      case GovernmentLevel.krallik:
        // Krallıktan imparatorluğa geçiş maliyeti
        tempAsker -= 30;
        tempHalk -= 20;
        tempEkonomi -= 40;
        tempLevel = GovernmentLevel.imparatorluk;
        break;
      default:
        return true;
    }

    // Yeni seviyenin maksimum değerlerini al
    int maxHalk, maxDin, maxAsker, maxEkonomi;

    switch (tempLevel) {
      case GovernmentLevel.koyu:
        maxHalk = 60;
        maxDin = 40;
        maxAsker = 40;
        maxEkonomi = 60;
        break;
      case GovernmentLevel.derebeylik:
        maxHalk = 70;
        maxDin = 50;
        maxAsker = 55;
        maxEkonomi = 70;
        break;
      case GovernmentLevel.prenslik:
        maxHalk = 75;
        maxDin = 60;
        maxAsker = 65;
        maxEkonomi = 80;
        break;
      case GovernmentLevel.krallik:
        maxHalk = 85;
        maxDin = 80;
        maxAsker = 85;
        maxEkonomi = 90;
        break;
      case GovernmentLevel.imparatorluk:
        maxHalk = 100;
        maxDin = 100;
        maxAsker = 100;
        maxEkonomi = 100;
        break;
    }

    // Sınırları uygula
    tempHalk = tempHalk.clamp(0, maxHalk);
    tempDin = tempDin.clamp(0, maxDin);
    tempAsker = tempAsker.clamp(0, maxAsker);
    tempEkonomi = tempEkonomi.clamp(0, maxEkonomi);

    // Oyun bitiş koşullarını kontrol et
    return !(tempHalk <= 0 ||
        tempDin <= 0 ||
        tempAsker <= 0 ||
        tempEkonomi <= 0 ||
        tempHalk >= maxHalk ||
        tempDin >= maxDin ||
        tempAsker >= maxAsker ||
        tempEkonomi >= maxEkonomi);
  }

  void levelUp() {
    if (canLevelUp && level.index < GovernmentLevel.values.length - 1) {
      // Seviye atlama maliyetlerini uygula
      switch (level) {
        case GovernmentLevel.koyu:
          // Köyden derebeyliğe geçiş maliyeti
          ekonomi -= 25;
          halk -= 10;
          asker += 10;
          break;
        case GovernmentLevel.derebeylik:
          // Derebeylikten baronluğa geçiş maliyeti
          halk -= 30;
          ekonomi -= 30;
          din -= 40;
          asker += 15;
          break;
        case GovernmentLevel.prenslik:
          // Baronluktan krallığa geçiş maliyeti
          // Halk: 40'tan düşükse -10, 40'tan yüksekse +10
          if (halk < 40) {
            halk -= 10;
          } else {
            halk += 10;
          }
          // Din: 40'tan düşükse -10, 40'tan yüksekse +10
          if (din < 40) {
            din -= 10;
          } else {
            din += 10;
          }
          // Asker: 40'tan düşükse -10, 40'tan yüksekse +10
          if (asker < 40) {
            asker -= 10;
          } else {
            asker += 10;
          }
          // Ekonomi: her durumda -30
          ekonomi -= 30;
          break;
        case GovernmentLevel.krallik:
          // Krallıktan imparatorluğa geçiş maliyeti
          asker -= 30;
          halk -= 20;
          ekonomi -= 40;
          break;
        default:
          break;
      }

      level = GovernmentLevel.values[level.index + 1];
      
      // Yeni seviyede geçirilen gün sayısını sıfırla
      daysAtCurrentLevel = 0;

      // Seviye değişikliği sonrası stat sınırlarını kontrol et
      int maxHalk, maxDin, maxAsker, maxEkonomi;

      switch (level) {
        case GovernmentLevel.koyu:
          maxHalk = 60;
          maxDin = 40;
          maxAsker = 40;
          maxEkonomi = 60;
          break;
        case GovernmentLevel.derebeylik:
          maxHalk = 70;
          maxDin = 50;
          maxAsker = 55;
          maxEkonomi = 70;
          break;
        case GovernmentLevel.prenslik:
          maxHalk = 75;
          maxDin = 60;
          maxAsker = 65;
          maxEkonomi = 80;
          break;
        case GovernmentLevel.krallik:
          maxHalk = 85;
          maxDin = 80;
          maxAsker = 85;
          maxEkonomi = 90;
          break;
        case GovernmentLevel.imparatorluk:
          maxHalk = 100;
          maxDin = 100;
          maxAsker = 100;
          maxEkonomi = 100;
          break;
      }

      // Yeni seviyenin maksimum değerlerine göre sınırla
      halk = halk.clamp(0, maxHalk);
      din = din.clamp(0, maxDin);
      asker = asker.clamp(0, maxAsker);
      ekonomi = ekonomi.clamp(0, maxEkonomi);
    }  }
}

// Açılış Sayfası
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final MusicService _musicService = MusicService();
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  @override
  void initState() {
    super.initState();
    // Müzik servisi durumunu senkronize et
    _isMusicEnabled = _musicService.isMusicEnabled;
    _isSoundEnabled = _musicService.isSoundEnabled;
    
    print('Uygulama başlatılıyor - Müzik: $_isMusicEnabled, Ses: $_isSoundEnabled');
    
    // Müziği başlat
    if (_isMusicEnabled) {
      _musicService.playBackgroundMusic();
    }
  }

  @override
  void dispose() {
    // Müzik servisi zaten singleton, dispose etmeyelim
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF212121),
              Color(0xFF424242),
              Color(0xFF616161),
            ],
          ),
        ),        child: Stack(
          children: [
            // Ana play butonu - merkez
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const GameScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1C1C1C),
                        Color(0xFF000000),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 25,
                        spreadRadius: 5,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -5,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Ayarlar butonu - sağ alt köşe
            Positioned(
              bottom: 50,
              right: 30,              child: GestureDetector(
                onTap: () {
                  _showSettingsDialog(context);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2C2C2C),
                        Color(0xFF1C1C1C),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings,
                    size: 28,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),          ],
        ),
      ),
    );
  }  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2C2C2C),
                  Color(0xFF1C1C1C),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                const Text(
                  'AYARLAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),
                  // Müzik Ayarı
                _buildSettingItem(
                  icon: Icons.music_note,
                  title: 'Müzik',
                  isToggle: true,
                  value: _isMusicEnabled,                  onChanged: (value) {
                    print('Müzik toggle değiştirildi: $value');
                    setDialogState(() {
                      _isMusicEnabled = value;
                    });
                    setState(() {
                      _isMusicEnabled = value;
                    });
                    _musicService.setMusicEnabled(value);
                  },
                ),
                
                const SizedBox(height: 20),                // Ses Efektleri
                _buildSettingItem(
                  icon: Icons.volume_up,
                  title: 'Ses Efektleri',
                  isToggle: true,
                  value: _isSoundEnabled,                  onChanged: (value) {
                    print('Ses efekti toggle değiştirildi: $value');
                    setDialogState(() {
                      _isSoundEnabled = value;
                    });
                    setState(() {
                      _isSoundEnabled = value;
                    });
                    _musicService.setSoundEnabled(value);
                  },
                ),
                  const SizedBox(height: 20),
                
                // Dil Seçimi
                _buildSettingItem(
                  icon: Icons.language,
                  title: 'Dil',
                  subtitle: 'Türkçe',
                  onTap: () {
                    // Dil seçimi dialog'u açılacak
                    _showLanguageDialog(context);
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Kapat Butonu
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: const Text(
                    'KAPAT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    bool isToggle = false,
    bool value = false,
    Function(bool)? onChanged,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          if (isToggle)
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: Colors.white.withOpacity(0.3),
              inactiveThumbColor: Colors.white.withOpacity(0.5),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
            )
          else if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.6),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2C2C2C),
                  Color(0xFF1C1C1C),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DİL SEÇİMİ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                _buildLanguageOption('🇹🇷', 'Türkçe', true),
                const SizedBox(height: 10),
                _buildLanguageOption('🇺🇸', 'English', false),
                const SizedBox(height: 10),
                _buildLanguageOption('🇩🇪', 'Deutsch', false),
                
                const SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('KAPAT'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String flag, String language, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? Colors.white.withOpacity(0.1) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected 
              ? Colors.white.withOpacity(0.3) 
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            flag,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Text(
            language,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check,
              color: Colors.white,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameState gameState;
  late List<EventCard> events;
  late EventCard currentEvent;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final MusicService _musicService = MusicService();
  @override
  void initState() {
    super.initState();
    gameState = GameState();
    _initializeEvents();
    _selectRandomEvent();

    // Arka plan müziğini başlat
    _musicService.playBackgroundMusic();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
    _animationController.forward();
  }
  void _initializeEvents() {
    events = GameData.getEvents();
  }

  // Toplam günleri yıl/ay/gün formatında göster
  String _formatTimePassed() {
    if (gameState.totalDays == 0) {
      return "Yeni Başladı";
    }
    
    int years = gameState.totalDays ~/ 365;
    int remainingDays = gameState.totalDays % 365;
    int months = remainingDays ~/ 30;
    int days = remainingDays % 30;
    
    List<String> parts = [];
    if (years > 0) parts.add("$years Yıl");
    if (months > 0) parts.add("$months Ay");
    if (days > 0) parts.add("$days Gün");
    
    if (parts.isEmpty) {
      return "${gameState.totalDays} Gün";
    }
    
    return parts.join(", ");
  }

  void _selectRandomEvent() {
    final random = Random();

    // Önce zincirleme olayları kontrol et
    List<EventCard> chainEvents = GameData.getChainEvents(gameState.eventFlags);

    if (chainEvents.isNotEmpty) {
      // Zincirleme olay varsa önceliği ona ver
      currentEvent = chainEvents[random.nextInt(chainEvents.length)];
      return;
    }

    // Önce kullanılmamış eventleri filtrele
    List<EventCard> unusedEvents = events
        .where((event) => !gameState.usedEventTitles.contains(event.title))
        .toList();

    // Eğer zincirleme hikaye limiti dolmuşsa, zincirleme başlatıcı kartları çıkar
    if (gameState.completedChainStories.length >= gameState.maxChainStories) {
      unusedEvents = unusedEvents
          .where(
            (event) =>
                event.title != "Gizemli Hastalık" &&
                event.title != "Ejder Efsanesi" &&
                event.title != "Gizli Hazine",
          )
          .toList();
    }

    // Eğer hiç kullanılmamış event yoksa, tüm eventleri tekrar kullanılabilir yap
    if (unusedEvents.isEmpty) {
      gameState.usedEventTitles.clear();
      unusedEvents = events;

      // Zincirleme hikaye limiti dolmuşsa, tekrar zincirleme başlatıcıları çıkar
      if (gameState.completedChainStories.length >= gameState.maxChainStories) {
        unusedEvents = unusedEvents
            .where(
              (event) =>
                  event.title != "Gizemli Hastalık" &&
                  event.title != "Ejder Efsanesi" &&
                  event.title != "Gizli Hazine",
            )
            .toList();
      }
    }

    // Rastgele bir kullanılmamış event seç
    currentEvent = unusedEvents[random.nextInt(unusedEvents.length)];

    // Bu eventi kullanılanlar listesine ekle
    gameState.usedEventTitles.add(currentEvent.title);
  }

  // Government level'a göre advisor etkilerini ölçeklendiren fonksiyon
  double _getEffectMultiplier() {
    switch (gameState.level) {
      case GovernmentLevel.koyu:
        return 0.5; // Köy seviyesinde etkiler zayıf
      case GovernmentLevel.derebeylik:
        return 0.7; // Derebeylikte biraz daha güçlü
      case GovernmentLevel.prenslik:
        return 0.9; // Baronlukta normal etki
      case GovernmentLevel.krallik:
        return 1.0; // Krallıkta güçlü etki
      case GovernmentLevel.imparatorluk:
        return 1.3; // İmparatorlukta en güçlü etki
    }
  }

  void _makeChoice(Choice choice) {
    // Önce seçimin oyun bitiş riskine sebep olup olmayacağını kontrol et
    if (_wouldChoiceCauseGameOver(choice)) {
      _showRiskConfirmationDialog(choice);
      return;
    }

    _executeChoice(choice);
  }
  void _executeChoice(Choice choice) {
    // Ses efekti çal
    _musicService.playSoundEffect('choice_click');
    
    setState(() {
      // Government level'a göre ölçeklendirilmiş etkiler
      double multiplier = _getEffectMultiplier();

      int scaledHalkChange = (choice.halkChange * multiplier).round();
      int scaledDinChange = (choice.dinChange * multiplier).round();
      int scaledAskerChange = (choice.askerChange * multiplier).round();
      int scaledEkonomiChange = (choice.ekonomiChange * multiplier).round();

      // Seviye bazlı maksimum değerler
      int maxHalk, maxDin, maxAsker, maxEkonomi;

      switch (gameState.level) {
        case GovernmentLevel.koyu:
          maxHalk = 60;
          maxDin = 40;
          maxAsker = 40;
          maxEkonomi = 60;
          break;
        case GovernmentLevel.derebeylik:
          maxHalk = 70;
          maxDin = 50;
          maxAsker = 55;
          maxEkonomi = 70;
          break;
        case GovernmentLevel.prenslik:
          maxHalk = 75;
          maxDin = 60;
          maxAsker = 65;
          maxEkonomi = 80;
          break;
        case GovernmentLevel.krallik:
          maxHalk = 85;
          maxDin = 80;
          maxAsker = 85;
          maxEkonomi = 90;
          break;
        case GovernmentLevel.imparatorluk:
          maxHalk = 100;
          maxDin = 100;
          maxAsker = 100;
          maxEkonomi = 100;
          break;
      }

      gameState.halk = (gameState.halk + scaledHalkChange).clamp(0, maxHalk);
      gameState.din = (gameState.din + scaledDinChange).clamp(0, maxDin);
      gameState.asker = (gameState.asker + scaledAskerChange).clamp(
        0,
        maxAsker,
      );
      gameState.ekonomi = (gameState.ekonomi + scaledEkonomiChange).clamp(
        0,
        maxEkonomi,
      );      // Tur sayısını artır
      gameState.turnCount++;
      
      // Olay süresini toplam günlere ve mevcut seviye günlerine ekle
      gameState.totalDays += currentEvent.durationInDays;
      gameState.daysAtCurrentLevel += currentEvent.durationInDays;

      // Danışman kullanım sayısını artır
      gameState.advisorUsageCount[choice.advisorType] =
          (gameState.advisorUsageCount[choice.advisorType] ?? 0) + 1;

      // Zincirleme olaylar için flag'leri ayarla
      GameData.setEventFlags(
        currentEvent.title,
        choice.title,
        gameState.eventFlags,
        gameState.completedChainStories,
      );
    });

    if (gameState.isGameOver) {
      _showGameOverDialog();
    } else {
      _animationController.reset();
      _selectRandomEvent();
      _animationController.forward();
    }
  }
  void _showGameOverDialog() {
    // Müziği durdur
    _musicService.stopBackgroundMusic();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),          title: Container(
            alignment: Alignment.center,
            child: Column(
              children: [
                // Yenilgi resmi ekleme - büyütülmüş
                Container(
                  width: 250,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: const DecorationImage(
                      image: AssetImage("city/yenilgi.jpg"),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Oyun Bitti!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      _getGameOverReason(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),                    const SizedBox(height: 16),                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),                          const SizedBox(height: 8),
                          Text(
                            "Yönetilen Süre:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gameState.totalDays == 0 ? "0" : "${gameState.totalDays}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    gameState = GameState();
                    _selectRandomEvent();
                  });
                  // Müziği yeniden başlat
                  _musicService.playBackgroundMusic();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Yeniden Başla',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  String _getLevelUpImagePath(GovernmentLevel level) {
    switch (level) {
      case GovernmentLevel.derebeylik:
        return "city/derebeyi.jpeg";
      case GovernmentLevel.prenslik:
        return "city/baron.jpg";
      case GovernmentLevel.krallik:
        return "city/kral.jpg";
      case GovernmentLevel.imparatorluk:
        return "city/İmparator.jpg";
      default:
        return "city/derebeyi.jpeg"; // Varsayılan görsel
    }
  }
  void _showLevelUpDialog(GovernmentLevel oldLevel, GovernmentLevel newLevel) {
    String message = "";

    switch (newLevel) {
      case GovernmentLevel.derebeylik:
        message = "Şato inşa edildi. Artık derebeyisin!";
        break;
      case GovernmentLevel.prenslik:
        message = "Barona darbe yapıldı. Yeni baron oldun!";
        break;
      case GovernmentLevel.krallik:
        message =
            "Diğer baronlara oybirliği ile kendini kral seçtirdin. Seçilmiş kral sensin!";
        break;
      case GovernmentLevel.imparatorluk:
        message = "Bir imparatorluk devletini yıktın! Artık imparatorsun!";
        break;
      default:
        message = "Yeni seviyeye ulaştın!";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),          title: Container(
            alignment: Alignment.center,
            child: Text(
              newLevel.name,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [                // Seviye görseli - büyütülmüş
                Container(
                  width: 300,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      _getLevelUpImagePath(newLevel),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print(
                          'Görsel yüklenemedi: ${_getLevelUpImagePath(newLevel)}',
                        );
                        print('Hata: $error');
                        return Container(
                          color: Colors.amber.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                newLevel.icon,
                                size: 80,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Görsel yüklenemedi',
                                style: TextStyle(
                                  color: Colors.amber.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    "${oldLevel.name} → ${newLevel.name}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Devam Et',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRetirementDialog() {
    final personalityAnalysis = gameState.getPersonalityAnalysis();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),          title: Container(
            alignment: Alignment.center,
            child: Column(
              children: [
                // Başarı resmi ekleme - büyütülmüş
                Container(
                  width: 250,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: AssetImage(_getLevelUpImagePath(gameState.level)),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Başarılı Emeklilik!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başarı bilgileri
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(                    children: [
                      Text(
                        "${gameState.level.name} seviyesinde başarılı bir yöneticilik sergileyerek emekli oldunuz.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),const SizedBox(height: 12),                        Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(height: 8),                            Text(
                              "Geçen Süre:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimePassed(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Kişilik Analizi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: personalityAnalysis['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: personalityAnalysis['color']),
                  ),
                  child: Column(
                    children: [
                      // Kişilik başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            personalityAnalysis['icon'],
                            color: personalityAnalysis['color'],
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Liderlik Kişiliğiniz",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: personalityAnalysis['color'],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Kişilik tipi
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: personalityAnalysis['color'].withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: personalityAnalysis['color'],
                          ),
                        ),
                        child: Text(
                          personalityAnalysis['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: personalityAnalysis['color'],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Kişilik açıklaması
                      Text(
                        personalityAnalysis['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // Özellikler
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Liderlik Özellikleri:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: personalityAnalysis['traits']
                                  .map<Widget>(
                                    (trait) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: personalityAnalysis['color']
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        trait,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: personalityAnalysis['color'],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Final istatistikler
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFinalStat("Halk", gameState.halk, Colors.blue),
                      _buildFinalStat("Din", gameState.din, Colors.green),
                      _buildFinalStat("Asker", gameState.asker, Colors.red),
                      _buildFinalStat(
                        "Ekonomi",
                        gameState.ekonomi,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    gameState = GameState();
                    _selectRandomEvent();
                  });
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Yeni Oyun Başlat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinalStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getGameOverReason() {
    // Seviye bazlı maksimum değerleri al
    int maxHalk, maxDin, maxAsker, maxEkonomi;

    switch (gameState.level) {
      case GovernmentLevel.koyu:
        maxHalk = 60;
        maxDin = 40;
        maxAsker = 40;
        maxEkonomi = 60;
        break;
      case GovernmentLevel.derebeylik:
        maxHalk = 70;
        maxDin = 50;
        maxAsker = 55;
        maxEkonomi = 70;
        break;
      case GovernmentLevel.prenslik:
        maxHalk = 75;
        maxDin = 60;
        maxAsker = 65;
        maxEkonomi = 80;
        break;
      case GovernmentLevel.krallik:
        maxHalk = 85;
        maxDin = 80;
        maxAsker = 85;
        maxEkonomi = 90;
        break;
      case GovernmentLevel.imparatorluk:
        maxHalk = 100;
        maxDin = 100;
        maxAsker = 100;
        maxEkonomi = 100;
        break;
    }

    if (gameState.halk <= 0) {
      return "Halk sana karşı ayaklandı! Tahttan indirildin.";
    }
    if (gameState.halk >= maxHalk) {
      return "Halk gücü eline geçirdi ve kendine başka bir yönetici seçti!";
    }
    if (gameState.din <= 0) {
      return "Din adamları seni aforoz etti! Yönetimin sona erdi.";
    }
    if (gameState.din >= maxDin) {
      return "Yönetim bir teokrasiye dönüştü! Gücün elinden alındı.";
    }
    if (gameState.asker <= 0) {
      return "Ordu dağıldı! Toplumun savunmasız kaldı.";
    }
    if (gameState.asker >= maxAsker) {
      return "Askerler darbe yaptı! Askeri diktatörlük kuruldu.";
    }
    if (gameState.ekonomi <= 0) {
      return "Ekonomi çöktü! Hazinen iflas etti.";
    }
    if (gameState.ekonomi >= maxEkonomi) {
      return "Aşırı zenginlik toplumsal dengeyi bozdu!";
    }
    return "Oyun bitti!";
  }

  String _getLevelUpTooltip() {
    if (gameState.level == GovernmentLevel.imparatorluk) {
      return "Maksimum seviyeye ulaştınız!";
    }

    // Temel koşulları kontrol et
    bool meetsRequirements = false;
    String requirementMessage = "";

    switch (gameState.level) {      case GovernmentLevel.koyu:
        meetsRequirements =
            gameState.halk > 10 &&
            gameState.ekonomi > 25 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.halk <= 10) missing.add("Halk > 10");
          if (gameState.ekonomi <= 25) missing.add("Ekonomi > 25");
          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = "Gereken: ${missing.join(', ')}";
        }
        break;
      case GovernmentLevel.derebeylik:
        meetsRequirements =
            gameState.halk > 30 &&
            gameState.ekonomi > 30 &&
            gameState.din > 40 &&
            gameState.asker >= 40 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.halk <= 30) missing.add("Halk > 30");
          if (gameState.ekonomi <= 30) missing.add("Ekonomi > 30");
          if (gameState.din <= 40) missing.add("Din > 40");
          if (gameState.asker < 40) missing.add("Asker ≥ 40");          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = "Gereken: ${missing.join(', ')}";
        }
        break;
      case GovernmentLevel.prenslik:
        meetsRequirements =
            gameState.ekonomi >= 60 &&
            gameState.asker >= 30 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.ekonomi < 60) missing.add("Ekonomi ≥ 60");
          if (gameState.asker < 30) missing.add("Asker ≥ 30");          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = "Gereken: ${missing.join(', ')}";
        }
        break;
      case GovernmentLevel.krallik:
        meetsRequirements =
            gameState.halk >= 60 &&
            gameState.asker >= 50 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.halk < 60) missing.add("Halk ≥ 60");
          if (gameState.asker < 50) missing.add("Asker ≥ 50");
          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = "Gereken: ${missing.join(', ')}";
        }
        break;
      default:
        return "Seviye atlanamaz";
    }

    if (!meetsRequirements) {
      return requirementMessage;
    }

    // Temel koşullar sağlandıysa güvenlik kontrolü mesajı
    if (!gameState._isSafeLevelUp()) {
      return "⚠️ Seviye atlama oyun bitiş riskine sebep olacak! Önce güvenli seviyeye getirin.";
    }

    return "Seviye atlamak için tıklayın!";
  }

  String _getRetirementTooltip() {
    if (gameState.level != GovernmentLevel.imparatorluk) {
      return "Emekli olmak için önce İmparatorluk seviyesine ulaşmalısınız!";
    }

    if (!gameState.canRetire) {
      List<String> missing = [];
      if (gameState.halk < 50) missing.add("Halk ≥ 50");
      if (gameState.din < 50) missing.add("Din ≥ 50");
      if (gameState.asker < 50) missing.add("Asker ≥ 50");
      if (gameState.ekonomi < 50) missing.add("Ekonomi ≥ 50");
      return "Emekli olmak için gereken: ${missing.join(', ')}";
    }

    return "Başarılı yöneticiliği ile emekli olmak için tıklayın!";
  }
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    // Ekran boyutuna göre padding ve flex değerleri
    double mainPadding = screenWidth < 600 ? 12.0 : 16.0;
    double cardPadding = screenWidth < 600 ? 12.0 : 16.0;
    int eventCardFlex = screenHeight < 700 ? 3 : 2;
    int choiceCardFlex = screenHeight < 700 ? 2 : 2;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('card/arkaplan2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Üst durum çubukları
              Padding(
                padding: EdgeInsets.all(mainPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusBar("Halk", gameState.halk, Colors.blue),
                    _buildStatusBar("Din", gameState.din, Colors.green),
                    _buildStatusBar("Asker", gameState.asker, Colors.red),
                    _buildStatusBar(
                      "Ekonomi",
                      gameState.ekonomi,
                      Colors.orange,
                    ),
                  ],
                ),
              ),

              // Boşluk
              SizedBox(height: screenHeight * 0.02),

              // Seviye sistemi
              _buildLevelSection(),

              SizedBox(height: screenHeight * 0.02),              // Orta kısım - Olay kartı
              Expanded(
                flex: eventCardFlex,
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Card(
                      elevation: 8,
                      color: Colors.black.withValues(alpha: 0.8),
                      child: Stack(
                        children: [
                          // Arka plan resmi (eğer varsa)
                          if (currentEvent.imagePath.isNotEmpty)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  currentEvent.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade800,
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey.shade400,
                                        size: 48,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          // Koyu overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          // Metin içeriği
                          Padding(
                            padding: EdgeInsets.all(screenWidth < 600 ? 16.0 : 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  currentEvent.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth < 600 ? 22 : 24,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      currentEvent.description,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth < 600 ? 16 : 18,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(1, 1),
                                            blurRadius: 2,
                                            color: Colors.black.withOpacity(0.8),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),// Alt kısım - Seçim kartları
              Expanded(
                flex: choiceCardFlex,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: cardPadding * 0.5, // Yan padding'i azalt
                    vertical: cardPadding,
                  ),
                  child: Row(children: _buildAdvisorCards()),
                ),
              ),
            ],
          ),
        ),
      ),
    );  }

  Widget _buildStatusBar(String label, int value, Color color) {
    // Seviye bazlı maksimum değerleri al
    int maxValue;
    switch (gameState.level) {
      case GovernmentLevel.koyu:
        if (label == "Halk") {
          maxValue = 60;
        } else if (label == "Din")
          maxValue = 40;
        else if (label == "Asker")
          maxValue = 40;
        else if (label == "Ekonomi")
          maxValue = 60;
        else
          maxValue = 100;
        break;
      case GovernmentLevel.derebeylik:
        if (label == "Halk") {
          maxValue = 70;
        } else if (label == "Din")
          maxValue = 50;
        else if (label == "Asker")
          maxValue = 55;
        else if (label == "Ekonomi")
          maxValue = 70;
        else
          maxValue = 100;
        break;
      case GovernmentLevel.prenslik:
        if (label == "Halk") {
          maxValue = 75;
        } else if (label == "Din")
          maxValue = 60;
        else if (label == "Asker")
          maxValue = 65;
        else if (label == "Ekonomi")
          maxValue = 80;
        else
          maxValue = 100;
        break;
      case GovernmentLevel.krallik:
        if (label == "Halk") {
          maxValue = 85;
        } else if (label == "Din")
          maxValue = 80;
        else if (label == "Asker")
          maxValue = 85;
        else if (label == "Ekonomi")
          maxValue = 90;
        else
          maxValue = 100;
        break;
      case GovernmentLevel.imparatorluk:
        maxValue = 100;
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        double barWidth = screenWidth < 600 ? 50 : 60;
        double barHeight = screenWidth < 600 ? 6 : 8;
        double labelFontSize = screenWidth < 600 ? 10 : 12;
        double valueFontSize = screenWidth < 600 ? 8 : 10;

        return Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
              ),
            ),
            SizedBox(height: screenWidth < 600 ? 2 : 4),
            Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value / maxValue,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Text(
              '$value/$maxValue',
              style: TextStyle(color: Colors.white, fontSize: valueFontSize),
            ),          ],
        );
      },
    );
  }

  Widget _buildChoiceCard(Choice choice) {
    final advisorInfo = GameData.getAdvisorInfo();
    final advisor =
        advisorInfo[choice.advisorType] ??
        {"name": "Danışman", "icon": Icons.person, "color": Colors.grey};

    Color advisorColor = advisor["color"];
    IconData advisorIcon = advisor["icon"];
    String advisorName = advisor["name"];

    return LayoutBuilder(
      builder: (context, constraints) {        // Ekran boyutuna göre dinamik boyutlar
        double screenWidth = MediaQuery.of(context).size.width;
        double screenHeight = MediaQuery.of(context).size.height;
        
        double iconSize = screenWidth < 600 ? 18 : 22;
        double advisorFontSize = screenWidth < 600 ? 12 : 14;
        double titleFontSize = screenWidth < 600 ? 16 : 20;
        double descriptionFontSize = screenWidth < 600 ? 14 : 17;
        double cardPadding = screenWidth < 600 ? 8.0 : 12.0; // Padding arttır
        double containerPadding = screenWidth < 600 ? 4 : 6;        return GestureDetector(
          onTap: () => _makeChoice(choice),          child: Card(
            elevation: 8, // Daha belirgin shadow efekti
            shadowColor: Colors.black.withOpacity(0.3),
            color: const Color(0xFFF5F5F5), // Beyazımsı gri renk
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Danışman ikonu ve adı
                  Container(
                    padding: EdgeInsets.all(containerPadding),
                    decoration: BoxDecoration(
                      color: advisorColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(advisorIcon, color: advisorColor, size: iconSize),
                        SizedBox(height: screenHeight * 0.002),
                        Text(
                          advisorName,
                          style: TextStyle(
                            color: advisorColor,
                            fontSize: advisorFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  // Önerinin başlığı
                  Text(
                    choice.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: titleFontSize,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenHeight * 0.007),
                  // Önerinin açıklaması
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        choice.description,
                        style: TextStyle(fontSize: descriptionFontSize, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),                    ),
                  ),
                  // Etkiler (opsiyonel - küçük gösterim)
                  if (choice.halkChange != 0 ||
                      choice.dinChange != 0 ||
                      choice.askerChange != 0 ||
                      choice.ekonomiChange != 0)
                    Container(
                      margin: EdgeInsets.only(top: screenHeight * 0.005),
                      child: _buildEffectsPreview(choice),
                    ),                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEffectsPreview(Choice choice) {
    List<Widget> effects = [];
    double multiplier = _getEffectMultiplier();

    if (choice.halkChange != 0) {
      int scaledChange = (choice.halkChange * multiplier).round();
      effects.add(
        _buildEffectIcon(
          scaledChange > 0 ? Icons.thumb_up : Icons.thumb_down,
          Colors.blue,
          scaledChange > 0,
          scaledChange.abs(),
        ),
      );
    }
    if (choice.dinChange != 0) {
      int scaledChange = (choice.dinChange * multiplier).round();
      effects.add(
        _buildEffectIcon(
          scaledChange > 0 ? Icons.thumb_up : Icons.thumb_down,
          Colors.green,
          scaledChange > 0,
          scaledChange.abs(),
        ),
      );
    }
    if (choice.askerChange != 0) {
      int scaledChange = (choice.askerChange * multiplier).round();
      effects.add(
        _buildEffectIcon(
          scaledChange > 0 ? Icons.thumb_up : Icons.thumb_down,
          Colors.red,
          scaledChange > 0,
          scaledChange.abs(),
        ),
      );
    }
    if (choice.ekonomiChange != 0) {
      int scaledChange = (choice.ekonomiChange * multiplier).round();
      effects.add(
        _buildEffectIcon(
          scaledChange > 0 ? Icons.thumb_up : Icons.thumb_down,
          Colors.orange,
          scaledChange > 0,
          scaledChange.abs(),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: effects);
  }

  Widget _buildEffectIcon(
    IconData icon,
    Color color,
    bool isPositive,
    int value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        icon,
        size: 18,
        color:
            color, // Always use full color, no pale effect for negative values
      ),
    );
  }  List<Widget> _buildAdvisorCards() {
    // Mevcut olayda bulunan danışman türlerini al
    Set<String> availableAdvisors = currentEvent.choices
        .map((choice) => choice.advisorType)
        .toSet();

    // Öncelik sırası: din, mali, askeri, diplomatik, halk
    const advisorOrder = ["din", "mali", "askeri", "diplomatik", "halk"];

    // Mevcut olaydaki danışman türlerini öncelik sırasına göre sırala
    List<String> sortedAdvisors = advisorOrder
        .where((advisor) => availableAdvisors.contains(advisor))
        .toList();

    // Her danışman türü için kart oluştur
    List<Widget> cards = [];
    for (int i = 0; i < sortedAdvisors.length; i++) {
      String advisorType = sortedAdvisors[i];
      Choice choice = currentEvent.choices.firstWhere(
        (c) => c.advisorType == advisorType,
      );      // Kart rotasyonu hesapla - iskambil tutma efekti
      double rotation = 0.0;
      
      if (sortedAdvisors.length == 1) {
        // Tek kart varsa düz dursun
        rotation = 0.0;
      } else if (sortedAdvisors.length == 2) {
        // İki kart varsa ikisi de çapraz dursun
        rotation = i == 0 ? -0.15 : 0.15;
      } else {
        // 3 veya daha fazla kart varsa orta kart düz, diğerleri çapraz
        int centerIndex = (sortedAdvisors.length / 2).floor();
        
        if (i < centerIndex) {
          // Sol taraftaki kartlar - sola doğru çapraz
          rotation = -0.2 - (centerIndex - i - 1) * 0.1;
        } else if (i > centerIndex) {
          // Sağ taraftaki kartlar - sağa doğru çapraz
          rotation = 0.2 + (i - centerIndex - 1) * 0.1;
        }
        // Ortadaki kart rotation = 0.0 (düz)
      }

      cards.add(
        Expanded(
          child: LayoutBuilder(            builder: (context, constraints) {
              double screenWidth = MediaQuery.of(context).size.width;
              double horizontalPadding = screenWidth < 600 ? 1.0 : 2.0; // Padding'i azalt
              
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Transform.rotate(
                  angle: rotation,
                  child: _buildChoiceCard(choice),
                ),
              );
            },
          ),
        ),
      );
    }
    
    return cards;
  }

  Widget _buildLevelSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Mevcut seviye bilgisi
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(
                      gameState.level.icon,
                      color: Colors.amber.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Mevcut Seviye",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          gameState.level.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),              // Yönetilen gün sayacı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${gameState.totalDays}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      "Gün Yönetildi",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Seviye atlama veya emeklilik butonu
              Expanded(
                flex: 2,
                child: gameState.level == GovernmentLevel.imparatorluk
                    ? Tooltip(
                        message: _getRetirementTooltip(),
                        child: ElevatedButton.icon(
                          onPressed: gameState.canRetire
                              ? () {
                                  _showRetirementDialog();
                                }
                              : null,
                          icon: Icon(
                            Icons.emoji_events,
                            size: 18,
                            color: gameState.canRetire
                                ? Colors.white
                                : Colors.grey,
                          ),
                          label: Text(
                            "Emekli Ol",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gameState.canRetire
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gameState.canRetire
                                ? Colors.purple.shade600
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    : Tooltip(
                        message: _getLevelUpTooltip(),
                        child: ElevatedButton.icon(
                          onPressed: gameState.canLevelUp
                              ? () {
                                  setState(() {
                                    GovernmentLevel oldLevel = gameState.level;
                                    gameState.levelUp();
                                    _showLevelUpDialog(
                                      oldLevel,
                                      gameState.level,
                                    );
                                  });
                                }
                              : null,
                          icon: Icon(
                            Icons.upgrade,
                            size: 18,
                            color: gameState.canLevelUp
                                ? Colors.white
                                : Colors.grey,
                          ),
                          label: Text(
                            "Seviye Atla",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gameState.canLevelUp
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gameState.canLevelUp
                                ? Colors.green.shade600
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  void dispose() {
    _animationController.dispose();
    // Müziği durdur (singleton olduğu için başka yerlerden de kontrol edilebilir)
    _musicService.pauseBackgroundMusic();
    super.dispose();
  }

  bool _wouldChoiceCauseGameOver(Choice choice) {
    // Government level'a göre ölçeklendirilmiş etkiler
    double multiplier = _getEffectMultiplier();

    int scaledHalkChange = (choice.halkChange * multiplier).round();
    int scaledDinChange = (choice.dinChange * multiplier).round();
    int scaledAskerChange = (choice.askerChange * multiplier).round();
    int scaledEkonomiChange = (choice.ekonomiChange * multiplier).round();

    // Mevcut değerleri simüle et
    int tempHalk = gameState.halk + scaledHalkChange;
    int tempDin = gameState.din + scaledDinChange;
    int tempAsker = gameState.asker + scaledAskerChange;
    int tempEkonomi = gameState.ekonomi + scaledEkonomiChange;

    // Seviye bazlı maksimum değerler
    int maxHalk, maxDin, maxAsker, maxEkonomi;

    switch (gameState.level) {
      case GovernmentLevel.koyu:
        maxHalk = 60;
        maxDin = 40;
        maxAsker = 40;
        maxEkonomi = 60;
        break;
      case GovernmentLevel.derebeylik:
        maxHalk = 70;
        maxDin = 50;
        maxAsker = 55;
        maxEkonomi = 70;
        break;
      case GovernmentLevel.prenslik:
        maxHalk = 75;
        maxDin = 60;
        maxAsker = 65;
        maxEkonomi = 80;
        break;
      case GovernmentLevel.krallik:
        maxHalk = 85;
        maxDin = 80;
        maxAsker = 85;
        maxEkonomi = 90;
        break;
      case GovernmentLevel.imparatorluk:
        maxHalk = 100;
        maxDin = 100;
        maxAsker = 100;
        maxEkonomi = 100;
        break;
    }

    // Oyun bitiş koşullarını kontrol et (sınırlara uygulanmadan önce)
    return (tempHalk <= 0 ||
        tempDin <= 0 ||
        tempAsker <= 0 ||
        tempEkonomi <= 0 ||
        tempHalk >= maxHalk ||
        tempDin >= maxDin ||
        tempAsker >= maxAsker ||
        tempEkonomi >= maxEkonomi);
  }  void _showRiskConfirmationDialog(Choice choice) {
    String riskMessage = _getRiskMessage(choice);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        double screenWidth = MediaQuery.of(context).size.width;
        double screenHeight = MediaQuery.of(context).size.height;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.1,
          ),
          title: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.all(screenWidth < 600 ? 12 : 16),
            child: Column(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade600,
                  size: screenWidth < 600 ? 40 : 48,
                ),
                SizedBox(height: screenWidth < 600 ? 6 : 8),
                Text(
                  "⚠️ Tehlikeli Karar!",
                  style: TextStyle(
                    fontSize: screenWidth < 600 ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          content: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.5,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth < 600 ? 12 : 16,
                vertical: screenWidth < 600 ? 8 : 12,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth < 600 ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Seçeceğin karar oyununun bitmesine sebep olabilir!",
                      style: TextStyle(
                        fontSize: screenWidth < 600 ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenWidth < 600 ? 8 : 12),
                    Text(
                      riskMessage,
                      style: TextStyle(
                        fontSize: screenWidth < 600 ? 12 : 14,
                        color: Colors.orange.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenWidth < 600 ? 12 : 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(screenWidth < 600 ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Seçeceğin karar:",
                            style: TextStyle(
                              fontSize: screenWidth < 600 ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: screenWidth < 600 ? 2 : 4),
                          Text(
                            choice.title,
                            style: TextStyle(
                              fontSize: screenWidth < 600 ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),actions: [
            Padding(
              padding: EdgeInsets.all(screenWidth < 600 ? 8 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(); // Sadece popup'ı kapat, seçimi yapma
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth < 600 ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'İptal Et',
                        style: TextStyle(
                          fontSize: screenWidth < 600 ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth < 600 ? 8 : 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Popup'ı kapat
                        _executeChoice(choice); // Seçimi gerçekleştir
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth < 600 ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Devam Et',
                        style: TextStyle(
                          fontSize: screenWidth < 600 ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getRiskMessage(Choice choice) {
    double multiplier = _getEffectMultiplier();

    int scaledHalkChange = (choice.halkChange * multiplier).round();
    int scaledDinChange = (choice.dinChange * multiplier).round();
    int scaledAskerChange = (choice.askerChange * multiplier).round();
    int scaledEkonomiChange = (choice.ekonomiChange * multiplier).round();

    int tempHalk = gameState.halk + scaledHalkChange;
    int tempDin = gameState.din + scaledDinChange;
    int tempAsker = gameState.asker + scaledAskerChange;
    int tempEkonomi = gameState.ekonomi + scaledEkonomiChange;

    List<String> risks = [];

    // Seviye bazlı maksimum değerleri al
    int maxHalk, maxDin, maxAsker, maxEkonomi;
    switch (gameState.level) {
      case GovernmentLevel.koyu:
        maxHalk = 60;
        maxDin = 40;
        maxAsker = 40;
        maxEkonomi = 60;
        break;
      case GovernmentLevel.derebeylik:
        maxHalk = 70;
        maxDin = 50;
        maxAsker = 55;
        maxEkonomi = 70;
        break;
      case GovernmentLevel.prenslik:
        maxHalk = 75;
        maxDin = 60;
        maxAsker = 65;
        maxEkonomi = 80;
        break;
      case GovernmentLevel.krallik:
        maxHalk = 85;
        maxDin = 80;
        maxAsker = 85;
        maxEkonomi = 90;
        break;
      case GovernmentLevel.imparatorluk:
        maxHalk = 100;
        maxDin = 100;
        maxAsker = 100;
        maxEkonomi = 100;
        break;
    }

    if (tempHalk <= 0) risks.add("Halk ayaklanacak");
    if (tempDin <= 0) risks.add("Din otoritesi çökecek");
    if (tempAsker <= 0) risks.add("Ordu dağılacak");
    if (tempEkonomi <= 0) risks.add("Ekonomi çökecek");

    if (tempHalk >= maxHalk) risks.add("Halk kontrolden çıkacak");
    if (tempDin >= maxDin) risks.add("Din adamları iktidarı ele geçirecek");
    if (tempAsker >= maxAsker) risks.add("Ordu diktatörlük kuracak");
    if (tempEkonomi >= maxEkonomi) {
      risks.add("Zenginlik toplumsal dengeyi bozacak");
    }

    if (risks.isEmpty) {
      return "Bu seçim oyun bitiş riskine sebep olabilir.";
    }

    return "Risk: ${risks.join(', ')}.";
  }
}
