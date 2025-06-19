import 'package:flutter/material.dart';

// Olay kartları için model
class EventCard {
  final String title;
  final String description;
  final String imagePath;
  final List<Choice> choices;
  final List<String> governmentLevels; // Hangi yönetim seviyelerinde görünür: ["köy", "derebeylik"]
  final int durationInDays; // Olayın kaç gün sürdüğü

  EventCard({
    required this.title,
    required this.description,
    this.imagePath = "",
    required this.choices,
    required this.governmentLevels,
    this.durationInDays = 365, // Varsayılan 1 yıl (365 gün)
  });
}

// Seçim kartları için model
class Choice {
  final String title;
  final String description;
  final String advisorType; // "din", "mali", "askeri"
  final int halkChange;
  final int dinChange;
  final int askerChange;
  final int ekonomiChange;

  Choice({
    required this.title,
    required this.description,
    required this.advisorType,
    this.halkChange = 0,
    this.dinChange = 0,
    this.askerChange = 0,
    this.ekonomiChange = 0,
  });
}

// Tüm oyun olayları ve kartları
class GameData {
  static List<EventCard> getEvents({String? currentGovernmentLevel}) {    List<EventCard> allEvents = [
      // === KÖY SEVİYESİ OLAYLARI ===
      EventCard(
        title: "Kıtlık Tehdidi",
        description: "Büyük bir kuraklık baş gösterir ve köylüler endişeli.",
        imagePath: "city/olaylar/kuraklik.jpg",
        governmentLevels: ["köy"],
        durationInDays: 90, // 3 ay süren kıtlık krizi
        choices: [
          Choice(
            title: "Kraliyet Hazinesini Aç",
            description: "Hazineden para harcayarak gıda ithal et",
            advisorType: "mali",
            halkChange: 6,
            ekonomiChange: -8,
          ),
          Choice(
            title: "Ordunun Stokları Kullan",
            description: "Ordu depolarındaki erzakı halka dağıt",
            advisorType: "askeri",
            halkChange: 6,
            askerChange: -8,
          ),
          Choice(
            title: "Dua ve Sabır",
            description: "Tanrı'dan yardım dile ve sabretmelerini söyle",
            advisorType: "din",
            dinChange: 4,
            halkChange: -6,
          ),
        ],
      ),      EventCard(
        title: "Köy Meydanı Yenileme",
        description:
            "Köyün merkez meydanı harap durumda ve yenilenmesi gerekiyor.",
        imagePath: "city/olaylar/kopru_insasi.jpg",
        governmentLevels: ["köy"],
        durationInDays: 180, // 6 ay süren inşaat projesi
        choices: [
          Choice(
            title: "Köylülerle Birlikte İnşa Et",
            description: "Herkes elini taşın altına koyup beraber yapalım",
            advisorType: "halk",
            halkChange: -5,
            ekonomiChange: -3,
          ),
          Choice(
            title: "Usta İşçi Getir",
            description: "Şehirden usta taşçı ve marangoz kirala",
            advisorType: "mali",
            ekonomiChange: -8,
            halkChange: 5,
          ),
        ],
      ),

      EventCard(
        title: "Köy Okulunun Açılması",
        description: "Köy okulunun açılması için bütçe ayrılması isteniyor.",
        governmentLevels: ["köy"],
        durationInDays: 365, // 1 yıl süren büyük proje
        choices: [
          Choice(
            title: "Okulu Destekle",
            description: "Öğretmene maaş ver ve okul binası yaptır",
            advisorType: "halk",
            ekonomiChange: -8,
            halkChange: 9,
            dinChange: -5,
          ),
          Choice(
            title: "Sadece Din Dersi",
            description: "Okulun açılması sadece dini eğitim verilirse uygun.",
            advisorType: "din",
            dinChange: 8,
            halkChange: 4,
            ekonomiChange: -3,
          ),
          Choice(
            title: "Okul açmayı ertele ",
            description: "Okul açılmasını mali sebeplerle ertele",
            advisorType: "mali",
            halkChange: -5,
            dinChange: -3,
            ekonomiChange: 7,
          ),
        ],
      ),

      EventCard(
        title: "Yabani Hayvan Saldırısı",
        description: "Vahşi kurtlar köylülere ve sürülerine saldırıyor.",
        governmentLevels: ["köy"],
        durationInDays: 45, // 1.5 ay süren acil durum
        choices: [
          Choice(
            title: "Avcı Takımı Kur",
            description: "Deneyimli avcılar göndererek kurtları avla",
            advisorType: "askeri",
            askerChange: -5,
            halkChange: 7,
          ),
          Choice(
            title: "Koruma Duvarı",
            description: "Köy etrafına güvenlik için ahşap çit yapılması öneriliyor.",
            advisorType: "mali",
            ekonomiChange: -7,
            halkChange: 6,
            askerChange: 3,
          ),
          Choice(
            title: "Doğal Denge",
            description: "Doğanın kuralı bu, hayvanlara zarar verilmemeli.",
            advisorType: "din",
            dinChange: 4,
            halkChange: -4,
          ),
        ],
      ),

      EventCard(
        title: "Köy Çınarının Kesilmesi",
        description: "Köyün 300 yıllık çınar ağacı hasta oldu.",
        governmentLevels: ["köy"],
        choices: [
          Choice(
            title: "Ağacı Kurtar",
            description: "Usta bahçıvan getir, ağacı iyileştirmeye çalış",
            advisorType: "mali",
            ekonomiChange: -6,
            halkChange: 5,
            dinChange: 3,
          ),
          Choice(
            title: "Güvenle Kes",
            description: "Bir grup asleri ağacı kesmekle görevlendir.",
            advisorType: "askeri",
            askerChange: 5,
            halkChange: -4,
            dinChange: -3,
          ),
          Choice(
            title: "Kutsal Ayin",
            description: "Ağacı iyileştirmek için dua töreni düzenle",
            advisorType: "din",
            dinChange: 4,
            halkChange: 3,
            ekonomiChange: -2,
          ),
        ],
      ),

      EventCard(
        title: "Köv Festivali Organizasyonu",
        description: "Köylüler hasat festivali düzenlemek istiyor.",
        governmentLevels: ["köy"],
        durationInDays: 15, // 15 günlük festival hazırlığı
        choices: [
          Choice(
            title: "Büyük Festival",
            description: "Cömert bütçeyle muhteşem bir festival düzenle",
            advisorType: "halk",
            ekonomiChange: -5,
            halkChange: 5,
          ),
          Choice(
            title: "Mütevazi Şenlik",
            description: "Basit ama neşeli bir toplantı organize et",
            advisorType: "halk",
            halkChange: 4,
            ekonomiChange: -3,
          ),
          Choice(
            title: "Organizyonu ertele.",
            description: "Festival için yeterli bütçe olmadığını söyle",
            advisorType: "mali",
            halkChange: -4,
            ekonomiChange: 4,
          ),
        ],
      ),

      EventCard(
        title: "Köprü Yapım İhtiyacı",
        description: "Köyü ikiye bölen dere taştığında köprü gerekiyor.",
        governmentLevels: ["köy"],
        durationInDays: 240, // 8 ay süren inşaat projesi
        choices: [
          Choice(
            title: "Taş Köprü Yap",
            description: "Sağlam taş köprü inşa et, asırlarca dayanır",
            advisorType: "mali",
            ekonomiChange: -15,
            halkChange: 15,
            askerChange: 8,
          ),
          Choice(
            title: "Ahşap Köprü",
            description: "Hızlı ve ucuz ahşap köprü yap",
            advisorType: "mali",
            ekonomiChange: -8,
            halkChange: 10,
            dinChange: 3,
          ),
          Choice(
            title: "Köylüler Yapsın",
            description: "Köylüler kendi güçleriyle köprü inşa etsin",
            advisorType: "halk",
            halkChange: 8,
            ekonomiChange: -3,
    
          ),
        ],
      ),

      EventCard(
        title: "Gezgin Tüccarın Teklifi",
        description: "Gezgin tüccar köyde dükkân açmak istiyor.",
        governmentLevels: ["köy"],
        choices: [
          Choice(
            title: "Tüccarı Destekle",
            description: "Dükkân açmasına izin ver, vergi al",
            advisorType: "mali",
            ekonomiChange: 6,
            halkChange: 4,
            
          ),
          Choice(
            title: "Sadece Pazar Kurmasına İzin Ver",
            description: "Haftada bir pazar kurmasına izin ver",
            advisorType: "halk",
            halkChange: 2,
            ekonomiChange: 4,
            
          ),
          Choice(
            title: "Yabancıları İstemem",
            description: "Köye yabancı tüccar istemiyoruz",
            advisorType: "din",
            dinChange: 8,
            halkChange: -4,
            
          ),
        ],      ),

      // === DEREBEYLİK SEVİYESİ OLAYLARI ===
      EventCard(
        title: "Din Adamlarının İsyanı",
        description: "Din adamları toplanıp liderliğinizi sorguluyorlar.",
        imagePath: "city/olaylar/din_adamlari_isyani.jpg",
        governmentLevels: ["derebeylik"],
        durationInDays: 120, // 4 ay süren politik kriz
        choices: [
          Choice(
            title: "Tam İtaat",
            description: "Din adamlarının isteklerini kabul et",
            advisorType: "din",
            dinChange: 7,
            halkChange: -3,
            askerChange: -5,
          ),
          Choice(
            title: "Güç Gösterisi",
            description: "Ordu ile isyanı bastır",
            advisorType: "askeri",
            askerChange: 6,
            dinChange: -7,
            halkChange: -3,
          ),
          Choice(
            title: "Laik Yönetim",
            description: "Din adamlarının siyasi gücünü kırarak laik düzen kur",
            advisorType: "askeri",
            askerChange: 8,
            dinChange: -9,
            halkChange: 9,
            ekonomiChange: 5,
          ),
        ],
      ),

      EventCard(
        title: "Sınır Anlaşmazlığı",
        description: "Komşu derebeyiyle aranızda sınır anlaşmazlığı çıktı.",
        governmentLevels: ["derebeylik"],
        choices: [
          Choice(
            title: "Hakim Çağır",
            description: "Tarafsız bir hakim getirerek meseleyi mahkemede çöz",
            advisorType: "diplomatik",
            halkChange: 8,
            ekonomiChange: -5,
            dinChange: 8,
          ),
          Choice(
            title: "Güç Gösterisi",
            description: "Askerlerini sınıra gönder, gücünü göster",
            advisorType: "askeri",
            askerChange: 8,
            halkChange: 5,
            ekonomiChange: -5,
          ),
          Choice(
            title: "Toprak Takas Et",
            description: "Karşılıklı değişim yaparak sorunu çöz",
            advisorType: "diplomatik",
            halkChange: 6,
            ekonomiChange: 5,
            dinChange: 3,
          ),
        ],
      ),

      // === BARONLUK SEVİYESİ OLAYLARI ===
      EventCard(
        title: "Kristal Madeni Keşfi",
        description: "Dağlarda değerli kristal madeni bulundu.",
        governmentLevels: ["baronluk"],
        choices: [
          Choice(
            title: "Büyük Yatırım Yap",
            description: "Hazineyi açıp profesyonel madenciler getir",
            advisorType: "mali",
            ekonomiChange: -15,
            halkChange: 10,
            askerChange: 5,
          ),
          Choice(
            title: "Kristalleri Kutsal İlan Et",
            description: "Tapınağın malı sayıp din adamlarına bırak",
            advisorType: "din",
            dinChange: 9,
            ekonomiChange: 5,
            halkChange: 8,
          ),
          Choice(
            title: "Kademeli Açılış",
            description: "Önce küçük çaplı çıkarıma başla",
            advisorType: "askeri",
            askerChange: 8,
            ekonomiChange: 8,
            halkChange: 5,
          ),
        ],      ),

      // === KRALLIK SEVİYESİ OLAYLARI ===
      EventCard(
        title: "Kraliyet Evliliği Teklifi",
        description: "Güçlü komşu krallığın kralı kızını seninle evlendirmek istiyor.",
        imagePath: "city/olaylar/kraliyet_evlilik.jpeg",
        governmentLevels: ["krallık"],
        choices: [
          Choice(
            title: "Evliliği Kabul Et",
            description: "Prensesin tüm şartlarını kabul ederek evlen",
            advisorType: "diplomatik",
            ekonomiChange: 20,
            askerChange: 15,
            dinChange: -5,
            halkChange: 10,
          ),
          Choice(
            title: "Şartları Müzakere Et",
            description: "Bazı şartları değiştirerek anlaşma yap",
            advisorType: "diplomatik",
            ekonomiChange: 10,
            askerChange: 8,
            halkChange: 5,
            dinChange: 3,
          ),
          Choice(
            title: "Kibar Reddet",
            description: "Diplomatik bir şekilde teklifi geri çevir",
            advisorType: "din",
            dinChange: 8,
            halkChange: -3,
            askerChange: -5,
          ),
        ],
      ),

      // === İMPARATORLUK SEVİYESİ OLAYLARI ===
      EventCard(
        title: "Antik İmparatorluk Kalıntıları",
        description: "Arkeologlar antik imparatorluğun kalıntılarını keşfetti.",
        governmentLevels: ["imparatorluk"],
        choices: [
          Choice(
            title: "Kalıntıları Tam Kontrol Et",
            description: "Orduyla koruma altına al, tüm hazineleri çıkar",
            advisorType: "askeri",
            askerChange: 20,
            ekonomiChange: 25,
            halkChange: 10,
            dinChange: 5,
          ),
          Choice(
            title: "Uluslararası Çalışma",
            description: "Diğer imparatorluklarla ortak araştırma yap",
            advisorType: "diplomatik",
            ekonomiChange: 15,
            halkChange: 15,
            dinChange: 10,
            askerChange: -10,
          ),
          Choice(
            title: "Kutsal Sit İlan Et",
            description: "Kalıntıları kutsal alan ilan edip koruma altına al",
            advisorType: "din",
            dinChange: 20,
            halkChange: 12,
            ekonomiChange: 10,
            askerChange: 8,
          ),
        ],
      ),

      // === ORTAK OLAYLAR (ÇOKLU SEVİYELER) ===
      EventCard(
        title: "Ticaret Krizi",
        description: "Ana ticaret yolları kesildi ve ekonomi sarsıldı.",
        governmentLevels: ["köy", "derebeylik"],
        choices: [
          Choice(
            title: "Yeni Yollar",
            description: "Askeri eskort ile yeni ticaret yolları aç",
            advisorType: "askeri",
            askerChange: -9,
            ekonomiChange: 8,
            halkChange: 5,
          ),
          Choice(
            title: "Vergi İndirimi",
            description: "Tüccarları desteklemek için vergileri düşür",
            advisorType: "mali",
            ekonomiChange: 9,
            halkChange: 9,
          ),
          Choice(
            title: "Mucizevi Çözüm",
            description: "Tanrı'nın yardımıyla çözüm bulunacağını vaaz et",
            advisorType: "din",
            dinChange: 9,
            halkChange: -9,
            ekonomiChange: 5,
          ),
        ],
      ),
    ];

    // === ZİNCİR BAŞLATICI OLAYLAR ===
    allEvents.addAll([
      EventCard(
        title: "Gizemli Hastalık",
        description: "Şehirde gizemli bir hastalık yayılmaya başladı.",
        governmentLevels: ["köy", "derebeylik"],
        choices: [
          Choice(
            title: "Kutsal Koruma",
            description: "Din adamlarına kutsal törenler düzenlettir",
            advisorType: "din",
            dinChange: 8,
            halkChange: 5,
            ekonomiChange: -5,
          ),
          Choice(
            title: "Hekim Çağır",
            description: "En iyi hekimleri getirip hastalığı araştırt",
            advisorType: "mali",
            ekonomiChange: -8,
            halkChange: 8,
            dinChange: -3,
          ),
          Choice(
            title: "Karantina Uygula",
            description: "Hasta bölgeleri tamamen izole et",
            advisorType: "askeri",
            askerChange: 8,
            halkChange: -5,
            ekonomiChange: -3,
          ),
        ],
      ),

      EventCard(
        title: "Ejder Efsanesi",
        description: "Dağlarda büyük bir ejderin uyandığı söyleniyor.",
        governmentLevels: ["derebeylik"],
        choices: [
          Choice(
            title: "Ejder Avcısı Gönder",
            description: "En cesur şövalyeni ejderi aramaya gönder",
            advisorType: "askeri",
            askerChange: -5,
            halkChange: 8,
            dinChange: 3,
          ),
          Choice(
            title: "Ejdere Haraç",
            description: "Altın gönderip ejderin gazabından kaçın",
            advisorType: "mali",
            ekonomiChange: -8,
            halkChange: -3,
            dinChange: -5,
          ),
          Choice(
            title: "Efsane Diyerek Geç",
            description: "Bu sadece masaldır, gerçek değil",
            advisorType: "halk",
            halkChange: -8,
            dinChange: 5,
            askerChange: 3,
          ),
        ],
      ),

      EventCard(
        title: "Gizli Hazine",
        description: "Eski çiftçi gizli hazine haritası getirdi.",
        governmentLevels: ["köy"],
        choices: [
          Choice(
            title: "Dikkatli Araştır",
            description: "Uzmanlar göndererek hazineyi araştır",
            advisorType: "mali",
            ekonomiChange: -5,
            halkChange: 3,
            askerChange: 3,
          ),
          Choice(
            title: "Halka Dağıt",
            description: "Hazine bulunursa hemen halka dağıt",
            advisorType: "halk",
            halkChange: 8,
            dinChange: 5,
            ekonomiChange: -3,
          ),
          Choice(
            title: "Sahte Harita",
            description: "Bu kesinlikle sahte, zaman kaybetme",
            advisorType: "askeri",
            askerChange: 3,
            halkChange: -5,
            dinChange: 3,
          ),
        ],
      ),
    ]);

    // Eğer yönetim seviyesi belirtilmişse, olayları filtrele
    if (currentGovernmentLevel != null) {
      return allEvents
          .where(
            (event) => event.governmentLevels.contains(currentGovernmentLevel),
          )
          .toList();
    }

    // Eğer seviye belirtilmemişse tüm olayları döndür
    return allEvents;
  }

