import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_data.dart';
import 'audio_service.dart';
import 'vibration_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Sadece dikey mod (portrait) için ayarla
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  bool isTutorialCompleted; // Öğretici tamamlandı mı?
  int tutorialEventIndex; // Hangi öğretici olayındayız?
  bool hasShownTutorialChoice; // Öğretici seçim kartı gösterildi mi?
  bool playerWantsTutorial; // Oyuncu öğretici istiyor mu?
  static bool hasEverSeenTutorial = false; // Hiç öğretici gösterildi mi? (kalıcı)

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
    this.isTutorialCompleted = false,
    this.tutorialEventIndex = 0,
    this.hasShownTutorialChoice = false,
    this.playerWantsTutorial = false,
  }) : this.usedEventTitles = usedEventTitles ?? [],
       this.eventFlags = eventFlags ?? {},
       this.completedChainStories = completedChainStories ?? <String>{},
       this.advisorUsageCount =
           advisorUsageCount ??
           {'mali': 0, 'askeri': 0, 'din': 0, 'diplomatik': 0, 'halk': 0};
  bool get isGameOver {
    // Seviye bazlı maksimum değerler
    int maxHalk, maxDin, maxAsker, maxEkonomi;

    switch (this.level) {
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

    return this.halk <= 0 ||
        this.din <= 0 ||
        this.asker <= 0 ||
        this.ekonomi <= 0 ||
        this.halk >= maxHalk ||
        this.din >= maxDin ||
        this.asker >= maxAsker ||
        this.ekonomi >= maxEkonomi;
  }
  bool get canLevelUp {
    // Önce temel seviye atlama koşullarını kontrol et
    bool meetsRequirements = false;

    switch (this.level) {
      case GovernmentLevel.koyu:
        // Köyden derebeyliğe geçmek için koşullar: ekonomi ≥ 40, halk ≥ 10 ve 3 yıl (1095 gün)
        meetsRequirements = this.halk > 10 && this.ekonomi > 25 && this.daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.derebeylik:
        // Derebeylikten baronluğa geçmek için koşullar: halk > 30, ekonomi > 30, din > 40, asker >= 40 ve 3 yıl
        meetsRequirements =
            this.halk > 30 &&
            this.ekonomi > 30 &&
            this.din > 40 &&
            this.asker >= 40 &&
            this.daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.prenslik:
        // Baronluktan krallığa geçmek için koşullar: ekonomi ≥ 60, asker ≥ 30 ve baronlukta 3 yıl
        meetsRequirements = this.ekonomi >= 60 && this.asker >= 30 && this.daysAtCurrentLevel >= 1095;
        break;
      case GovernmentLevel.krallik:
        // Krallıktan imparatorluğa geçmek için koşullar: halk ≥ 60, asker ≥ 50 ve krallıkta en az 3 yıl
        meetsRequirements = this.halk >= 60 && this.asker >= 50 && this.daysAtCurrentLevel >= 1095;
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
  // Seviye atlama maliyetlerini hesapla (gerçek değişiklik yapmadan)
  Map<String, int> getLevelUpCosts() {
    Map<String, int> costs = {
      'halk': 0,
      'din': 0,
      'asker': 0,
      'ekonomi': 0,
    };

    switch (level) {
      case GovernmentLevel.koyu:
        // Köyden derebeyliğe geçiş maliyeti
        costs['ekonomi'] = -25;
        costs['halk'] = -10;
        costs['asker'] = 10;
        break;
      case GovernmentLevel.derebeylik:
        // Derebeylikten baronluğa geçiş maliyeti
        costs['halk'] = -30;
        costs['ekonomi'] = -30;
        costs['din'] = -40;
        costs['asker'] = 15;
        break;
      case GovernmentLevel.prenslik:
        // Baronluktan krallığa geçiş maliyeti
        // Halk: 40'tan düşükse -10, 40'tan yüksekse +10
        if (halk < 40) {
          costs['halk'] = -10;
        } else {
          costs['halk'] = 10;
        }
        // Din: 40'tan düşükse -10, 40'tan yüksekse +10
        if (din < 40) {
          costs['din'] = -10;
        } else {
          costs['din'] = 10;
        }
        // Asker: 40'tan düşükse -10, 40'tan yüksekse +10
        if (asker < 40) {
          costs['asker'] = -10;
        } else {
          costs['asker'] = 10;
        }
        // Ekonomi: her durumda -30
        costs['ekonomi'] = -30;
        break;
      case GovernmentLevel.krallik:
        // Krallıktan imparatorluğa geçiş maliyeti
        costs['asker'] = -30;
        costs['halk'] = -20;
        costs['ekonomi'] = -40;
        break;
      default:
        break;
    }

    return costs;
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
      }      // Yeni seviyenin maksimum değerlerine göre sınırla
      halk = halk.clamp(0, maxHalk);
      din = din.clamp(0, maxDin);
      asker = asker.clamp(0, maxAsker);
      ekonomi = ekonomi.clamp(0, maxEkonomi);
    }
  }  // Static değişkenleri sıfırlama metodu (ana sayfaya dönüş için)
  static void resetTutorialState() {
    // Bu metod tutorial durumunu tamamen sıfırlar
    hasEverSeenTutorial = false;
  }
  // Sadece oyun durumunu sıfırlama (tutorial durumunu korur)
  static void resetGameStateOnly() {
    // Tutorial durumunu korurken sadece oyun durumunu sıfırla
    // hasEverSeenTutorial değiştirilmez
  }

  // GameState'i JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'halk': halk,
      'din': din,
      'asker': asker,
      'ekonomi': ekonomi,
      'level': level.index,
      'turnCount': turnCount,
      'totalDays': totalDays,
      'daysAtCurrentLevel': daysAtCurrentLevel,
      'usedEventTitles': usedEventTitles,
      'eventFlags': eventFlags,
      'completedChainStories': completedChainStories.toList(),
      'maxChainStories': maxChainStories,
      'advisorUsageCount': advisorUsageCount,
      'isTutorialCompleted': isTutorialCompleted,
      'tutorialEventIndex': tutorialEventIndex,
      'hasShownTutorialChoice': hasShownTutorialChoice,
      'playerWantsTutorial': playerWantsTutorial,
      'hasEverSeenTutorial': hasEverSeenTutorial,
    };
  }

  // JSON'dan GameState oluştur
  static GameState fromJson(Map<String, dynamic> json) {
    return GameState(
      halk: json['halk'] ?? 35,
      din: json['din'] ?? 28,
      asker: json['asker'] ?? 25,
      ekonomi: json['ekonomi'] ?? 40,
      level: GovernmentLevel.values[json['level'] ?? 0],
      turnCount: json['turnCount'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
      daysAtCurrentLevel: json['daysAtCurrentLevel'] ?? 0,
      usedEventTitles: List<String>.from(json['usedEventTitles'] ?? []),
      eventFlags: Map<String, dynamic>.from(json['eventFlags'] ?? {}),
      completedChainStories: Set<String>.from(json['completedChainStories'] ?? []),
      maxChainStories: json['maxChainStories'] ?? 2,
      advisorUsageCount: Map<String, int>.from(json['advisorUsageCount'] ?? 
          {'mali': 0, 'askeri': 0, 'din': 0, 'diplomatik': 0, 'halk': 0}),
      isTutorialCompleted: json['isTutorialCompleted'] ?? false,
      tutorialEventIndex: json['tutorialEventIndex'] ?? 0,
      hasShownTutorialChoice: json['hasShownTutorialChoice'] ?? false,
      playerWantsTutorial: json['playerWantsTutorial'] ?? false,
    )..setStaticFromJson(json);
  }

  // Static değerleri ayarla
  void setStaticFromJson(Map<String, dynamic> json) {
    GameState.hasEverSeenTutorial = json['hasEverSeenTutorial'] ?? false;
  }

  // Oyunu kaydet
  static Future<void> saveGame(GameState gameState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameJson = jsonEncode(gameState.toJson());
      await prefs.setString('saved_game', gameJson);
      await prefs.setBool('has_saved_game', true);
    } catch (e) {
      print('Oyun kaydedilemedi: $e');
    }
  }

  // Oyunu yükle
  static Future<GameState?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameJson = prefs.getString('saved_game');
      
      if (gameJson != null) {
        final gameData = jsonDecode(gameJson);
        return GameState.fromJson(gameData);
      }
    } catch (e) {
      print('Oyun yüklenemedi: $e');
    }
    return null;
  }

  // Kaydedilmiş oyun var mı kontrol et
  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_saved_game') ?? false;
    } catch (e) {
      return false;
    }
  }

  // Kaydedilmiş oyunu sil
  static Future<void> deleteSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_game');
      await prefs.setBool('has_saved_game', false);
    } catch (e) {
      print('Kayıt silinemedi: $e');
    }
  }
}