  // Danışman bilgileri
  static Map<String, Map<String, dynamic>> getAdvisorInfo() {
    return {
      "din": {
        "name": "Din Danışmanı",
        "icon": Icons.brightness_2,
        "color": Colors.green,
        "description": "Kutsal kitapların bilgini, halkın ruhsal lideri",
        "speciality": "Manevi güç ve din adamlarının desteği",
      },
      "mali": {
        "name": "Mali Danışman",
        "icon": Icons.monetization_on,
        "color": Colors.orange,
        "description": "Hazine ve ticaret uzmanı, ekonominin ustası",
        "speciality": "Altın yönetimi ve ticaret stratejileri",
      },
      "askeri": {
        "name": "Askeri Danışman",
        "icon": Icons.security,
        "color": Colors.red,
        "description": "Savaş sanatının ustası, orduların komutanı",
        "speciality": "Güvenlik ve askeri operasyonlar",
      },
      "diplomatik": {
        "name": "Diplomatik Danışman",
        "icon": Icons.handshake,
        "color": Colors.blue,
        "description": "Dış ilişkiler uzmanı, barış ve anlaşmaların mimarı",
        "speciality": "Diplomasi ve komşu ülkelerle ilişkiler",
      },
      "halk": {
        "name": "Halk Danışmanı",
        "icon": Icons.groups,
        "color": Colors.purple,
        "description": "Halkın sesi, sokaklardaki durumun gözlemcisi",
        "speciality": "Halkın nabzını tutma ve sosyal politikalar",
      },
    };
  }

  // Rastgele danışman tavsiyesi için
  static List<String> getRandomAdvice(String advisorType) {
    Map<String, List<String>> adviceMap = {
      "din": [
        "Tanrı'nın lütfu ile doğru yolu bulacaksınız, Majeste.",
        "Halkın ruhunu yükseltmek, bedenleri beslemekten daha önemlidir.",
        "Kutsal kitaplarda bu duruma benzer bir olay var...",
        "Din adamlarının desteği sizin en büyük gücünüzdür.",
        "Manevi arınma ile tüm sorunlar çözülebilir.",
        "Tanrı'dan korkanı hiçbir güç yenemez.",
        "Dua, en güçlü silahınızdır, Majeste.",
        "Kutsal görevlerinizi unutmayın.",
        "Halkın ruhsal ihtiyaçları maddi ihtiyaçlarından önemlidir.",
        "İman, dağları yerinden oynatır.",
      ],
      "mali": [
        "Altın her kapıyı açar, Majeste. Hazineyi akıllıca kullanın.",
        "Bu durumda yatırım yapmak, gelecekte büyük kazanç getirir.",
        "Tüccarlarla iyi ilişkiler kurmalısınız.",
        "Ekonomik kriz zamanında hızlı hareket etmek gerekir.",
        "Para, politikanın en güçlü silahıdır.",
        "Vergiler halkı ezer ama hazine doldurmak şarttır.",
        "Ticaret yolları açık tutmak her şeyden önemlidir.",
        "Bu karar pahalıya patlayabilir, Majeste.",
        "Altın olmadan hiçbir plan işe yaramaz.",
        "Tüccarlar mutlu olursa, hazine de mutlu olur.",
      ],
      "askeri": [
        "Güç gösterisi düşmanları sindirmenin en etkili yoludur.",
        "Ordu disiplini ve sıkı kontrol gerektirir, Majeste.",
        "Bu durumda hızlı ve kararlı davranmalısınız.",
        "Düşmanlarınız zayıflık belirtisi göstermeyi bekliyor.",
        "İyi bir savunma, en iyi saldırıdır.",
        "Askerlerin morali yüksek olmalı, Majeste.",
        "Savaşta tereddüt eden kaybeder!",
        "Demir yumruk gerektiğinde kullanılmalıdır.",
        "Kılıç konuştuğunda diplomasi susmalıdır.",
        "Güçlü ol ki barışta bile saygı gör.",
      ],
      "diplomatik": [
        "Barışçıl çözümler her zaman daha uzun sürer ama kalıcıdır.",
        "Komşularınızla iyi ilişkiler kurmanız şarttır.",
        "Bu krizde sabırlı olmak ve müzakere etmek gerekir.",
        "Düşmanınızı anlamak, onu yenmekten daha önemlidir.",
        "Güçlü ittifaklar, büyük orduları bile geçer.",
        "Diplomaside sabır ve zeka en önemli silahlarınızdır.",
        "Bir anlaşma iki tarafı da memnun etmelidir.",
        "Söz gümüşse, sükût altındır, Majeste.",
        "Dostluk para ile satın alınamaz ama diplomasi ile kazanılır.",
        "Barış için savaşa hazır olmalısınız.",
      ],
      "halk": [
        "Halkın sesi Tanrı'nın sesidir, Majeste.",
        "Köylerde dolaşıp gerçek durumu görmek gerekir.",
        "Halkın memnuniyeti krallığın temel taşıdır.",
        "Basit insanlar en dürüst tavsiyeleri verir.",
        "Sarayda duyduklarınız, sokaklardaki gerçeklerden farklıdır.",
        "Halk aç iken saray tok olamaz.",
        "Çiftçiler mutlu olursa, herkes tok olur.",
        "Halkın derdi sizin derdiniz olmalı, Majeste.",
        "Tahtın altında toprak, toprakta halk vardır.",
        "Halktan kopan kral, tahtından da olur.",
      ],
    };

    List<String> advice =
        adviceMap[advisorType] ?? ["Akıllıca hareket etmelisiniz, Majeste."];
    advice.shuffle();
    return advice;
  }