// Açılış Sayfası
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _hasSavedGame = false;
  @override
  void initState() {
    super.initState();
    _checkSavedGame();
    _loadAudioSettings();
  }

  Future<void> _checkSavedGame() async {
    final hasSaved = await GameState.hasSavedGame();
    setState(() {
      _hasSavedGame = hasSaved;
    });
  }
  
  Future<void> _loadAudioSettings() async {
    await AudioSettings.loadSettings();
  }

  @override
  void dispose() {
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
        ),
        child: Stack(          children: [            // Ana içerik - logo ve başlat butonu
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1), // Üstten %10 boşluk
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  // Gri tonlamalı oyun ikonu - ekran genişliğini dolduracak şekilde
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, 20, // Daha açık gri tonlar için değerler ayarlandı
                      0.33, 0.33, 0.33, 0, 20, // Son sayılar parlaklık değeri (brightness)
                      0.33, 0.33, 0.33, 0, 20,
                      0, 0, 0, 1, 0,
                    ]),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        double screenWidth = MediaQuery.of(context).size.width;
                        double iconWidth = screenWidth * 0.95; // Ekranın %95'ini kaplasın
                        double iconHeight = iconWidth * 0.8; // Yükseklik genişliğin %80'i olsun
                        
                        return Container(
                          width: iconWidth,
                          height: iconHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            // Yumuşak gölge ekleyerek arkaplan ile karışmasını sağla
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade800.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Image.asset(
                            'icon/file_0000000082b86243a1042895da19c517.png',
                            fit: BoxFit.contain, // İçeriği koruyarak sığdır
                          ),
                        );
                      },
                    ),
                  ),                  const SizedBox(height: 50), // Boşluğu da arttırdık
                  
                  // Oyun butonları
                  Column(
                    children: [
                      // Devam Et butonu (sadece kaydedilmiş oyun varsa görünür)
                      if (_hasSavedGame) ...[
                        GestureDetector(
                          onTap: () async {
                            final savedGame = await GameState.loadGame();
                            if (savedGame != null) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => GameScreen(initialGameState: savedGame),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 120,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1A5D1A),
                                  Color(0xFF0F3F0F),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'DEVAM ET',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Yeni Oyun/Başlat butonu
                      GestureDetector(
                        onTap: () {
                          // Yeni oyun başlarken sadece gerekirse tutorial durumunu sıfırla
                          // Eğer kullanıcı daha önce hiç tutorial görmemişse, tutorial seçimi gösterilecek
                          // Eğer görmüşse, direkt oyuna başlayacak
                          
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
                          ),                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              // Ayarlar butonu - sağ alt köşe
            Positioned(
              bottom: 50,
              right: 30,
              child: GestureDetector(
                onTap: () {
                  _showSettingsDialog(context);
                },                onLongPress: () async {
                  // Gizli özellik: Long press ile tutorial durumunu sıfırla (test için)
                  GameState.resetTutorialState();
                  await AudioSettings.saveTutorialToggleSetting(true); // Toggle'ı da sıfırla
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tutorial durumu tamamen sıfırlandı (Test modu)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
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
                  ),                ),
                const SizedBox(height: 30),
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
                  const SizedBox(height: 15),                  // Müzik Açma/Kapatma
                _buildSettingItem(
                  icon: Icons.music_note,
                  title: 'Müzik',
                  isToggle: true,
                  value: AudioSettings.isMusicEnabled,
                  onChanged: (value) async {
                    await AudioSettings.saveMusicSetting(value);
                    setDialogState(() {
                      // UI'yi güncelle
                    });
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Ses Efektleri Açma/Kapatma
                _buildSettingItem(
                  icon: Icons.volume_up,
                  title: 'Ses Efektleri',
                  isToggle: true,
                  value: AudioSettings.isSoundEffectsEnabled,
                  onChanged: (value) async {
                    await AudioSettings.saveSoundEffectsSetting(value);
                    setDialogState(() {
                      // UI'yi güncelle
                    });
                  },
                ),
                
                const SizedBox(height: 15),

                // Titreşim Açma/Kapatma
                _buildSettingItem(
                  icon: Icons.vibration,
                  title: 'Titreşim',
                  isToggle: true,
                  value: AudioSettings.isVibrationEnabled,
                  onChanged: (value) async {
                    await AudioSettings.saveVibrationSetting(value);
                    setDialogState(() {
                      // UI'yi güncelle
                    });
                  },
                ),
                const SizedBox(height: 15),
                
                // Tutorial Toggle
                _buildSettingItem(
                  icon: Icons.school,
                  title: 'Öğreticiyi Göster',
                  isToggle: false,
                  isEnabled: true,
                  onTap: () async {
                    // Kutucuğa tıklanınca tutorial ayarını aç ve tutorial'ı bir sonraki oyun başında gösterilecek şekilde ayarla
                    await AudioSettings.saveTutorialToggleSetting(true);
                    GameState.hasEverSeenTutorial = false;
                    setDialogState(() {
                      // UI güncellensin
                    });
                    // Kullanıcıya bilgi ver
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Öğretici, oyuna bir sonraki girişte gösterilecek.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  subtitle: null,
                  value: AudioSettings.isTutorialToggleEnabled && !GameState.hasEverSeenTutorial,
                ),
                
                const SizedBox(height: 15),                
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
    bool isEnabled = true,
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
            color: isEnabled ? Colors.white70 : Colors.white30,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isEnabled ? Colors.white : Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(isEnabled ? 0.6 : 0.3),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          if (isToggle)
            Switch(
              value: value,
              onChanged: isEnabled ? onChanged : null,
              activeColor: isEnabled ? Colors.white : Colors.grey,
              activeTrackColor: isEnabled ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
              inactiveThumbColor: Colors.white.withOpacity(isEnabled ? 0.5 : 0.3),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
            )
          else if (title == 'Öğreticiyi Göster')
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                child: Icon(
                  value ? Icons.check_box : Icons.check_box_outline_blank,
                  color: value ? Colors.greenAccent : Colors.white54,
                  size: 26,
                ),
              ),
            )
          else if (onTap != null)
            GestureDetector(
              onTap: isEnabled ? onTap : null,
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(isEnabled ? 0.6 : 0.3),
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
  final GameState? initialGameState;
  
  const GameScreen({super.key, this.initialGameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameState gameState;
  late List<EventCard> events;
  late EventCard currentEvent;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _cardFlipController;
  late Animation<double> _cardFlipAnimation;
    // Audio service instance
  final AudioService _audioService = AudioService();
  
  // Geri tuşu kontrolü için
  DateTime? _lastBackPressed;  @override
  void initState() {
    super.initState();
    // WidgetsBindingObserver'ı ekle
    WidgetsBinding.instance.addObserver(this);
    
    // Kaydedilmiş oyun varsa onu kullan, yoksa yeni oyun oluştur
    gameState = widget.initialGameState ?? GameState();
    
    _initializeEvents();
    _selectRandomEvent();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
    _animationController.forward();
    
    // Kart flip animasyonu için
    _cardFlipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardFlipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardFlipController,
      curve: Curves.easeInOut,
    ));

    // Audio service'i başlat ve arkaplan mü
    //ziğini çal
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _audioService.initialize();      await _audioService.startBackgroundMusic();
    });
  }  void _initializeEvents() {
    // Mevcut seviyeyi string olarak al (game_data.dart'daki governmentLevels ile uyumlu)
    String currentLevel = _getCurrentLevelString();
    
    if (!gameState.hasShownTutorialChoice) {
      // İlk kez oyuna başlıyorsa öğretici seçim kartını göster
      // Bu kart özel olarak işlenecek, ama yine de events listesini başlat
      events = GameData.getEvents(currentGovernmentLevel: currentLevel); // Seviye filtresini kullan
      return;
    } else if (gameState.playerWantsTutorial && !gameState.isTutorialCompleted) {
      // Öğretici modunda sadece tutorial kartları
      events = GameData.getTutorialEvents();
    } else {
      // Normal oyun kartları - seviye filtresini kullan
      events = GameData.getEvents(currentGovernmentLevel: currentLevel);
    }
  }

  // Mevcut seviyeyi game_data.dart ile uyumlu string formatında döndür
  String _getCurrentLevelString() {
    switch (gameState.level) {
      case GovernmentLevel.koyu:
        return "köy";
      case GovernmentLevel.derebeylik:
        return "derebeylik";
      case GovernmentLevel.prenslik:
        return "baronluk";
      case GovernmentLevel.krallik:
        return "krallık";
      case GovernmentLevel.imparatorluk:
        return "imparatorluk";
    }
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
  }  void _selectRandomEvent() {
    final random = Random();

    // Eğer daha önce hiç öğretici gösterilmişse, öğretici seçim kartını gösterme
    if (GameState.hasEverSeenTutorial) {
      // Direkt normal oyuna geç, öğretici seçimini tekrar gösterme
      if (!gameState.hasShownTutorialChoice) {
        gameState.hasShownTutorialChoice = true;
        gameState.playerWantsTutorial = false;
        gameState.isTutorialCompleted = true;
      }
    }

    // İlk kez oyuna başlıyorsa ve daha önce hiç öğretici gösterilmemişse öğretici seçim kartını göster
    if (!gameState.hasShownTutorialChoice && !GameState.hasEverSeenTutorial) {
      currentEvent = GameData.getTutorialStartCard();
      return;
    }

    // Öğretici modundaysa
    if (gameState.playerWantsTutorial && !gameState.isTutorialCompleted) {
      if (gameState.tutorialEventIndex < events.length) {
        currentEvent = events[gameState.tutorialEventIndex];
        return;
      } else {
        // Öğretici tamamlandı, normal oyuna geç
        gameState.isTutorialCompleted = true;
        _initializeEvents(); // Normal kartları yükle
        // İlk normal kartı seç
        _selectRandomEvent();
        return;
      }
    }    // Normal oyun mantığı...
    List<EventCard> chainEvents = []; // GameData.getChainEvents(gameState.eventFlags); // Geçici olarak kapatıldı

    if (chainEvents.isNotEmpty) {
      // Zincirleme olay varsa önceliği ona ver
      currentEvent = chainEvents[random.nextInt(chainEvents.length)];
      return;
    }    // Önce kullanılmamış eventleri filtrele
    List<EventCard> unusedEvents = events
        .where((event) => !gameState.usedEventTitles.contains(event.title))
        .toList();

    // Eğer zincirleme hikaye limiti dolmuşsa, zincirleme başlatıcı kartları çıkar
    if (gameState.maxChainStories >= 2) { // completedChainStories geçici olarak kapatıldı
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
      if (gameState.maxChainStories >= 2) { // completedChainStories geçici olarak kapatıldı
        unusedEvents = unusedEvents
            .where(
              (event) =>
                  event.title != "Gizemli Hastalık" &&
                  event.title != "Ejder Efsanesi" &&
                  event.title != "Gizli Hazine",
            )
            .toList();
      }
    }    // Son güvenlik kontrolü - eğer hala boşsa, events listesini yeniden yükle
    if (unusedEvents.isEmpty) {
      events = GameData.getEvents(currentGovernmentLevel: _getCurrentLevelString());
      unusedEvents = events;
    }

    // Rastgele bir kullanılmamış event seç
    if (unusedEvents.isNotEmpty) {
      currentEvent = unusedEvents[random.nextInt(unusedEvents.length)];
      // Bu eventi kullanılanlar listesine ekle
      gameState.usedEventTitles.add(currentEvent.title);
    } else {
      // Eğer hala event bulunamazsa, ilk eventi kullan
      events = GameData.getEvents(currentGovernmentLevel: _getCurrentLevelString());
      if (events.isNotEmpty) {
        currentEvent = events[0];
      }
    }
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
    }  }  void _executeChoice(Choice choice) {
    // Öğretici seçim kartıysa özel işlem yap
    if (!gameState.hasShownTutorialChoice) {
      setState(() {
        gameState.hasShownTutorialChoice = true;
        GameState.hasEverSeenTutorial = true; // Kalıcı olarak öğretici gösterildi işaretle
        if (choice.title == "Evet, Rehberlik İstiyorum") {
          gameState.playerWantsTutorial = true;
        } else {
          gameState.playerWantsTutorial = false;
          gameState.isTutorialCompleted = true; // Öğreticiyi atla
        }
      });
      // Tutorial toggle'ı yeniden aktifleştir ve kaydet
      AudioSettings.saveTutorialToggleSetting(true);
      _initializeEvents(); // Kartları yeniden yükle
      _animationController.reset();
      _selectRandomEvent();
      _animationController.forward();
      return;
    }

    // Danışman kartı seçildiğinde titreşim tetikle
    VibrationHelper.vibrateOnTap();

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
          (gameState.advisorUsageCount[choice.advisorType] ?? 0) + 1;      // Zincirleme olaylar için flag'leri ayarla
      // GameData.setEventFlags(
      //   currentEvent.title,
      //   choice.title,
      //   gameState.eventFlags,
      //   <String>{}, // completedChainStories geçici olarak boş set
      // ); // Geçici olarak kapatıldı
        // Öğretici modundaysa sonraki karta geç
      if (gameState.playerWantsTutorial && !gameState.isTutorialCompleted) {
        gameState.tutorialEventIndex++;
      }    });

    if (gameState.isGameOver) {
      _showGameOverDialog();
    } else {
      // Oyun devam ediyorsa durumu kaydet
      GameState.saveGame(gameState);
      
      _animationController.reset();
      _selectRandomEvent();
      _animationController.forward();
    }  }void _showGameOverDialog() {
    // Arkaplan müziğini durdur ve başarısızlık sesi çal
    _audioService.stopBackgroundMusic();
    _audioService.playFailureSound();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF222222), // Siyaha yakın koyu gri arkaplan
          title: Container(
            alignment: Alignment.center,
            child: Column(
              children: [
                // Yenilgi resmi ekleme - büyütülmüş
                Container(
                  width: 300,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade800, width: 4),
                    image: const DecorationImage(
                      image: AssetImage("city/basarisizlik.jpg"),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
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
                  color: const Color(0xFF333333), // Koyu gri arkaplan
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: Column(
                  children: [
                    // Daha belirgin oyun sonu mesajı
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF444444), // Biraz daha açık gri
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade900, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        _getGameOverReason(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade300, // Koyu tema üzerinde altın sarısı metin
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3A), // Biraz daha açık gri
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.amber.shade400, // Koyu tema üzerinde altın sarısı ikon
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Yönetilen Süre:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade300, // Açık gri metin
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimePassed(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade300, // Koyu tema üzerinde altın sarısı metin
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
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            // Butonları yatay olarak yan yana gösterilen ikonlu kare butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Yeniden Başla Butonu (sadece ikon)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 60,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Kaydedilmiş oyunu sil
                      await GameState.deleteSavedGame();
                      Navigator.of(context).pop();
                      // Yeni oyun başlarken sadece game state'i sıfırla, tutorial durumunu koru
                      setState(() {
                        gameState = GameState();
                        _initializeEvents();
                        _selectRandomEvent();
                      });
                      // Arkaplan müziğini yeniden başlat
                      await _audioService.startBackgroundMusic();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700, // Koyu tema için daha koyu yeşil
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Icon(Icons.refresh, color: Colors.white, size: 30),
                  ),
                ),
                // Ana Sayfaya Dön Butonu (sadece ikon)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 60,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Kaydedilmiş oyunu sil
                      await GameState.deleteSavedGame();
                      // Audio service'i durdur
                      _audioService.stopBackgroundMusic();
                      // Tutorial durumunu sıfırlama - kullanıcı bir kez gördüyse tekrar gösterme
                      // GameState.resetTutorialState();
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const StartScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700, // Koyu tema için daha koyu mavi
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Icon(Icons.home, color: Colors.white, size: 30),
                  ),
                ),
                // Kaldığın Yerden Devam Et (Reklamlı) Butonu
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: double.infinity,
                  height: 48,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ElevatedButton(
                        onPressed: () {
                          // Reklam izleme ve devam etme işlemi burada olacak (şimdilik sadece uyarı)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.ondemand_video, color: Colors.amber.shade700),
                                  const SizedBox(width: 8),
                                  const Text('Reklam izleme özelliği yakında eklenecek!'),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700, // Reklam için turuncu
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite, color: Colors.white, size: 32),
                            const SizedBox(width: 12),
                            Icon(Icons.ondemand_video, color: Colors.amber, size: 22),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
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
    }  }  void _showLevelUpDialog(GovernmentLevel oldLevel, GovernmentLevel newLevel) {
    // Seviye atlama sesi çal
    _audioService.playLevelUpSound();
    
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
                      errorBuilder: (context, error, stackTrace) {                        // Görsel yüklenemedi hatası
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
          ),          actions: [
            // Devam Et Butonu
            SizedBox(
              width: double.infinity,              child: ElevatedButton.icon(
                onPressed: () {
                  // Seviye atlama sonrası oyunu kaydet
                  GameState.saveGame(gameState);
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
    );  }

  void _showLevelUpConfirmationDialog() {
    Map<String, int> costs = gameState.getLevelUpCosts();
    
    // Mevcut seviye ve bir sonraki seviye
    GovernmentLevel currentLevel = gameState.level;
    GovernmentLevel nextLevel = GovernmentLevel.values[currentLevel.index + 1];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Container(
            alignment: Alignment.center,
            child: Text(
              "Seviye Atlama Onayı",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seviye geçişi gösterimi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(currentLevel.icon, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        currentLevel.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Icon(nextLevel.icon, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        nextLevel.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Maliyetler gösterimi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Seviye Atlama Maliyetleri:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...costs.entries.where((entry) => entry.value != 0).map((entry) {
                        Color textColor = entry.value > 0 ? Colors.green.shade700 : Colors.red.shade700;
                        String sign = entry.value > 0 ? "+" : "";
                        String statName = "";
                        IconData statIcon = Icons.help;
                        
                        switch (entry.key) {
                          case 'halk':
                            statName = "Halk";
                            statIcon = Icons.groups;
                            break;
                          case 'din':
                            statName = "Din";
                            statIcon = Icons.church;
                            break;
                          case 'asker':
                            statName = "Asker";
                            statIcon = Icons.security;
                            break;
                          case 'ekonomi':
                            statName = "Ekonomi";
                            statIcon = Icons.attach_money;
                            break;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(statIcon, size: 16, color: textColor),
                              const SizedBox(width: 8),
                              Text(
                                statName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "$sign${entry.value}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Text(
                  "Bu maliyetleri ödeyerek seviye atlamak istediğinize emin misiniz?",
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            // İptal butonu
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'İptal',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Onayla butonu
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                
                // Gerçek seviye atlama işlemini yap
                setState(() {
                  GovernmentLevel oldLevel = gameState.level;
                  gameState.levelUp();
                  _showLevelUpDialog(
                    oldLevel,
                    gameState.level,
                  );
                });
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Seviye Atla',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                    color: personalityAnalysis['color'].withOpacity(0.1),
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
                          color: personalityAnalysis['color'].withOpacity(0.2),
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
              width: double.infinity,              child: ElevatedButton.icon(
                onPressed: () async {
                  // Kaydedilmiş oyunu sil
                  await GameState.deleteSavedGame();
                  
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
          requirementMessage = missing.join(', ');
        }
        break;
      case GovernmentLevel.derebeylik:        meetsRequirements =            gameState.halk > 30 &&
            gameState.ekonomi > 30 &&
            gameState.din > 40 &&            gameState.asker >= 40 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.halk <= 30) missing.add("Halk > 30");
          if (gameState.ekonomi <= 30) missing.add("Ekonomi > 30");
          if (gameState.din <= 40) missing.add("Din > 40");
          if (gameState.asker < 40) missing.add("Asker ≥ 40");          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = missing.join(', ');
        }
        break;      case GovernmentLevel.prenslik:        meetsRequirements =
            gameState.ekonomi >= 60 &&
            gameState.asker >= 30 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.ekonomi < 60) missing.add("Ekonomi ≥ 60");
          if (gameState.asker < 30) missing.add("Asker ≥ 30");          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = missing.join(', ');
        }
        break;      case GovernmentLevel.krallik:        meetsRequirements =
            gameState.halk >= 60 &&
            gameState.asker >= 50 &&
            gameState.daysAtCurrentLevel >= 1095;
        if (!meetsRequirements) {
          List<String> missing = [];
          if (gameState.halk < 60) missing.add("Halk ≥ 60");
          if (gameState.asker < 50) missing.add("Asker ≥ 50");
          if (gameState.daysAtCurrentLevel < 1095) missing.add("3 yıl tamamla");
          requirementMessage = missing.join(', ');
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
    double cardPadding = screenWidth < 600 ? 12.0 : 16.0;    int eventCardFlex = screenHeight < 700 ? 3 : 2;
    int choiceCardFlex = screenHeight < 700 ? 2 : 2;

    return WillPopScope(      onWillPop: () async {
        DateTime now = DateTime.now();
        
        if (_lastBackPressed == null || 
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          // İlk geri tuşu basışı veya 2 saniyeden fazla zaman geçmişse
          _lastBackPressed = now;
          
          // Kullanıcıya bilgi ver
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Çıkmak için tekrar geri tuşuna basın'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.black87,
            ),
          );
          
          return false; // Uygulamadan çıkma
        }
        
        // İkinci geri tuşu basışı - oyunu kaydet ve uygulamadan çık
        await GameState.saveGame(gameState);
        return true;
      },child: Scaffold(
        body: Container(decoration: const BoxDecoration(
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
                    opacity: _fadeAnimation,                    child: Card(
                      elevation: 8,
                      color: Colors.black.withValues(alpha: 0.8),
                      child: Stack(
                        children: [                          // Arka plan resmi (eğer varsa)
                          if (currentEvent.imagePath.isNotEmpty) ...[
                            Builder(builder: (context) {
                              // Resim yolu mevcut
                              return const SizedBox.shrink();
                            }),
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  currentEvent.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {                                    // Resim yüklenemiyor
                                    return Container(
                                      color: Colors.grey.shade800,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey.shade400,
                                            size: 48,
                                          ),
                                          Text(
                                            'Resim yüklenemedi',
                                            style: TextStyle(color: Colors.grey.shade400),
                                          ),
                                        ],
                                      ),
                                    );
                                  },                                ),
                              ),
                            ),
                          ],
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
                ),              ),
            ],          ),        ),
      ),
    ), // Scaffold kapanış
  ); // WillPopScope kapanış
  }

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
        // Yazı boyutlarını büyütüyoruz:
        double labelFontSize = screenWidth < 600 ? 14 : 16;
        double valueFontSize = screenWidth < 600 ? 15 : 18;

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
                color: color.withOpacity(0.3),
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
              style: TextStyle(color: Colors.white, fontSize: valueFontSize, fontWeight: FontWeight.bold),
            ),
          ],
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
        double screenHeight = MediaQuery.of(context).size.height;        double iconSize = screenWidth < 600 ? 18 : 22;
        double advisorFontSize = screenWidth < 600 ? 13 : 13;
        double titleFontSize = screenWidth < 600 ? 16 : 19;
        double descriptionFontSize = screenWidth < 600 ? 14 : 16;
        double cardPadding = screenWidth < 600 ? 8.0 : 12.0; // Padding arttır

        double containerPadding = screenWidth < 600 ? 4 : 6;        return MouseRegion(
         
          child: AnimatedBuilder(
            animation: _cardFlipAnimation,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(0.1 * _cardFlipAnimation.value),                child: GestureDetector(
                  onTap: () async {
                    // Kart flip animasyonu çal
                    _cardFlipController.forward().then((_) {
                      _cardFlipController.reverse();
                    });
                
                    // Seçimi gerçekleştir
                    _executeChoice(choice);
                  },
            child: Card(
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
                      choice.ekonomiChange != 0)                    Container(
                      margin: EdgeInsets.only(top: screenHeight * 0.005),
                      child: _buildEffectsPreview(choice),
                    ),
                ],
              ),
            ),
          ),
                ),
              );
            },
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
              // Mevcut seviye bilgisi - tıklanabilir
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _showLevelInfoPopup(context),
                  borderRadius: BorderRadius.circular(8),
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
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            gameState.level.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Yönetilen gün sayacı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${gameState.totalDays}",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      "Gün Yönetildi",
                      style: TextStyle(
                        fontSize: 11,
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
                        child: ElevatedButton.icon(                          onPressed: gameState.canLevelUp
                              ? () {
                                  _showLevelUpConfirmationDialog();
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
    );  }
  
  // Uygulama yaşam döngüsü değiştiğinde çağrılacak metod
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Uygulama ön pl<ana geldiğinde ses ayarlarını kontrol et
    if (state == AppLifecycleState.resumed) {
      _controlBackgroundMusic();
    }
  }  // Müzik durumunu kontrol et ve güncelle
  void _controlBackgroundMusic() async {
    await _audioService.controlBackgroundMusic();
  }@override
  void dispose() {
    // WidgetsBindingObserver'ı kaldır
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _cardFlipController.dispose();
    
    // Audio service'i durdur
    _audioService.stopBackgroundMusic();
    _audioService.dispose();
  
    super.dispose();
  }
  // Seviye bilgisi popup'ı
  void _showLevelInfoPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Stack(
            children: [
              // Geri butonu (sol üst köşede)
              Positioned(
                left: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
              ),
              // Başlık metni (ortalanmış)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    "İlerleme",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Seviye: ${gameState.level.name}", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text("Toplam yönetilen gün: ${gameState.totalDays}"),
                SizedBox(height: 12),
                  // İlerleme bilgisi - oyunu tamamlama yüzdesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Oyun İlerlemesi:"),
                    Text(_getLevelProgressText(), style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                
                // İlerleme çubuğu - seviye bazlı ilerlemeyi gösterir
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _getLevelProgressValue(),
                    minHeight: 15,
                    backgroundColor: Colors.grey.shade300,                    valueColor: AlwaysStoppedAnimation<Color>(
                      gameState.canRetire ? Colors.green.shade700 : 
                      gameState.level == GovernmentLevel.imparatorluk ? Colors.amber.shade800 : 
                      Colors.amber.shade700,
                    ),
                  ),
                ),
                
                // Kalan seviye bilgisi
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [                    Text(
                      gameState.canRetire ? 
                      "Tebrikler! Emekli olabilirsiniz!" : 
                      gameState.level == GovernmentLevel.imparatorluk ? 
                      "İmparatorluk seviyesindesiniz! Emekli olmak için tüm değerleri 50'nin üzerine çıkarın." :
                      gameState.canLevelUp ? 
                      "Seviye atlamaya hazırsınız! Düğmeye tıklayarak ilerleyebilirsiniz." :
                      _getLevelUpTooltip(),
                      style: TextStyle(
                        fontSize: 12,
                        color: gameState.canRetire ? 
                          Colors.green.shade700 : 
                          gameState.level == GovernmentLevel.imparatorluk ? 
                          Colors.amber.shade700 :
                          gameState.canLevelUp ?
                          Colors.green.shade600 :
                          Colors.grey.shade700,
                        fontWeight: gameState.canRetire || gameState.level == GovernmentLevel.imparatorluk || gameState.canLevelUp ? 
                          FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),          actions: [
            // İki butonun yan yana gösterilmesi için Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Poşet ikonu (varsa) veya para/kese ikonu
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    Icons.shopping_bag, // Poşet ikonu (Flutter Material Icons)
                    color: Colors.amber.shade700,
                    size: 24,
                  ),
                ),
                // İstatistik butonu (yalnızca ikon)
                IconButton(
                  icon: const Icon(Icons.insights),
                  color: Colors.purple.shade700,
                  iconSize: 24,
                  onPressed: () {
                    Navigator.of(context).pop(); // Önce mevcut dialog'u kapat
                    _showStatisticsDialog(context); // İstatistik dialog'unu göster
                  },
                ),
                const SizedBox(width: 24), // Butonlar arası boşluk
                // Ayarlar butonu (yalnızca ikon)
                IconButton(
                  icon: const Icon(Icons.settings),
                  color: Colors.blue.shade700,
                  iconSize: 24,
                  onPressed: () {
                    Navigator.of(context).pop(); // Önce mevcut dialog'u kapat
                    _showSettingsDialog(context); // Ayarlar dialog'unu göster
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
    // Ayarlar dialog'u
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),              title: Stack(
                children: [                  // Geri butonu (sol üst köşede) - level info popup'a dön
                  Positioned(
                    left: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.of(context).pop(); // Önce ayarlar dialogunu kapat
                        // Kısa bir gecikme ile level info popup'ı göster
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _showLevelInfoPopup(context);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ),
                  // Başlık (ortalanmış)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings, color: Colors.amber.shade800),
                          const SizedBox(width: 10),
                          Text(
                            "Ayarlar",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Müzik ayarı
                  SwitchListTile(
                    title: const Text('Müzik'),
                    value: AudioSettings.isMusicEnabled,
                    onChanged: (bool value) async {
                      setDialogState(() {
                        AudioSettings.isMusicEnabled = value;
                      });
                      if (value) {
                        await _audioService.startBackgroundMusic();
                      } else {
                        await _audioService.stopBackgroundMusic();
                      }
                      await AudioSettings.saveMusicSetting(value);
                    },
                    secondary: Icon(
                      AudioSettings.isMusicEnabled ? Icons.music_note : Icons.music_off,
                      color: AudioSettings.isMusicEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  // Ses Efektleri ayarı
                  SwitchListTile(
                    title: const Text('Ses Efektleri'),
                    value: AudioSettings.isSoundEffectsEnabled,
                    onChanged: (bool value) async {
                      setDialogState(() {
                        AudioSettings.isSoundEffectsEnabled = value;
                      });
                      await AudioSettings.saveSoundEffectsSetting(value);
                    },
                    secondary: Icon(
                      AudioSettings.isSoundEffectsEnabled ? Icons.volume_up : Icons.volume_off,
                      color: AudioSettings.isSoundEffectsEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),actions: [],
            );
          },
        );
      },
    );
  }

  // Mevcut seviye indeksini döndür (0-4 arası)
  int _getCurrentLevelIndex() {
    switch (gameState.level) {
      case GovernmentLevel.koyu:
        return 0;
      case GovernmentLevel.derebeylik:
        return 1;
      case GovernmentLevel.prenslik:
        return 2;
      case GovernmentLevel.krallik:
        return 3;
      case GovernmentLevel.imparatorluk:
        return 4;
    }
  }
  // İlerleme değerini hesapla (0.0 - 1.0 arası)
  double _getLevelProgressValue() {
    // Emekli olabilir durumdaysa %100 göster
    if (gameState.canRetire) {
      return 1.0;
    }
    
    // İmparatorluk seviyesinde ama emekli olamıyorsa %90'da tut
    if (gameState.level == GovernmentLevel.imparatorluk) {
      return 0.9;
    }
    
    // Diğer seviyelerde orantılı olarak ilerle (ilk 4 seviye için %0-%80 arası)
    // İmparatorluk öncesindeki son seviye (Krallık) maksimum %80 göstersin
    return _getCurrentLevelIndex() / 5.0; // 5.0 = tam ilerleme için bölüm faktörü
  }
    // İlerleme yüzdesini metin olarak döndür
  String _getLevelProgressText() {
    int yuzde = (_getLevelProgressValue() * 100).round();
    
    // İmparatorlukta ama emekli olamıyorsa eksik koşulları belirt
    if (gameState.level == GovernmentLevel.imparatorluk && !gameState.canRetire) {
      List<String> missing = [];
      if (gameState.halk < 50) missing.add("Halk");
      if (gameState.din < 50) missing.add("Din"); 
      if (gameState.asker < 50) missing.add("Asker");
      if (gameState.ekonomi < 50) missing.add("Ekonomi");
      
      String eksikler = missing.join(', ');
      return "%$yuzde (Emeklilik için: $eksikler ≥ 50)";
    }
    
    return "%$yuzde";
  }
  // İstatistik dialogu
  void _showStatisticsDialog(BuildContext context) {
    // Danışman kullanım sayılarını topla - hiç danışman kullanılmadıysa 0 olacaktır
    final totalAdvisorUsage = gameState.advisorUsageCount.values.fold<int>(0, (sum, count) => sum + count);
    
    // Henüz hiç karar vermediyse farklı bir dialog göster
    if (totalAdvisorUsage == 0) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Stack(
              children: [
                // Geri butonu (sol üst köşede)
                Positioned(
                  left: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                ),
                // Başlık metni (ortalanmış)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      "Yönetici Analizi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bilgi ikonu
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue.shade400,
                  size: 64,
                ),
                const SizedBox(height: 16),
                // Bilgi mesajı
                Text(
                  "Henüz yönetici analizi için yeterli veri yok!",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Analiz için en az bir danışman kararı vermeniz gerekmektedir.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Oyuna devam etme tavsiyesi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Oyuna devam edin ve danışmanlarınızın tavsiyelerini dinleyin!",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [],
          );
        },
      );
      return;
    }
    
    // En az bir karar verilmişse normal istatistik dialogunu göster
    final personalityAnalysis = gameState.getPersonalityAnalysis();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Stack(
            children: [
              // Geri butonu (sol üst köşede)
              Positioned(
                left: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Kısa bir gecikme ile level info popup'ı göster
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _showLevelInfoPopup(context);
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
              ),
              // Başlık metni (ortalanmış)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insights, color: Colors.purple.shade700),
                      const SizedBox(width: 10),
                      Text(
                        "Yönetici Analizi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Yönetim süresi
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 8),
                      Text(
                        "Yönetim Süresi:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimePassed(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Kişilik Analizi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: personalityAnalysis['color'].withOpacity(0.1),
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
                          color: personalityAnalysis['color'].withOpacity(0.2),
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
                              "Yönetici Özellikleri:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: (personalityAnalysis['traits'] as List<String>)
                                  .map(
                                    (trait) => Chip(
                                      label: Text(
                                        trait,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: personalityAnalysis['color'].withOpacity(0.1),
                                      side: BorderSide(
                                        color: personalityAnalysis['color'].withOpacity(0.3),
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
                
                // Danışman istatistikleri
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Danışman Tercihleri",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAdvisorUsageStats(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [],
        );
      },
    );
  }
  
  // Danışman kullanım istatistiklerini görselleştiren widget
  Widget _buildAdvisorUsageStats() {
    final advisorInfo = GameData.getAdvisorInfo();
    final totalUsage = gameState.advisorUsageCount.values.fold<int>(0, (sum, count) => sum + count);
    
    if (totalUsage == 0) {
      return const Text(
        "Henüz hiçbir danışman kullanılmadı.",
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    
    List<Widget> stats = [];
    
    gameState.advisorUsageCount.forEach((type, count) {
      if (count > 0) {
        final advisor = advisorInfo[type] ?? 
            {"name": "Bilinmeyen", "icon": Icons.person, "color": Colors.grey};
        
        double percentage = count / totalUsage * 100;
        
        stats.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(advisor["icon"], color: advisor["color"], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "${advisor["name"]}: ",
                      style: TextStyle(color: advisor["color"]),
                    ),
                    Text(
                      "$count kez (${"${percentage.toStringAsFixed(1)}%"})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(advisor["color"]),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
    
    return Column(children: stats);
  }
}