  // Zincirleme olaylar için flag'leri kontrol eden fonksiyon
  static List<EventCard> getChainEvents(Map<String, dynamic> eventFlags) {
    List<EventCard> chainEvents = [];

    // Gizemli Hastalık zinciri
    if (eventFlags['plague_start'] == true &&
        eventFlags['plague_choice'] != null) {
      if (eventFlags['plague_choice'] == 'koruma' &&
          eventFlags['plague_2_shown'] != true) {
        chainEvents.add(_getPlagueEvent2());
      } else if (eventFlags['plague_choice'] == 'tedavi' &&
          eventFlags['plague_3_shown'] != true) {
        chainEvents.add(_getPlagueEvent3());
      } else if (eventFlags['plague_choice'] == 'karantina' &&
          eventFlags['plague_4_shown'] != true) {
        chainEvents.add(_getPlagueEvent4());
      }
    }

    // Ejder Efsanesi zinciri
    if (eventFlags['dragon_start'] == true &&
        eventFlags['dragon_choice'] != null) {
      if (eventFlags['dragon_choice'] == 'avci' &&
          eventFlags['dragon_2_shown'] != true) {
        chainEvents.add(_getDragonEvent2());
      } else if (eventFlags['dragon_choice'] == 'harac' &&
          eventFlags['dragon_3_shown'] != true) {
        chainEvents.add(_getDragonEvent3());
      }
    }

    // Gizli Hazine zinciri
    if (eventFlags['treasure_start'] == true &&
        eventFlags['treasure_choice'] != null) {
      if (eventFlags['treasure_choice'] == 'araştır' &&
          eventFlags['treasure_2_shown'] != true) {
        chainEvents.add(_getTreasureEvent2());
      } else if (eventFlags['treasure_choice'] == 'dağıt' &&
          eventFlags['treasure_3_shown'] != true) {
        chainEvents.add(_getTreasureEvent3());
      }
    }

    return chainEvents;
  }

  // Event seçildikten sonra flag'leri ayarlayan fonksiyon
  static void setEventFlags(
    String eventTitle,
    String choiceTitle,
    Map<String, dynamic> eventFlags,
    Set<String> completedChainStories,
  ) {
    // Gizemli Hastalık zinciri başlatma
    if (eventTitle == "Gizemli Hastalık") {
      eventFlags['plague_start'] = true;
      if (choiceTitle == "Kutsal Koruma") {
        eventFlags['plague_choice'] = 'koruma';
      } else if (choiceTitle == "Hekim Çağır") {
        eventFlags['plague_choice'] = 'tedavi';
      } else if (choiceTitle == "Karantina Uygula") {
        eventFlags['plague_choice'] = 'karantina';
      }
    }

    // Ejder Efsanesi zinciri
    if (eventTitle == "Ejder Efsanesi") {
      eventFlags['dragon_start'] = true;
      if (choiceTitle == "Ejder Avcısı Gönder") {
        eventFlags['dragon_choice'] = 'avci';
      } else if (choiceTitle == "Ejdere Haraç") {
        eventFlags['dragon_choice'] = 'harac';
      }
    }

    // Gizli Hazine zinciri
    if (eventTitle == "Gizli Hazine") {
      eventFlags['treasure_start'] = true;
      if (choiceTitle == "Dikkatli Araştır") {
        eventFlags['treasure_choice'] = 'araştır';
      } else if (choiceTitle == "Halka Dağıt") {
        eventFlags['treasure_choice'] = 'dağıt';
      }
    }

    // Zincirleme olayların gösterildiğini işaretle ve hikayeyi tamamla
    if (eventTitle == "Hastalığın Yayılması") {
      eventFlags['plague_2_shown'] = true;
      completedChainStories.add('plague');
    } else if (eventTitle == "Hekimin Keşfi") {
      eventFlags['plague_3_shown'] = true;
      completedChainStories.add('plague');
    } else if (eventTitle == "Karantina Sonuçları") {
      eventFlags['plague_4_shown'] = true;
      completedChainStories.add('plague');
    } else if (eventTitle == "Ejder Avcısının Dönüşü") {
      eventFlags['dragon_2_shown'] = true;
      completedChainStories.add('dragon');
    } else if (eventTitle == "Ejderin Gazabı") {
      eventFlags['dragon_3_shown'] = true;
      completedChainStories.add('dragon');
    } else if (eventTitle == "Hazine Araştırması") {
      eventFlags['treasure_2_shown'] = true;
      completedChainStories.add('treasure');
    } else if (eventTitle == "Halkın Minneti") {
      eventFlags['treasure_3_shown'] = true;
      completedChainStories.add('treasure');
    }
  }

  // Zincirleme olay kartları
  static EventCard _getPlagueEvent2() {
    return EventCard(
      title: "Hastalığın Yayılması",
      description: "Hastalık yayılmaya devam ediyor ve durum kontrolden çıkıyor.",
      governmentLevels: [
        "köy",
        "derebeylik",
      ], // Zincirleme olaylar her seviyede görünür
      choices: [
        Choice(
          title: "Tapınakları Kapat",
          description: "Geçici olarak toplu ibadetleri yasakla",
          advisorType: "askeri",
          dinChange: -20,
          halkChange: -10,
          askerChange: 8,
        ),
        Choice(
          title: "Daha Çok Dua",
          description: "Daha büyük törenler düzenleyerek Tanrı'dan af dile",
          advisorType: "din",
          dinChange: 8,
          halkChange: -15,
          ekonomiChange: -10,
        ),
        Choice(
          title: "Hekim İthal Et",
          description: "Yabancı ülkelerden deneyimli hekimler getir",
          advisorType: "mali",
          ekonomiChange: -25,
          halkChange: 9,
          dinChange: -5,
        ),
      ],
    );
  }

  static EventCard _getPlagueEvent3() {
    return EventCard(
      title: "Hekimin Keşfi",
      description: "Hekim hastalığın su kaynaklarından bulaştığını keşfetti.",
      governmentLevels: [
        "köy",
        "derebeylik",
      ], // Zincirleme olaylar her seviyede görünür
      choices: [
        Choice(
          title: "Su Sistemini Yenile",
          description: "Tüm şehrin su sistemini baştan inşa et",
          advisorType: "mali",
          ekonomiChange: -30,
          halkChange: 9,
          askerChange: 8,
        ),
        Choice(
          title: "Kuyuları Temizle",
          description: "Mevcut kuyuları temizleyip dezenfekte et",
          advisorType: "askeri",
          askerChange: -15,
          halkChange: 9,
          ekonomiChange: -10,
        ),
        Choice(
          title: "Su İthal Et",
          description: "Temiz bölgelerden su getirtmeye odaklan",
          advisorType: "diplomatik",
          ekonomiChange: -20,
          halkChange: 8,
          dinChange: 8,
        ),
      ],
    );
  }

  static EventCard _getPlagueEvent4() {
    return EventCard(
      title: "Karantina Sonuçları",
      description: "Karantina hastalığı durdurdu ama ekonomiyi çok etkiledi.",
      governmentLevels: [
        "köy",
        "derebeylik",
      ], // Zincirleme olaylar her seviyede görünür
      choices: [
        Choice(
          title: "Karantinayı Sürdür",
          description: "Hastalık tamamen bitene kadar karantina devam etsin",
          advisorType: "askeri",
          halkChange: -20,
          askerChange: 8,
          ekonomiChange: -25,
        ),
        Choice(
          title: "Kademeli Açılış",
          description: "Güvenli bölgeleri yavaş yavaş aç",
          advisorType: "diplomatik",
          halkChange: 8,
          ekonomiChange: 8,
          dinChange: 5,
        ),
        Choice(
          title: "Acil Yardım Dağıt",
          description: "Karantinada olan halka yiyecek ve para yardımı yap",
          advisorType: "mali",
          ekonomiChange: -20,
          halkChange: 9,
          dinChange: 8,
        ),
      ],
    );
  }

  static EventCard _getDragonEvent2() {
    return EventCard(
      title: "Ejder Avcısının Dönüşü",
      description: "Şövalye ejderi buldu ama yaşlı ve hasta olduğunu keşfetti.",
      governmentLevels: [
        "köy",
        "derebeylik",
      ], // Zincirleme olaylar her seviyede görünür
      choices: [
        Choice(
          title: "Hazineyi Al",
          description:
              "Ejder yokken hazineyi çalmak için büyük bir ekip gönder",
          advisorType: "askeri",
          ekonomiChange: 9,
          askerChange: -10,
          dinChange: -15,
        ),
        Choice(
          title: "Ejderi İyileştir",
          description: "Hasta ejdere yardım ederek dostluğunu kazan",
          advisorType: "din",
          dinChange: 9,
          halkChange: 8,
          ekonomiChange: 9,
        ),
        Choice(
          title: "Barış Teklifi",
          description: "Ejderle barış yapıp toprakları paylaş",
          advisorType: "diplomatik",
          halkChange: 9,
          dinChange: 8,
          ekonomiChange: 8,
        ),
      ],
    );
  }

  static EventCard _getDragonEvent3() {
    return EventCard(
      title: "Ejderin Gazabı",
      description: "Ejder haraçlardan memnun olmadı ve köyleri yakmaya başladı.",
      governmentLevels: [
        "köy",
        "derebeylik",
      ], // Zincirleme olaylar her seviyede görünür
      choices: [
        Choice(
          title: "Büyük Ordu Gönder",
          description: "Tüm askeri gücünü ejdere karşı kullan",
          advisorType: "askeri",
          askerChange: -25,
          halkChange: 9,
          ekonomiChange: -15,
        ),
        Choice(
          title: "Daha Fazla Haraç",
          description: "Ejderin istediği kadar altın ver",
          advisorType: "mali",
          ekonomiChange: -40,
          halkChange: -20,
          dinChange: -10,
        ),
        Choice(
          title: "Büyücü İste",
          description: "Ejderle konuşabilecek bir büyücü bul",
          advisorType: "din",
          dinChange: -15,
          ekonomiChange: -10,
          halkChange: 8,
        ),
      ],
    );
  }

  static EventCard _getTreasureEvent2() {
    return EventCard(
      title: "Hazine Araştırması",
      description: "Hazinede altın, mücevher ve gizemli büyülü eşyalar bulundu.",
      governmentLevels: ["köy", "derebeylik"],
      choices: [
        Choice(
          title: "Büyülü Eşyaları İncele",
          description: "Büyücülük eşyalarını araştırmak için akademi kur",
          advisorType: "mali",
          ekonomiChange: -15,
          dinChange: -20,
          halkChange: 8,
        ),
        Choice(
          title: "Eşyaları Yak",
          description: "Büyülü eşyaları imha et, sadece altını al",
          advisorType: "din",
          dinChange: 9,
          ekonomiChange: 9,
          halkChange: -5,
        ),
        Choice(
          title: "Gizli Tut",
          description: "Eşyaları gizli bir yerde sakla, kimseye söyleme",
          advisorType: "askeri",
          askerChange: 8,
          ekonomiChange: 8,
          dinChange: -5,
        ),
      ],
    );
  }

  static EventCard _getTreasureEvent3() {
    return EventCard(
      title: "Halkın Minneti",
      description: "Hazineyi halka dağıttın ve büyük sevgi kazandın.",
      governmentLevels: ["köy", "derebeylik"],
      choices: [
        Choice(
          title: "Yeni Vergiler Koy",
          description: "Zenginliği sürdürmek için vergileri artır",
          advisorType: "mali",
          ekonomiChange: 9,
          halkChange: -15,
          dinChange: -5,
        ),
        Choice(
          title: "Komşularla Ticaret",
          description: "Zenginlik imajını kullanarak ticaret anlaşmaları yap",
          advisorType: "diplomatik",
          ekonomiChange: 9,
          halkChange: 8,
          askerChange: 5,
        ),
        Choice(
          title: "Sadelik Vaaz Et",
          description: "Halka sade yaşamayı öğütleyerek beklentileri düşür",
          advisorType: "din",
          dinChange: 8,
          halkChange: 5,
          ekonomiChange: 8,
        ),
      ],
    );
  }

  // Zincir başlatıcı olayları getiren metod
  static List<EventCard> getChainStarterEvents({
    String? currentGovernmentLevel,
  }) {
    List<EventCard> chainStarters = [
      EventCard(
        title: "Gizemli Hastalık",
        description: "Şehirde gizemli ve bilinmeyen bir hastalık yayılmaya başladı.",
        governmentLevels: ["köy", "derebeylik"],
        choices: [
          Choice(
            title: "Kutsal Koruma",
            description: "Din adamlarına kutsal törenler düzenlettir",
            advisorType: "din",
            dinChange: 8,
            halkChange: 5,
            ekonomiChange: -5,
          ),
          Choice(
            title: "Hekim Çağır",
            description: "En iyi hekimleri getirip hastalığı araştırt",
            advisorType: "mali",
            ekonomiChange: -8,
            halkChange: 8,
            dinChange: -3,
          ),
          Choice(
            title: "Karantina Uygula",
            description: "Hasta bölgeleri tamamen izole et",
            advisorType: "askeri",
            askerChange: 8,
            halkChange: -5,
            ekonomiChange: -3,
          ),
        ],
      ),

      EventCard(
        title: "Ejder Efsanesi",
        description: "Dağlarda büyük bir ejderin uyandığı söyleniyor.",
        governmentLevels: ["derebeylik"],
        choices: [
          Choice(
            title: "Ejder Avcısı Gönder",
            description: "En cesur şövalyeni ejderi aramaya gönder",
            advisorType: "askeri",
            askerChange: -5,
            halkChange: 8,
            dinChange: 3,
          ),
          Choice(
            title: "Ejdere Haraç",
            description: "Altın gönderip ejderin gazabından kaçın",
            advisorType: "mali",
            ekonomiChange: -8,
            halkChange: -3,
            dinChange: -5,
          ),
          Choice(
            title: "Efsane Diyerek Geç",
            description: "Bu sadece masaldır, gerçek değil",
            advisorType: "halk",
            halkChange: -8,
            dinChange: 5,
            askerChange: 3,
          ),
        ],
      ),

      EventCard(
        title: "Gizli Hazine",
        description: "Eski çiftçi gizli hazine haritası getirdi.",
        governmentLevels: ["köy"],
        choices: [
          Choice(
            title: "Dikkatli Araştır",
            description: "Uzmanlar göndererek hazineyi araştır",
            advisorType: "mali",
            ekonomiChange: -5,
            halkChange: 3,
            askerChange: 3,
          ),
          Choice(
            title: "Halka Dağıt",
            description: "Hazine bulunursa hemen halka dağıt",
            advisorType: "halk",
            halkChange: 8,
            dinChange: 5,
            ekonomiChange: -3,
          ),
          Choice(
            title: "Sahte Harita",
            description: "Bu kesinlikle sahte, zaman kaybetme",
            advisorType: "askeri",
            askerChange: 3,
            halkChange: -5,
            dinChange: 3,
          ),
        ],
      ),
    ];

    // Eğer yönetim seviyesi belirtilmişse, olayları filtrele
    if (currentGovernmentLevel != null) {
      return chainStarters
          .where(
            (event) => event.governmentLevels.contains(currentGovernmentLevel),
          )
          .toList();
    }

    return chainStarters;
  }

  // Tüm olayları (normal + zincir başlatıcı) getiren metod
  static List<EventCard> getAllEventsForLevel(String governmentLevel) {
    List<EventCard> allEvents = [];

    // Normal olayları ekle
    allEvents.addAll(getEvents(currentGovernmentLevel: governmentLevel));

    // Zincir başlatıcı olayları ekle
    allEvents.addAll(
      getChainStarterEvents(currentGovernmentLevel: governmentLevel),
    );

    return allEvents;
  }
}
