import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const IndexocialApp());

// ============================================================================
// DESIGN TOKENS
// ============================================================================
class CivicPalette {
  static const Color signalYellow = Color(0xFFFFE600);
  static const Color yellowLight = Color(0xFFFFF176);
  static const Color yellowSubtle = Color(0xFF282508);

  // Dark Theme
  static const Color darkBg = Color(0xFF121418);
  static const Color darkCard = Color(0xFF1A1D24);
  static const Color darkCardBorder = Color(0xFF282C36);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextMuted = Color(0xFF9EA3B0);

  // Light Theme
  static const Color lightBg = Color(0xFFF0F2F6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFD1D5DB);
  static const Color lightTextPrimary = Color(0xFF0A0C10);
  static const Color lightTextMuted = Color(0xFF374151);

  // Status
  static const Color vermilion = Color(0xFFFF3B30);
}

// ============================================================================
// CUSTOM GLOBE WIREFRAME ICON
// ============================================================================
class GlobeWireframeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const GlobeWireframeIcon({
    super.key,
    this.size = 28.0,
    this.color = CivicPalette.signalYellow,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlobeWireframePainter(color: color)),
    );
  }
}

class _GlobeWireframePainter extends CustomPainter {
  final Color color;
  _GlobeWireframePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawCircle(center, radius, outlinePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 1.1, height: radius * 2), gridPaint);
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 2, height: radius), gridPaint);
  }

  @override
  bool shouldRepaint(covariant _GlobeWireframePainter oldDelegate) => oldDelegate.color != color;
}

// ============================================================================
// ROOT APP (DÉTECTION AUTOMATIQUE DU THÈME DU TÉLÉPHONE PAR DÉFAUT)
// ============================================================================
class IndexocialApp extends StatefulWidget {
  const IndexocialApp({super.key});

  @override
  State<IndexocialApp> createState() => _IndexocialAppState();
}

class _IndexocialAppState extends State<IndexocialApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system && mounted) {
      setState(() {});
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('indexocial_theme_mode');
    if (!mounted) return;
    setState(() {
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.dark) {
      await prefs.setString('indexocial_theme_mode', 'dark');
    } else if (mode == ThemeMode.light) {
      await prefs.setString('indexocial_theme_mode', 'light');
    } else {
      await prefs.remove('indexocial_theme_mode');
    }
  }

  bool get _effectiveIsDark {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  ThemeData _buildTheme(bool dark) {
    final bg = dark ? CivicPalette.darkBg : CivicPalette.lightBg;
    final surface = dark ? CivicPalette.darkCard : CivicPalette.lightCard;
    final text = dark ? CivicPalette.darkTextPrimary : CivicPalette.lightTextPrimary;
    final border = dark ? CivicPalette.darkCardBorder : CivicPalette.lightCardBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      primaryColor: CivicPalette.signalYellow,
      fontFamily: 'sans-serif-condensed',
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: CivicPalette.signalYellow,
        onPrimary: CivicPalette.darkBg,
        secondary: Colors.white,
        onSecondary: CivicPalette.darkBg,
        error: CivicPalette.vermilion,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: text, fontSize: 14, fontFamily: 'Roboto'),
        titleMedium: TextStyle(color: text, fontSize: 14, fontFamily: 'Roboto'),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: CivicPalette.signalYellow, width: 2.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _effectiveIsDark;

    return MaterialApp(
      title: 'INDEXOCIAL // QC',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      home: CivicLedgerScreen(
        isDark: isDark,
        themeMode: _themeMode,
        onToggleDark: () {
          _setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
        },
        onUseSystemTheme: () {
          _setThemeMode(ThemeMode.system);
        },
      ),
    );
  }
}

// ============================================================================
// DATA MODELS & CONSTANTS
// ============================================================================
enum NavTab { directory, wizard, saved, notes, docs, more }

enum DisplayMode { ledger, grid }

class EcccWeatherAlert {
  final String alertNameFr;
  final String alertType;
  final String riskColourFr;
  final String impactFr;
  final String featureNameFr;
  final String alertTextFr;
  final String eventEndDatetime;

  const EcccWeatherAlert({
    required this.alertNameFr,
    required this.alertType,
    required this.riskColourFr,
    required this.impactFr,
    required this.featureNameFr,
    required this.alertTextFr,
    required this.eventEndDatetime,
  });

  factory EcccWeatherAlert.fromProperties(Map props) {
    return EcccWeatherAlert(
      alertNameFr: (props['alert_name_fr'] ?? '').toString().trim(),
      alertType: (props['alert_type'] ?? '').toString().trim().toLowerCase(),
      riskColourFr: (props['risk_colour_fr'] ?? '').toString().trim().toLowerCase(),
      impactFr: (props['impact_fr'] ?? '').toString().trim(),
      featureNameFr: (props['feature_name_fr'] ?? '').toString().trim(),
      alertTextFr: (props['alert_text_fr'] ?? '').toString().trim(),
      eventEndDatetime: (props['event_end_datetime'] ?? '').toString().trim(),
    );
  }

  bool get isSevereAlert {
    if (alertType == 'warning') return true;
    if (riskColourFr == 'orange' || riskColourFr == 'rouge') return true;

    final lowerName = alertNameFr.toLowerCase();
    const severeKeywords = [
      'froid extrême',
      'refroidissement éolien',
      'tempête',
      'blizzard',
      'verglas',
      'pluie verglaçante',
      'bourrasques de neige',
      'onde de tempête',
      'tornade',
      'orage violent',
      'chaleur accablante',
    ];
    return severeKeywords.any((kw) => lowerName.contains(kw));
  }
}

class SocialResource {
  final String id;
  final String nameFr;
  final String nameEn;
  final List<String> categoryIds;
  final String region;
  final String phone;
  final String website;
  final String address;
  final String descFr;
  final String descEn;
  final List<String> tags;
  final bool isCustom;

  const SocialResource({
    required this.id,
    required this.nameFr,
    required this.nameEn,
    required this.categoryIds,
    required this.region,
    required this.phone,
    required this.website,
    required this.address,
    required this.descFr,
    required this.descEn,
    required this.tags,
    this.isCustom = false,
  });

  String get categoryId => categoryIds.isNotEmpty ? categoryIds.first : 'ALL';
  String name(bool fr) => fr ? nameFr : nameEn;
  String desc(bool fr) => fr ? descFr : descEn;

  String toVCard(bool fr) {
    final cleanName = name(fr).replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final cleanAddress = address.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final cleanWeb = website.trim();

    return [
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:;$cleanName;;;',
      'FN:$cleanName',
      'ORG:$cleanName',
      'TEL;TYPE=CELL,VOICE:$cleanPhone',
      if (cleanAddress.isNotEmpty) 'ADR;TYPE=WORK:;;$cleanAddress;;;;',
      if (cleanWeb.isNotEmpty) 'URL:$cleanWeb',
      'END:VCARD',
    ].join('\r\n');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameFr': nameFr,
    'nameEn': nameEn,
    'categoryIds': categoryIds,
    'categoryId': categoryId,
    'region': region,
    'phone': phone,
    'website': website,
    'address': address,
    'descFr': descFr,
    'descEn': descEn,
    'tags': tags,
    'isCustom': isCustom,
  };

  factory SocialResource.fromJson(Map<String, dynamic> json) => SocialResource(
    id: json['id'] ?? '',
    nameFr: json['nameFr'] ?? '',
    nameEn: json['nameEn'] ?? '',
    categoryIds: json['categoryIds'] != null
        ? List<String>.from(json['categoryIds'])
        : (json['categoryId'] != null ? [json['categoryId'].toString()] : ['ALL']),
    region: json['region'] ?? 'PROVINCIAL (TOUT LE QUÉBEC)',
    phone: json['phone'] ?? '',
    website: json['website'] ?? '',
    address: json['address'] ?? 'Québec, QC',
    descFr: json['descFr'] ?? '',
    descEn: json['descEn'] ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    isCustom: json['isCustom'] ?? false,
  );
}

class PersonalNote {
  final String id;
  final String title;
  final String content;
  final String dateStr;
  final String? audioPath;

  const PersonalNote({
    required this.id,
    required this.title,
    required this.content,
    required this.dateStr,
    this.audioPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'dateStr': dateStr,
    'audioPath': audioPath,
  };

  factory PersonalNote.fromJson(Map<String, dynamic> json) => PersonalNote(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    dateStr: json['dateStr'] ?? '',
    audioPath: json['audioPath'],
  );
}

class CategoryItem {
  final String id;
  final String labelFr;
  final String labelEn;
  final IconData icon;

  const CategoryItem(this.id, this.labelFr, this.labelEn, this.icon);
  String label(bool fr) => fr ? labelFr : labelEn;
}

const List<CategoryItem> kCategories = [
  CategoryItem('ALL', 'TOUTES LES CATÉGORIES', 'ALL CATEGORIES', Icons.grid_view_rounded),
  CategoryItem('CRISIS', 'CRISE & SUICIDE', 'CRISIS & SUICIDE', Icons.support_agent_rounded),
  CategoryItem('HEALTH', 'SANTÉ MENTALE & ÉCOUTE', 'MENTAL HEALTH', Icons.psychology_rounded),
  CategoryItem('FOOD', 'AIDE ALIMENTAIRE & NOURRITURE', 'FOOD AID & FOOD BANKS', Icons.restaurant_rounded),
  CategoryItem('HOUSING', 'REFUGES & LOGEMENT', 'SHELTERS & HOUSING', Icons.home_work_rounded),
  CategoryItem('STUDENT', 'ÉTUDIANTS & ÉDUCATION', 'STUDENTS & EDUCATION', Icons.school_rounded),
  CategoryItem('VIOLENCE', 'VIOLENCE & SÉCURITÉ', 'VIOLENCE & SAFETY', Icons.shield_rounded),
  CategoryItem('EMPLOYMENT', 'EMPLOI & RÉINSERTION', 'JOB SEARCH & REENTRY', Icons.work_rounded),
  CategoryItem('INDIGENOUS', 'PREMIÈRES NATIONS', 'FIRST NATIONS', Icons.diversity_3_rounded),
  CategoryItem('YOUTH', 'JEUNESSE & FAMILLE', 'YOUTH & FAMILY', Icons.child_care_rounded),
  CategoryItem('ADDICTION', 'DÉPENDANCES & SIS', 'ADDICTIONS', Icons.healing_rounded),
  CategoryItem('LGBTQ', 'LGBTQ+ & IDENTITÉ', 'LGBTQ+ & IDENTITY', Icons.favorite_rounded),
  CategoryItem('SENIORS', 'AÎNÉS & PROCHE AIDANCE', 'SENIORS & CAREGIVERS', Icons.elderly_rounded),
  CategoryItem('LEGAL', 'DROITS & JUSTICE', 'LEGAL & JUSTICE', Icons.gavel_rounded),
];

const List<String> kQuebecRegions = [
  'PROVINCIAL (TOUT LE QUÉBEC)',
  '01 - BAS-SAINT-LAURENT',
  '02 - SAGUENAY–LAC-SAINT-JEAN',
  '03 - CAPITALE-NATIONALE',
  '04 - MAURICIE',
  '05 - ESTRIE',
  '06 - MONTRÉAL',
  '07 - OUTAOUAIS',
  '08 - ABITIBI-TÉMISCAMINGUE',
  '09 - CÔTE-NORD',
  '10 - NORD-DU-QUÉBEC',
  '11 - GASPÉSIE–ÎLES-DE-LA-MADELEINE',
  '12 - CHAUDIÈRE-APPALACHES',
  '13 - LAVAL',
  '14 - LANAUDIÈRE',
  '15 - LAURENTIDES',
  '16 - MONTÉRÉGIE (INCL. SUROÎT)',
  '17 - CENTRE-DU-QUÉBEC',
];

const List<SocialResource> kFallbackResources = [];

// ============================================================================
// MAIN SCREEN
// ============================================================================
class CivicLedgerScreen extends StatefulWidget {
  final bool isDark;
  final ThemeMode themeMode;
  final VoidCallback onToggleDark;
  final VoidCallback onUseSystemTheme;

  const CivicLedgerScreen({
    super.key,
    required this.isDark,
    required this.themeMode,
    required this.onToggleDark,
    required this.onUseSystemTheme,
  });

  @override
  State<CivicLedgerScreen> createState() => _CivicLedgerScreenState();
}

class _CivicLedgerScreenState extends State<CivicLedgerScreen> {
  static const String _hideRedirectUrl = 'https://www.google.ca';
  static const String _resourcesJsonUrl =
      'https://raw.githubusercontent.com/Iam-Mithra/INDEXOCIAL/refs/heads/main/resources.json';
  static const String _privacyPolicyRawUrl =
      'https://raw.githubusercontent.com/Iam-Mithra/INDEXOCIAL/refs/heads/main/Privacy_policy.md';
  static const String _privacyPolicyWebUrl =
      'https://github.com/Iam-Mithra/INDEXOCIAL/blob/main/Privacy_policy.md';
  static const String _kofiSupportUrl = 'https://ko-fi.com/iam_mithra';

  // Official source URLs
  static const String _quebecCaUrl = 'https://www.quebec.ca';
  static const String _talGovQcUrl = 'https://www.tal.gouv.qc.ca';
  static const String _suicideHelpline988Url = 'https://988.ca';
  static const String _meteoGcUrl = 'https://meteo.gc.ca';
  static const String _twoOneOneQcUrl = 'https://www.211qc.ca';

  bool _isFr = true;
  NavTab _activeTab = NavTab.directory;
  DisplayMode _displayMode = DisplayMode.ledger;

  bool _hasAcceptedDisclaimer = false;
  bool _disclaimerChecked = false;
  bool _hasSeenTour = false;
  String _cachedPrivacyPolicyText = '';

  // --- ÉTAT ALERTES MÉTÉO ECCC (PAGE PRINCIPALE UNIQUEMENT) ---
  bool _isLoadingWeather = false;
  String? _weatherError;
  bool _locationPermissionDeniedForever = false;
  bool _locationServiceDisabled = false;
  List<EcccWeatherAlert> _weatherAlerts = [];

  // --- ÉTAT ACCESSIBILITÉ (Confirmation d'appel activée par défaut) ---
  double _textScaleFactor = 1.0;
  bool _highContrast = false;
  bool _confirmEmergencyCalls = true;

  Color get _bg => widget.isDark ? CivicPalette.darkBg : CivicPalette.lightBg;
  Color get _cardBg => widget.isDark ? CivicPalette.darkCard : CivicPalette.lightCard;

  Color get _cardBorder {
    if (_highContrast) {
      return widget.isDark ? Colors.white70 : Colors.black87;
    }
    return widget.isDark ? CivicPalette.darkCardBorder : CivicPalette.lightCardBorder;
  }

  double get _cardBorderWidth => _highContrast ? 2.2 : 1.0;

  Color get _textPrimary => widget.isDark ? CivicPalette.darkTextPrimary : CivicPalette.lightTextPrimary;

  Color get _textMuted {
    if (_highContrast) {
      return widget.isDark ? Colors.white : Colors.black;
    }
    return widget.isDark ? CivicPalette.darkTextMuted : CivicPalette.lightTextMuted;
  }

  Color get _accentText => widget.isDark ? CivicPalette.signalYellow : const Color(0xFFB48A00);

  String _searchQuery = '';
  String _selectedCategory = 'ALL';

  List<SocialResource> _resources = [];
  final Set<String> _savedIds = {};
  List<PersonalNote> _notes = [];

  final Set<String> _wizardCatIds = {};
  Set<String> _wizardRegions = {};
  bool _isLocatingWizardRegion = false;
  String? _detectedWizardRegion;

  // Shake Detection
  StreamSubscription<UserAccelerometerEvent>? _shakeSubscription;
  DateTime? _lastShakeTime;
  bool _enableShakeHide = true;

  // Audio Memo
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecordingAudio = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _playingAudioPath;

  // Add Resource Form
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _webController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();
  Set<String> _newCatIds = {'HEALTH'};
  bool _submitOnlineToTeam = false;

  // Notes & Search Controllers
  final _noteTitleController = TextEditingController();
  final _noteBodyController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _resources = List<SocialResource>.from(kFallbackResources);
    _loadAccessibilityPrefs();
    _loadCachedAndRemoteData();
    _fetchEcccWeatherAlerts();
    _startShakeDetector();
  }

  // ==========================================================================
  // ECCC GEOMET-OGC WEATHER ALERTS (GEOLOCATOR + BBOX +/- 0.05)
  // ==========================================================================
  Future<void> _fetchEcccWeatherAlerts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
      _locationPermissionDeniedForever = false;
      _locationServiceDisabled = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingWeather = false;
          _locationServiceDisabled = true;
          _weatherError = _isFr
              ? 'Les services de localisation (GPS) sont désactivés sur votre appareil.'
              : 'Location services (GPS) are disabled on your device.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoadingWeather = false;
            _weatherError = _isFr
                ? 'Permission de localisation refusée. Activez-la pour voir les alertes météo d’Environnement Canada.'
                : 'Location permission denied. Enable it to view Environment Canada weather alerts.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingWeather = false;
          _locationPermissionDeniedForever = true;
          _weatherError = _isFr
              ? 'Permission GPS bloquée définitivement. Ouvrez les paramètres de l’application pour l’autoriser.'
              : 'GPS permission permanently denied. Open app settings to allow location access.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      const double delta = 0.05;
      final double minLon = position.longitude - delta;
      final double minLat = position.latitude - delta;
      final double maxLon = position.longitude + delta;
      final double maxLat = position.latitude + delta;

      final uri = Uri.https(
        'api.weather.gc.ca',
        '/collections/weather-alerts/items',
        {
          'f': 'json',
          'bbox': '$minLon,$minLat,$maxLon,$maxLat',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decodedBody = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> geoJson = jsonDecode(decodedBody);
      final List<dynamic> features = (geoJson['features'] as List<dynamic>?) ?? [];

      final parsedAlerts = features
          .where((feature) => feature is Map)
          .map((feature) {
        final rawProps = (feature as Map)['properties'];
        final props = rawProps is Map ? rawProps : {};
        return EcccWeatherAlert.fromProperties(props);
      })
          .where((alert) => alert.alertNameFr.isNotEmpty && alert.isSevereAlert)
          .toList();

      if (!mounted) return;
      setState(() {
        _weatherAlerts = parsedAlerts;
        _isLoadingWeather = false;
      });
    } catch (e) {
      debugPrint('ECCC WEATHER ERROR: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingWeather = false;
        _weatherError = _isFr
            ? 'Impossible de vérifier les alertes météo d’Environnement Canada pour le moment.'
            : 'Unable to check Environment Canada weather alerts right now.';
      });
    }
  }

  // ==========================================================================
  // DÉTECTION GPS DE LA RÉGION ADMINISTRATIVE DU QUÉBEC (ASSISTANT)
  // ==========================================================================
  String _resolveQuebecRegionFromCoordinates(double lat, double lon) {
    if (lat >= 49.0 && lon <= -70.0) {
      return '10 - NORD-DU-QUÉBEC';
    }
    if (lat >= 48.5 && lon > -70.0) {
      return '09 - CÔTE-NORD';
    }
    if ((lat >= 47.0 && lat <= 48.0 && lon >= -62.5 && lon <= -61.0) ||
        (lat >= 47.8 && lat <= 49.3 && lon >= -67.2 && lon <= -64.0)) {
      return '11 - GASPÉSIE–ÎLES-DE-LA-MADELEINE';
    }
    if (lat >= 47.3 && lat < 48.9 && lon >= -70.0 && lon < -67.2) {
      return '01 - BAS-SAINT-LAURENT';
    }
    if (lat >= 48.0 && lat < 50.5 && lon >= -73.5 && lon <= -70.0) {
      return '02 - SAGUENAY–LAC-SAINT-JEAN';
    }
    if (lat >= 46.2 && lat < 49.0 && lon <= -76.5) {
      return '08 - ABITIBI-TÉMISCAMINGUE';
    }
    if (lat >= 45.3 && lat < 47.8 && lon >= -77.5 && lon <= -74.7) {
      return '07 - OUTAOUAIS';
    }
    if (lat >= 45.40 && lat <= 45.71 && lon >= -73.99 && lon <= -73.47) {
      return '06 - MONTRÉAL';
    }
    if (lat > 45.51 && lat <= 45.71 && lon >= -73.89 && lon <= -73.51) {
      return '13 - LAVAL';
    }
    if (lat >= 45.65 && lat < 47.5 && lon >= -75.8 && lon <= -73.85) {
      return '15 - LAURENTIDES';
    }
    if (lat >= 45.68 && lat < 47.8 && lon > -74.2 && lon <= -73.15) {
      return '14 - LANAUDIÈRE';
    }
    if (lat >= 46.2 && lat < 48.5 && lon > -73.5 && lon <= -72.0) {
      return '04 - MAURICIE';
    }
    if (lat >= 46.65 && lat < 48.2 && lon > -72.4 && lon <= -69.7) {
      return '03 - CAPITALE-NATIONALE';
    }
    if (lat >= 45.8 && lat < 47.35 && lon >= -71.6 && lon <= -69.6) {
      return '12 - CHAUDIÈRE-APPALACHES';
    }
    if (lat >= 45.8 && lat < 46.65 && lon >= -72.9 && lon < -71.5) {
      return '17 - CENTRE-DU-QUÉBEC';
    }
    if (lat >= 45.0 && lat < 45.85 && lon >= -72.45 && lon <= -70.7) {
      return '05 - ESTRIE';
    }
    if (lat >= 45.0 && lat < 46.05 && lon >= -74.5 && lon < -72.45) {
      return '16 - MONTÉRÉGIE (INCL. SUROÎT)';
    }

    return kQuebecRegions.first;
  }

  Future<void> _detectUserRegionForWizard() async {
    if (_isLocatingWizardRegion) return;

    if (_detectedWizardRegion != null && _wizardRegions.contains(_detectedWizardRegion)) {
      setState(() {
        _wizardRegions.remove(_detectedWizardRegion);
      });
      return;
    }

    setState(() => _isLocatingWizardRegion = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CivicPalette.vermilion,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text(
              _isFr
                  ? 'Activez le GPS de votre appareil pour détecter votre région.'
                  : 'Enable device GPS to detect your region.',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CivicPalette.vermilion,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text(
              _isFr
                  ? 'Permission de localisation refusée. Sélectionnez votre région manuellement.'
                  : 'Location permission denied. Select your region manually.',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final detected = _resolveQuebecRegionFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _detectedWizardRegion = detected;
        _wizardRegions = {detected};
      });

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: CivicPalette.signalYellow,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 3),
            content: Text(
              _isFr ? 'RÉGION DÉTECTÉE : $detected' : 'DETECTED REGION: $detected',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: CivicPalette.darkBg,
              ),
            ),
          ),
        );
    } catch (e) {
      debugPrint('WIZARD GPS REGION ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CivicPalette.vermilion,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text(
            _isFr
                ? 'Impossible de déterminer votre position GPS.'
                : 'Unable to determine your GPS location.',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocatingWizardRegion = false);
      }
    }
  }

  String _formatAlertEndDatetime(String rawIso) {
    if (rawIso.isEmpty) return '';
    final dt = DateTime.tryParse(rawIso)?.toLocal();
    if (dt == null) return rawIso;
    return _formatTimestamp(dt);
  }

  Widget _buildWeatherAlertsSection() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder, width: _cardBorderWidth),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: CivicPalette.signalYellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isFr
                    ? 'Vérification des alertes météo officielles (ECCC — meteo.gc.ca)...'
                    : 'Checking official weather alerts (ECCC — meteo.gc.ca)...',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textMuted, fontFamily: 'Roboto'),
              ),
            ),
          ],
        ),
      );
    }

    if (_weatherError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder, width: _cardBorderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_off_rounded, color: CivicPalette.signalYellow, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _weatherError!,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textPrimary, fontFamily: 'Roboto'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_locationPermissionDeniedForever)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CivicPalette.signalYellow,
                      foregroundColor: CivicPalette.darkBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () async {
                      await Geolocator.openAppSettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: Text(
                      _isFr ? 'PARAMÈTRES APP' : 'APP SETTINGS',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                if (_locationServiceDisabled)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CivicPalette.signalYellow,
                      foregroundColor: CivicPalette.darkBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                    },
                    icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                    label: Text(
                      _isFr ? 'ACTIVER LE GPS' : 'ENABLE GPS',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bg,
                    foregroundColor: _textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                    ),
                  ),
                  onPressed: _fetchEcccWeatherAlerts,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    _isFr ? 'RÉESSAYER' : 'RETRY',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_weatherAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder, width: _cardBorderWidth),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF22C55E), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isFr
                    ? 'Aucune alerte météo grave active pour votre secteur (Source officielle : meteo.gc.ca).'
                    : 'No severe weather alerts active for your area (Official source: meteo.gc.ca).',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textPrimary, fontFamily: 'Roboto'),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 18, color: _textMuted),
              onPressed: _fetchEcccWeatherAlerts,
              tooltip: _isFr ? 'Actualiser la météo' : 'Refresh weather',
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _weatherAlerts.map((alert) {
        final Color levelColor;
        switch (alert.riskColourFr) {
          case 'rouge':
            levelColor = CivicPalette.vermilion;
            break;
          case 'orange':
            levelColor = const Color(0xFFFF8C00);
            break;
          default:
            levelColor = CivicPalette.signalYellow;
        }

        final String endFormatted = _formatAlertEndDatetime(alert.eventEndDatetime);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: levelColor, width: _highContrast ? 2.6 : 1.8),
            boxShadow: [
              BoxShadow(
                color: levelColor.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: levelColor, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: levelColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            alert.riskColourFr.isNotEmpty
                                ? 'RISQUE ${alert.riskColourFr.toUpperCase()}'
                                : alert.alertType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: alert.riskColourFr == 'jaune' || alert.riskColourFr.isEmpty
                                  ? CivicPalette.darkBg
                                  : Colors.white,
                              fontFamily: 'sans-serif-condensed',
                            ),
                          ),
                        ),
                        if (alert.impactFr.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _cardBorder, width: _cardBorderWidth),
                            ),
                            child: Text(
                              'IMPACT : ${alert.impactFr.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                alert.alertNameFr.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  fontFamily: 'sans-serif-condensed',
                ),
              ),
              if (alert.featureNameFr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_rounded, size: 15, color: levelColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert.featureNameFr,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _accentText,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (endFormatted.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _isFr ? 'Fin prévue : $endFormatted' : 'Expected end: $endFormatted',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
              if (alert.alertTextFr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  alert.alertTextFr,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textPrimary,
                    height: 1.4,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _loadAccessibilityPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _textScaleFactor = prefs.getDouble('indexocial_text_scale') ?? 1.0;
      _highContrast = prefs.getBool('indexocial_high_contrast') ?? false;
      _confirmEmergencyCalls = prefs.getBool('indexocial_confirm_calls') ?? true;
    });
  }

  Future<void> _saveAccessibilityPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('indexocial_text_scale', _textScaleFactor);
    await prefs.setBool('indexocial_high_contrast', _highContrast);
    await prefs.setBool('indexocial_confirm_calls', _confirmEmergencyCalls);
  }

  void _startShakeDetector() {
    _shakeSubscription?.cancel();
    _shakeSubscription = userAccelerometerEventStream().listen((event) {
      if (!_enableShakeHide) return;

      final acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (acceleration > 15.0) {
        final now = DateTime.now();
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > const Duration(seconds: 2)) {
          _lastShakeTime = now;
          _quickHideEmergency();
        }
      }
    });
  }

  void _quickHideEmergency() => _launchUri(_hideRedirectUrl);

  Future<void> _loadCachedAndRemoteData() async {
    final prefs = await SharedPreferences.getInstance();

    final accepted = prefs.getBool('indexocial_disclaimer_accepted') ?? false;
    final seenTour = prefs.getBool('indexocial_tour_seen') ?? false;
    final savedList = prefs.getStringList('indexocial_saved_ids');
    final notesJsonStr = prefs.getString('indexocial_personal_notes');
    final cachedJsonStr = prefs.getString('indexocial_cached_resources');
    final customJsonStr = prefs.getString('indexocial_custom_resources');
    final cachedPrivacy = prefs.getString('indexocial_cached_privacy_policy') ?? '';

    setState(() {
      _hasAcceptedDisclaimer = accepted;
      _hasSeenTour = seenTour;
      _cachedPrivacyPolicyText = cachedPrivacy;

      if (savedList != null) {
        _savedIds
          ..clear()
          ..addAll(savedList);
      }

      if (notesJsonStr != null) {
        try {
          final List<dynamic> decodedNotes = jsonDecode(notesJsonStr);
          _notes = decodedNotes.map((item) => PersonalNote.fromJson(item)).toList();
        } catch (_) {}
      }

      if (cachedJsonStr != null) {
        try {
          final List<dynamic> decodedCache = jsonDecode(cachedJsonStr);
          _resources = decodedCache.map((item) => SocialResource.fromJson(item)).toList();
        } catch (_) {}
      }

      if (customJsonStr != null) {
        try {
          final List<dynamic> decodedCustom = jsonDecode(customJsonStr);
          final customResources = decodedCustom.map((item) => SocialResource.fromJson(item)).toList();
          _resources.insertAll(0, customResources);
        } catch (_) {}
      }
    });

    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_resourcesJsonUrl?t=$cacheBuster'),
      );
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final List<dynamic> decodedNet = jsonDecode(decodedBody);
        await prefs.setString('indexocial_cached_resources', decodedBody);
        final netResources = decodedNet.map((item) => SocialResource.fromJson(item)).toList();

        final customOnly = _resources.where((r) => r.isCustom).toList();
        if (mounted) {
          setState(() {
            _resources = [...customOnly, ...netResources];
          });
        }
      }
    } catch (e) {
      debugPrint('FETCH ERROR: $e');
    }
  }

  Future<void> _acceptDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('indexocial_disclaimer_accepted', true);
    setState(() => _hasAcceptedDisclaimer = true);

    if (!_hasSeenTour && mounted) {
      _hasSeenTour = true;
      await prefs.setBool('indexocial_tour_seen', true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAppTourSheet();
      });
    }
  }

  Future<void> _persistSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('indexocial_saved_ids', _savedIds.toList());
  }

  Future<void> _persistCustomResources() async {
    final prefs = await SharedPreferences.getInstance();
    final customOnly = _resources.where((r) => r.isCustom).toList();
    await prefs.setString('indexocial_custom_resources', jsonEncode(customOnly.map((r) => r.toJson()).toList()));
  }

  Future<void> _persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('indexocial_personal_notes', jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _addPersonalNote() {
    final title = _noteTitleController.text.trim();
    final body = _noteBodyController.text.trim();
    if (title.isEmpty && body.isEmpty) return;

    final now = DateTime.now();
    setState(() {
      _notes.insert(
        0,
        PersonalNote(
          id: now.millisecondsSinceEpoch.toString(),
          title: title.isEmpty ? (_isFr ? 'NOTE SANS TITRE' : 'UNTITLED NOTE') : title.toUpperCase(),
          content: body,
          dateStr: _formatTimestamp(now),
        ),
      );
      _noteTitleController.clear();
      _noteBodyController.clear();
    });
    _persistNotes();
  }

  void _deletePersonalNote(String id) {
    setState(() => _notes.removeWhere((n) => n.id == id));
    _persistNotes();
  }

  void _copyAllNotes() {
    if (_notes.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln(_isFr
        ? '=== MES NOTES PERSONNELLES // INDEXOCIAL ==='
        : '=== MY PERSONAL NOTES // INDEXOCIAL ===');
    buffer.writeln('${_isFr ? "Exporté le" : "Exported on"} : ${_formatTimestamp(DateTime.now())}');
    buffer.writeln('============================================\n');

    for (final note in _notes) {
      buffer.writeln('• ${note.title} (${note.dateStr})');
      if (note.content.isNotEmpty) {
        buffer.writeln(note.content);
      }
      if (note.audioPath != null) {
        buffer.writeln(_isFr
            ? '[Fichier audio enregistré localement sur l’appareil]'
            : '[Audio memo saved locally on device]');
      }
      buffer.writeln('\n--------------------------------------------\n');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: CivicPalette.signalYellow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
          content: Text(
            _isFr
                ? 'TOUTES VOS NOTES ONT ÉTÉ COPIÉES (${_notes.length}) !'
                : 'ALL YOUR NOTES HAVE BEEN COPIED (${_notes.length})!',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: CivicPalette.darkBg,
            ),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _webController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _noteTitleController.dispose();
    _noteBodyController.dispose();
    super.dispose();
  }

  List<SocialResource> get _filteredResources {
    final q = _searchQuery.toLowerCase().trim();
    final list = _resources.where((item) {
      if (_activeTab == NavTab.saved && !_savedIds.contains(item.id)) return false;
      if (_activeTab == NavTab.directory &&
          _selectedCategory != 'ALL' &&
          !item.categoryIds.contains(_selectedCategory)) {
        return false;
      }
      if (q.isNotEmpty) {
        final haystack = [
          item.nameFr,
          item.nameEn,
          item.phone,
          item.address,
          item.descFr,
          item.descEn,
          item.region,
          ...item.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();

    if (_activeTab == NavTab.directory) {
      list.sort((a, b) {
        final aFav = _savedIds.contains(a.id) ? 0 : 1;
        final bFav = _savedIds.contains(b.id) ? 0 : 1;
        return aFav.compareTo(bFav);
      });
    }

    return list;
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String dirPath;
        try {
          final dir = await getApplicationDocumentsDirectory();
          dirPath = dir.path;
        } catch (_) {
          dirPath = Directory.systemTemp.path;
        }
        final path = '$dirPath/memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          _isRecordingAudio = true;
          _recordSeconds = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _recordSeconds++);
        });
      }
    } catch (e) {
      debugPrint('RECORD ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CivicPalette.vermilion,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text(
              _isFr
                  ? 'Veuillez redémarrer complètement l’application pour activer les plugins natifs audio.'
                  : 'Please fully restart the application to register native audio plugins.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() => _isRecordingAudio = false);

      if (path != null && path.isNotEmpty) {
        final now = DateTime.now();
        final voiceNote = PersonalNote(
          id: now.millisecondsSinceEpoch.toString(),
          title: _isFr ? '🎙 MÉMO VOCAL D\'URGENCE' : '🎙 EMERGENCY VOICE MEMO',
          content: _isFr ? 'Enregistrement audio local (${_recordSeconds}s)' : 'Local audio recording (${_recordSeconds}s)',
          dateStr: _formatTimestamp(now),
          audioPath: path,
        );

        setState(() => _notes.insert(0, voiceNote));
        _persistNotes();
      }
    } catch (e) {
      debugPrint('STOP ERROR: $e');
    }
  }

  Future<void> _playVoiceNote(String path) async {
    if (_playingAudioPath == path) {
      await _audioPlayer.stop();
      setState(() => _playingAudioPath = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _playingAudioPath = path);
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingAudioPath = null);
      });
    }
  }

  Future<void> _launchUri(String rawUri) async {
    if (_confirmEmergencyCalls && rawUri.startsWith('tel:')) {
      final displayPhone = rawUri.replaceFirst('tel:', '');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CivicPalette.signalYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: CivicPalette.signalYellow, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isFr ? 'CONFIRMER L’APPEL' : 'CONFIRM CALL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            _isFr
                ? 'Voulez-vous vraiment composer le $displayPhone ?'
                : 'Do you really want to call $displayPhone?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary, fontFamily: 'Roboto'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                _isFr ? 'ANNULER' : 'CANCEL',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.signalYellow,
                foregroundColor: CivicPalette.darkBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text(
                _isFr ? 'APPELER' : 'CALL',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final uri = Uri.tryParse(rawUri);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openMap(String address) {
    final query = Uri.encodeComponent(address);
    _launchUri('https://www.google.com/maps/search/?api=1&query=$query');
  }

  void _openAppTourSheet() {
    int currentStep = 0;

    final steps = [
      (
      icon: Icons.phone_in_talk_rounded,
      color: CivicPalette.vermilion,
      titleFr: '1. Appels d’urgence en 1 clic',
      titleEn: '1. One-Tap Emergency Calls',
      descFr:
      'Accédez instantanément aux lignes essentielles du Québec en haut de l’écran : 911 (Urgence), 811 (Info-Social), 988 (Prévention suicide) et 211 (Aide communautaire).',
      descEn:
      'Instantly reach essential Quebec helplines at the top of the screen: 911 (Emergency), 811 (Info-Social), 988 (Suicide Crisis), and 211 (Community Aid).',
      tab: NavTab.directory,
      ),
      (
      icon: Icons.explore_rounded,
      color: CivicPalette.signalYellow,
      titleFr: '2. Répertoire hors-ligne & QR Contact',
      titleEn: '2. Offline Directory & Contact QR',
      descFr:
      'Filtrez les organismes par catégorie ou mot-clé, ouvrez l’itinéraire sur Google Maps, ou générez un code QR vCard pour enregistrer un contact sans connexion.',
      descEn:
      'Filter organizations by category or keyword, open directions in Google Maps, or generate a vCard QR code to save contacts offline.',
      tab: NavTab.directory,
      ),
      (
      icon: Icons.assistant_rounded,
      color: CivicPalette.signalYellow,
      titleFr: '3. Assistant d’orientation rapide',
      titleEn: '3. Rapid Triage Wizard',
      descFr:
      'Cochez vos besoins (logement, aide alimentaire, santé mentale, violence...) et détectez automatiquement votre région du Québec par GPS.',
      descEn:
      'Check your needs (housing, food aid, mental health, safety...) and automatically detect your Quebec region via GPS.',
      tab: NavTab.wizard,
      ),
      (
      icon: Icons.mic_rounded,
      color: CivicPalette.signalYellow,
      titleFr: '4. Carnet de notes & Dictaphone privé',
      titleEn: '4. Private Notes & Voice Dictaphone',
      descFr:
      'Notez vos rendez-vous et numéros de dossier, enregistrez des mémos vocaux confidentiels directement sur votre appareil et copiez toutes vos notes en un geste.',
      descEn:
      'Jot down appointments and case numbers, record confidential voice memos directly on your device, and copy all your notes in one tap.',
      tab: NavTab.notes,
      ),
      (
      icon: Icons.shield_rounded,
      color: CivicPalette.vermilion,
      titleFr: '5. Mode « Urgence Discrète » (✕ HIDE)',
      titleEn: '5. Quick Hide Safety Mode (✕ HIDE)',
      descFr:
      'Besoin de quitter l’application rapidement ? Appuyez sur le bouton rouge « ✕ HIDE » en haut à droite ou secouez votre téléphone pour basculer immédiatement vers Google.ca.',
      descEn:
      'Need to exit the app quickly? Tap the red "✕ HIDE" button at the top right or shake your phone to immediately switch to Google.ca.',
      tab: NavTab.more,
      ),
      (
      icon: Icons.accessibility_new_rounded,
      color: CivicPalette.signalYellow,
      titleFr: '6. Accessibilité, Sources officielles & Ressources',
      titleEn: '6. Accessibility, Official Sources & Resources',
      descFr:
      'Dans l’onglet « Plus », ajustez la taille du texte, consultez les sources officielles, gérez la confirmation avant appel ou ajoutez vos propres ressources.',
      descEn:
      'In the "More" tab, adjust text size, view official sources, manage call confirmation, or add your own local resources.',
      tab: NavTab.more,
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final step = steps[currentStep];
          final isLast = currentStep == steps.length - 1;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const GlobeWireframeIcon(size: 22, color: CivicPalette.signalYellow),
                          const SizedBox(width: 8),
                          Text(
                            _isFr ? 'DÉCOUVRIR INDEXOCIAL' : 'INDEXOCIAL TOUR',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _accentText,
                              letterSpacing: 0.8,
                              fontFamily: 'sans-serif-condensed',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${currentStep + 1} / ${steps.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _textMuted,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(steps.length, (i) {
                      final active = i == currentStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: active ? CivicPalette.signalYellow : _cardBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: step.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: step.color.withValues(alpha: 0.4)),
                    ),
                    child: Icon(step.icon, color: step.color, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isFr ? step.titleFr : step.titleEn,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                      fontFamily: 'sans-serif-condensed',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFr ? step.descFr : step.descEn,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _textMuted,
                      height: 1.45,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: _bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _activeTab = step.tab);
                      },
                      icon: Icon(Icons.arrow_outward_rounded, size: 15, color: _accentText),
                      label: Text(
                        _isFr ? 'Aller à cet onglet maintenant' : 'Go to this tab now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _accentText,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (currentStep > 0) ...[
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _bg,
                              foregroundColor: _textPrimary,
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                              ),
                            ),
                            onPressed: () => setModalState(() => currentStep--),
                            child: Text(
                              _isFr ? 'PRÉCÉDENT' : 'PREVIOUS',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              _isFr ? 'PASSER' : 'SKIP',
                              style: TextStyle(color: _textMuted, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CivicPalette.signalYellow,
                            foregroundColor: CivicPalette.darkBg,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            if (isLast) {
                              Navigator.pop(ctx);
                            } else {
                              setModalState(() => currentStep++);
                            }
                          },
                          icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
                          label: Text(
                            isLast
                                ? (_isFr ? 'TERMINER LE TOUR' : 'FINISH TOUR')
                                : (_isFr ? 'SUIVANT' : 'NEXT'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPrivacyPolicyModal() async {
    final prefs = await SharedPreferences.getInstance();
    String policyText = _cachedPrivacyPolicyText.isNotEmpty
        ? _cachedPrivacyPolicyText
        : (prefs.getString('indexocial_cached_privacy_policy') ?? '');

    try {
      final response = await http.get(Uri.parse(_privacyPolicyRawUrl));
      if (response.statusCode == 200) {
        final fetched = utf8.decode(response.bodyBytes).trim();
        if (fetched.isNotEmpty && !fetched.trimLeft().startsWith('<!DOCTYPE html>')) {
          policyText = fetched;
          _cachedPrivacyPolicyText = fetched;
          await prefs.setString('indexocial_cached_privacy_policy', fetched);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.privacy_tip_rounded, color: CivicPalette.signalYellow, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isFr ? 'POLITIQUE DE CONFIDENTIALITÉ' : 'PRIVACY POLICY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                          fontFamily: 'sans-serif-condensed',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      policyText.isNotEmpty
                          ? policyText
                          : (_isFr
                          ? 'Impossible de charger la politique de confidentialité hors-ligne. Cliquez sur « Source Web » ci-dessous.'
                          : 'Unable to load privacy policy offline. Tap "Web Source" below.'),
                      style: TextStyle(fontSize: 13.5, color: _textPrimary, height: 1.45, fontFamily: 'Roboto'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bg,
                          foregroundColor: _textPrimary,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                          ),
                        ),
                        onPressed: () => _launchUri(_privacyPolicyWebUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          _isFr ? 'SOURCE WEB' : 'WEB SOURCE',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, fontFamily: 'sans-serif-condensed'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CivicPalette.signalYellow,
                          foregroundColor: CivicPalette.darkBg,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          _isFr ? 'FERMER' : 'CLOSE',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, fontFamily: 'sans-serif-condensed'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CivicPalette.vermilion.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: CivicPalette.vermilion, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isFr ? 'SUPPORT TECHNIQUE' : 'APP SUPPORT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CivicPalette.vermilion.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CivicPalette.vermilion.withValues(alpha: 0.3)),
              ),
              child: Text(
                _isFr
                    ? '⚠ URGENCE : Si vous êtes en danger immédiat, composez le 911 ou le 988.'
                    : '⚠ EMERGENCY: If you are in danger, call 911 or 988 immediately.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isFr
                  ? 'Pour signaler un bogue, un lien brisé ou proposer une ressource :'
                  : 'To report a bug, broken link, or suggest a resource:',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder, width: _cardBorderWidth),
              ),
              child: SelectableText(
                'IamMithra@proton.me',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _accentText),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isFr ? 'ANNULER' : 'CANCEL', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicPalette.signalYellow,
              foregroundColor: CivicPalette.darkBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _launchUri('mailto:IamMithra@proton.me?subject=INDEXOCIAL%20-%20Support');
            },
            child: Text(_isFr ? 'ÉCRIRE UN COURRIEL' : 'SEND EMAIL', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showContactQRCode(SocialResource item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
        ),
        title: Text(
          'QR CODE // CONTACT',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name(_isFr),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _textPrimary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: item.toVCard(_isFr),
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  errorStateBuilder: (cxt, err) => Center(
                    child: Text(_isFr ? 'Erreur QR' : 'QR Error', style: const TextStyle(color: Colors.black, fontSize: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isFr ? 'Scannez avec l’appareil photo pour ajouter aux contacts.' : 'Scan with camera to add to contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicPalette.signalYellow,
              foregroundColor: CivicPalette.darkBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(_isFr ? 'FERMER' : 'CLOSE', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog(SocialResource item) {
    final issueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CivicPalette.vermilion.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.report_problem_rounded, color: CivicPalette.vermilion, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isFr ? 'SIGNALER UN PROBLÈME' : 'REPORT AN ISSUE',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder, width: _cardBorderWidth),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: CivicPalette.signalYellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name(_isFr)} (ID: ${item.id})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isFr
                  ? 'Décrivez l\'erreur (ex. numéro erroné, adresse changée, service fermé...) :'
                  : 'Describe the issue (e.g. wrong number, address changed, closed service...):',
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: issueController,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: _textPrimary, fontFamily: 'Roboto'),
              decoration: InputDecoration(
                hintText: _isFr ? 'Détails du problème rencontré...' : 'Details of the reported issue...',
                hintStyle: TextStyle(fontSize: 12, color: _textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isFr ? 'ANNULER' : 'CANCEL', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicPalette.signalYellow,
              foregroundColor: CivicPalette.darkBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              final comment = issueController.text.trim();
              Navigator.pop(context);
              final subject = Uri.encodeComponent('INDEXOCIAL - Signalement de problème: ${item.nameFr}');
              final body = Uri.encodeComponent(
                'SIGNALEMENT DE PROBLÈME // INDEXOCIAL\n'
                    '-----------------------------------\n'
                    'Ressource : ${item.nameFr}\n'
                    'ID : ${item.id}\n'
                    'Téléphone : ${item.phone}\n'
                    'Adresse : ${item.address}\n'
                    'Région : ${item.region}\n'
                    'Site web : ${item.website}\n\n'
                    'DESCRIPTION DU PROBLÈME :\n'
                    '${comment.isEmpty ? "(Aucune description fournie)" : comment}\n',
              );
              _launchUri('mailto:IamMithra@proton.me?subject=$subject&body=$body');
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(_isFr ? 'ENVOYER' : 'SEND', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _copyNumber(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: CivicPalette.signalYellow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 2),
          content: Text(
            _isFr ? 'NUMÉRO COPIÉ : $phone' : 'NUMBER COPIED: $phone',
            style: const TextStyle(fontWeight: FontWeight.w900, color: CivicPalette.darkBg),
          ),
        ),
      );
  }

  void _toggleSave(String id) {
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
    _persistSavedIds();
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = 'ALL';
    });
  }

  void _confirmDeleteCustomResource(SocialResource item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CivicPalette.vermilion.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: CivicPalette.vermilion, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isFr ? 'SUPPRIMER LA RESSOURCE' : 'DELETE RESOURCE',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          _isFr
              ? 'Voulez-vous vraiment supprimer définitivement « ${item.nameFr} » de vos ressources locales ?'
              : 'Are you sure you want to permanently delete "${item.nameEn}" from your local resources?',
          style: TextStyle(fontSize: 13, color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isFr ? 'ANNULER' : 'CANCEL', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicPalette.vermilion,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteCustomResource(item.id);
            },
            child: Text(_isFr ? 'SUPPRIMER' : 'DELETE', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _deleteCustomResource(String id) {
    setState(() {
      _resources.removeWhere((r) => r.id == id && r.isCustom);
      _savedIds.remove(id);
    });
    _persistSavedIds();
    _persistCustomResources();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CivicPalette.vermilion,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
        content: Text(
          _isFr ? 'Ressource supprimée.' : 'Resource deleted.',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  bool _submitNewResource() {
    if (!_formKey.currentState!.validate()) return false;
    final nameInput = _nameController.text.trim().toUpperCase();
    final phoneInput = _phoneController.text.trim();
    final addressInput = _addressController.text.trim();
    final descInput = _descController.text.trim();
    final webInput = _webController.text.trim();
    final shouldSendOnline = _submitOnlineToTeam;

    final nextNum = (_resources.length + 1).toString().padLeft(2, '0');
    final created = SocialResource(
      id: 'LOC-$nextNum',
      nameFr: nameInput,
      nameEn: nameInput,
      categoryIds: _newCatIds.isEmpty ? ['HEALTH'] : _newCatIds.toList(),
      region: kQuebecRegions.first,
      phone: phoneInput.isEmpty ? 'N/A' : phoneInput,
      website: webInput.isEmpty ? 'https://www.211qc.ca' : webInput,
      address: addressInput.isEmpty ? 'Québec, QC' : addressInput,
      descFr: descInput.isEmpty ? 'Ressource locale ajoutée par l’utilisateur.' : descInput,
      descEn: descInput.isEmpty ? 'Local resource added by user.' : descInput,
      tags: ['local', 'custom'],
      isCustom: true,
    );

    setState(() {
      _resources.insert(0, created);
      _savedIds.add(created.id);
      _activeTab = NavTab.directory;
      _nameController.clear();
      _phoneController.clear();
      _webController.clear();
      _addressController.clear();
      _descController.clear();
      _newCatIds = {'HEALTH'};
      _submitOnlineToTeam = false;
    });
    _persistSavedIds();
    _persistCustomResources();

    if (shouldSendOnline) {
      final subject = Uri.encodeComponent('INDEXOCIAL - Nouvelle proposition de ressource: $nameInput');
      final catLabels = created.categoryIds.map((cId) {
        final cat = kCategories.firstWhere((c) => c.id == cId, orElse: () => kCategories.first);
        return cat.labelFr;
      }).join(', ');

      final jsonMap = {
        'id': 'QC-$nextNum',
        'nameFr': created.nameFr,
        'nameEn': created.nameEn,
        'categoryIds': created.categoryIds,
        'region': created.region,
        'phone': created.phone,
        'website': created.website,
        'address': created.address,
        'descFr': created.descFr,
        'descEn': created.descEn,
        'tags': ['communautaire', 'quebec'],
      };

      const encoder = JsonEncoder.withIndent('  ');
      final jsonBlock = ',\n${encoder.convert(jsonMap)}';

      final body = Uri.encodeComponent(
        '==================================================\n'
            '1. VERSION TEXTE (.TXT) - LECTURE RAPIDE\n'
            '==================================================\n'
            'Nom de la ressource : $nameInput\n'
            'Catégories : $catLabels\n'
            'Région : ${created.region}\n'
            'Téléphone : ${created.phone}\n'
            'Adresse : ${created.address}\n'
            'Site Web : ${created.website}\n'
            'Description : ${created.descFr}\n\n'
            '==================================================\n'
            '2. VERSION JSON (À COLLER DANS resources.json)\n'
            '==================================================\n'
            '$jsonBlock\n',
      );

      _launchUri('mailto:IamMithra@proton.me?subject=$subject&body=$body');
    }

    return true;
  }

  void _openAddResourceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isFr ? 'Ajouter Une Ressource Locale' : 'Add Local Resource',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto'),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: _textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      _isFr ? 'Seul le nom de la ressource est obligatoire.' : 'Only the resource name is required.',
                      style: TextStyle(fontSize: 12, color: _textMuted, fontFamily: 'Roboto'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: _textPrimary, fontFamily: 'Roboto'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (_isFr ? 'Nom requis' : 'Name required') : null,
                      decoration: InputDecoration(labelText: _isFr ? 'Nom de la ressource *' : 'Resource Name *'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isFr ? 'Catégories (Sélection multiple) :' : 'Categories (Multi-select):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
                    ),
                    const SizedBox(height: 6),
                    _buildCategoryChecklist(
                      maxHeight: 180,
                      selectedIds: _newCatIds,
                      onChanged: (id, checked) {
                        setState(() {
                          if (checked) {
                            _newCatIds.add(id);
                          } else if (_newCatIds.length > 1) {
                            _newCatIds.remove(id);
                          }
                        });
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressController,
                      style: TextStyle(color: _textPrimary, fontFamily: 'Roboto'),
                      decoration: InputDecoration(labelText: _isFr ? 'Adresse physique (Optionnel)' : 'Physical Address (Optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: _textPrimary, fontFamily: 'Roboto'),
                      decoration: InputDecoration(labelText: _isFr ? 'Numéro de téléphone (Optionnel)' : 'Phone Number (Optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _webController,
                      style: TextStyle(color: _textPrimary, fontFamily: 'Roboto'),
                      decoration: InputDecoration(labelText: _isFr ? 'Site web / Lien (Optionnel)' : 'Website / Link (Optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descController,
                      style: TextStyle(color: _textPrimary, fontFamily: 'Roboto'),
                      maxLines: 3,
                      decoration: InputDecoration(labelText: _isFr ? 'Description des services (Optionnel)' : 'Description (Optional)'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _submitOnlineToTeam ? CivicPalette.signalYellow : _cardBorder,
                          width: _cardBorderWidth,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _submitOnlineToTeam,
                                activeColor: CivicPalette.signalYellow,
                                checkColor: CivicPalette.darkBg,
                                onChanged: (val) {
                                  setState(() => _submitOnlineToTeam = val ?? false);
                                  setModalState(() {});
                                },
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _submitOnlineToTeam = !_submitOnlineToTeam);
                                    setModalState(() {});
                                  },
                                  child: Text(
                                    _isFr
                                        ? 'Soumettre cette ressource à Indexocial (publication en ligne)'
                                        : 'Submit this resource to Indexocial (online publication)',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 44, right: 8, bottom: 4),
                            child: Text(
                              _isFr
                                  ? 'Lorsque cette case est cochée, une copie de cette ressource est envoyée par courriel à l’équipe Indexocial (IamMithra@proton.me) pour révision et ajout au répertoire officiel en ligne.'
                                  : 'When checked, a copy of this resource is sent by email to the Indexocial team (IamMithra@proton.me) for review and addition to the official online directory.',
                              style: TextStyle(fontSize: 11.5, color: _textMuted, height: 1.35, fontFamily: 'Roboto'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CivicPalette.signalYellow,
                        foregroundColor: CivicPalette.darkBg,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        if (_submitNewResource()) {
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        _isFr ? 'Enregistrer la ressource' : 'Save Resource',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAccessibilitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateSetting(VoidCallback fn) {
            setState(fn);
            setModalState(() {});
            _saveAccessibilityPrefs();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.accessibility_new_rounded, color: CivicPalette.signalYellow, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        _isFr ? 'ACCESSIBILITÉ' : 'ACCESSIBILITY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                          fontFamily: 'sans-serif-condensed',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isFr ? 'Taille du texte' : 'Text Size',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final opt in [
                        (1.0, _isFr ? 'Normal' : 'Normal'),
                        (1.15, _isFr ? 'Grand' : 'Large'),
                        (1.3, _isFr ? 'Très grand' : 'Extra Large'),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              showCheckmark: false,
                              side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                              label: Center(
                                child: Text(
                                  opt.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: _textScaleFactor == opt.$1 ? CivicPalette.darkBg : _textPrimary,
                                  ),
                                ),
                              ),
                              selected: _textScaleFactor == opt.$1,
                              selectedColor: CivicPalette.signalYellow,
                              backgroundColor: _bg,
                              onSelected: (_) => updateSetting(() => _textScaleFactor = opt.$1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: CivicPalette.signalYellow,
                    activeTrackColor: CivicPalette.yellowSubtle,
                    title: Text(
                      _isFr ? 'Contraste renforcé' : 'High Contrast',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
                    ),
                    subtitle: Text(
                      _isFr
                          ? 'Bordures épaissies et textes secondaires plus lisibles'
                          : 'Thicker card borders and higher secondary text contrast',
                      style: TextStyle(fontSize: 11.5, color: _textMuted, fontFamily: 'Roboto'),
                    ),
                    value: _highContrast,
                    onChanged: (val) => updateSetting(() => _highContrast = val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: CivicPalette.signalYellow,
                    activeTrackColor: CivicPalette.yellowSubtle,
                    title: Text(
                      _isFr ? 'Confirmation avant les appels (911 / 988 / 811)' : 'Confirm before calls (911 / 988 / 811)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
                    ),
                    subtitle: Text(
                      _isFr
                          ? 'Demande une confirmation avant de lancer un appel'
                          : 'Asks for confirmation before dialing a number',
                      style: TextStyle(fontSize: 11.5, color: _textMuted, fontFamily: 'Roboto'),
                    ),
                    value: _confirmEmergencyCalls,
                    onChanged: (val) => updateSetting(() => _confirmEmergencyCalls = val),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CivicPalette.signalYellow,
                      foregroundColor: CivicPalette.darkBg,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      _isFr ? 'FERMER' : 'DONE',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_textScaleFactor),
      ),
      child: _hasAcceptedDisclaimer ? _buildMainScaffold() : _buildDisclaimerView(),
    );
  }

  Widget _buildMainScaffold() {
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavBar(showSubtitle: true),
            Expanded(
              child: RefreshIndicator(
                color: CivicPalette.darkBg,
                backgroundColor: CivicPalette.signalYellow,
                onRefresh: () async {
                  await Future.wait([
                    _loadCachedAndRemoteData(),
                    if (_activeTab == NavTab.directory) _fetchEcccWeatherAlerts(),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroWelcomeBanner(),
                      const SizedBox(height: 16),
                      _buildQuickEmergencyGrid(),
                      if (_activeTab == NavTab.directory) ...[
                        const SizedBox(height: 14),
                        _buildWeatherAlertsSection(),
                      ],
                      const SizedBox(height: 18),
                      if (_activeTab == NavTab.directory || _activeTab == NavTab.saved) ...[
                        _buildSearchBar(),
                        const SizedBox(height: 14),
                        _buildHorizontalCategorySelector(),
                        const SizedBox(height: 16),
                      ],
                      _buildActiveTabContent(isDesktop),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  // ==========================================================================
  // TOP BAR (SHARED BY DISCLAIMER & MAIN SCREEN)
  // ==========================================================================
  Widget _buildTopNavBar({required bool showSubtitle}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: showSubtitle ? 12 : 16, vertical: showSubtitle ? 8 : 12),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _cardBorder, width: _highContrast ? 1.8 : 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const GlobeWireframeIcon(size: 28, color: CivicPalette.signalYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INDEXOCIAL // QC',
                        style: TextStyle(
                          fontFamily: 'sans-serif-condensed',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _accentText,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showSubtitle)
                        Text(
                          _isFr ? 'Répertoire d’aide sociale Québec' : 'Quebec Social Aid Directory',
                          style: TextStyle(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _isFr = !_isFr),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cardBorder, width: _cardBorderWidth),
                  ),
                  child: Text(
                    _isFr ? 'EN' : 'FR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto'),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _quickHideEmergency,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: CivicPalette.vermilion,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✕ HIDE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'sans-serif-condensed',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DISCLAIMER ONBOARDING VIEW
  // ==========================================================================
  Widget _buildDisclaimerView() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavBar(showSubtitle: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isFr
                          ? 'Avis important et conditions d\'utilisation — Indexocial'
                          : 'Important Notice & Terms of Use — Indexocial',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                        fontFamily: 'sans-serif-condensed',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isFr
                          ? 'Bienvenue sur Indexocial. Avant d\'accéder au répertoire des ressources communautaires et sociales, veuillez lire attentivement et accepter les conditions suivantes :'
                          : 'Welcome to Indexocial. Before accessing the community and social services directory, please carefully read and accept the following terms:',
                      style: TextStyle(fontSize: 13, color: _textMuted, height: 1.4, fontFamily: 'Roboto'),
                    ),
                    const SizedBox(height: 16),
                    _buildDisclaimerSection(
                      title: _isFr
                          ? '1. En cas d\'urgence vitale ou de crise immédiate'
                          : '1. In Case of Emergency or Immediate Crisis',
                      body: _isFr
                          ? 'Indexocial est un outil d\'orientation et d\'information, pas un service d\'intervention d\'urgence. Si vous ou une personne de votre entourage êtes en danger immédiat, en détresse psychologique aiguë ou nécessitez des soins médicaux urgents, fermez cette application et composez immédiatement le 911 (ou le 988 pour la ligne d\'aide en cas de crise de suicide, ou le 811 pour Info-Santé / Info-Social au Québec).'
                          : 'Indexocial is an informational and referral directory, not an emergency response service. If you or someone around you is in immediate danger, experiencing acute psychological distress, or requires urgent medical attention, close this app and immediately call 911 (or 988 for the Suicide Crisis Helpline, or 811 for Info-Santé / Info-Social in Quebec).',
                    ),
                    _buildDisclaimerSection(
                      title: _isFr
                          ? '2. Exactitude et mise à jour des informations'
                          : '2. Accuracy and Updates of Information',
                      body: _isFr
                          ? 'Les informations présentées dans Indexocial (horaires, critères d\'admissibilité, disponibilité des places, adresses, numéros de téléphone et informations transmises par des intervenants ou organismes) sont fournies à titre indicatif. Les services évoluent rapidement : contactez toujours la ressource par téléphone avant de vous déplacer.'
                          : 'The information provided in Indexocial (opening hours, eligibility criteria, spot availability, addresses, phone numbers, and updates shared by community workers or organizations) is for informational purposes only. Services change rapidly: always call ahead before traveling.',
                    ),
                    _buildDisclaimerSection(
                      title: _isFr
                          ? '3. Absence de représentation gouvernementale et indépendance'
                          : '3. No Government Representation & Independence',
                      body: _isFr
                          ? 'Indexocial est une initiative indépendante et ne représente aucun gouvernement ni organisme public (notamment le gouvernement du Québec ou du Canada). L’application n’est pas affiliée aux organismes ni aux ministères mentionnés et ne fournit ni ne traite aucun service gouvernemental officiel. Les informations publiques proviennent de sources officielles telles que quebec.ca, tal.gouv.qc.ca et canada.ca.'
                          : 'Indexocial is an independent application and does not represent any government entity or public body (including the Government of Quebec or Canada). The app is not affiliated with listed organizations or government ministries and does not provide or process official government services. Public information references official sources such as quebec.ca, tal.gouv.qc.ca, and canada.ca.',
                    ),
                    _buildDisclaimerSection(
                      title: _isFr ? '4. Absence de conseils professionnels' : '4. No Professional Advice',
                      body: _isFr
                          ? 'Le contenu disponible sur Indexocial ne constitue en aucun cas un avis médical, juridique, psychologique ou financier. L\'application ne remplace pas l\'accompagnement d\'un professionnel de la santé ou d\'un travailleur social qualifié.'
                          : 'The content available on Indexocial does not constitute medical, legal, psychological, or financial advice. This app is not a substitute for support from a qualified healthcare professional or social worker.',
                    ),
                    _buildDisclaimerSection(
                      title: _isFr ? '5. Protection de la vie privée' : '5. Privacy Protection',
                      body: _isFr
                          ? 'Vos recherches sur Indexocial sont confidentielles. Toutefois, lorsque vous quittez l\'application pour visiter le site web externe d\'un organisme ou pour l\'appeler, les politiques de confidentialité de ces tiers s\'appliquent.'
                          : 'Your searches within Indexocial are confidential. However, once you leave the app to visit an organization\'s external website or call them directly, the privacy policies of those third parties apply.',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openPrivacyPolicyModal,
                        icon: Icon(Icons.privacy_tip_rounded, size: 16, color: _accentText),
                        label: Text(
                          _isFr
                              ? 'Consulter la politique de confidentialité complète'
                              : 'View full privacy policy',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _accentText,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _disclaimerChecked ? CivicPalette.signalYellow : _cardBorder,
                          width: _cardBorderWidth,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _disclaimerChecked,
                            activeColor: CivicPalette.signalYellow,
                            checkColor: CivicPalette.darkBg,
                            onChanged: (val) => setState(() => _disclaimerChecked = val ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _disclaimerChecked = !_disclaimerChecked),
                              child: Text(
                                _isFr
                                    ? 'J\'ai lu et compris ces conditions. Je reconnais qu\'Indexocial est une application indépendante non gouvernementale et ne remplace pas les services d\'urgence.'
                                    : 'I have read and understood these terms. I acknowledge that Indexocial is an independent non-government app and does not replace emergency services.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPrimary, height: 1.35, fontFamily: 'Roboto'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _disclaimerChecked ? CivicPalette.signalYellow : _cardBorder,
                        foregroundColor: _disclaimerChecked ? CivicPalette.darkBg : _textMuted,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: _disclaimerChecked ? _acceptDisclaimer : null,
                      child: Text(
                        _isFr ? 'Accepter et continuer' : 'Accept and Continue',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'sans-serif-condensed'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerSection({required String title, required String body}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _accentText, fontFamily: 'Roboto')),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 12.5, color: _textMuted, height: 1.35, fontFamily: 'Roboto')),
        ],
      ),
    );
  }

  // ==========================================================================
  // HERO BANNER & QUICK EMERGENCY GRID
  // ==========================================================================
  Widget _buildHeroWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _accentText, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                _isFr ? 'ACCÈS DIRECT • INDÉPENDANT' : 'DIRECT ACCESS • INDEPENDENT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _accentText, letterSpacing: 1.0, fontFamily: 'Roboto'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textPrimary, height: 1.15, fontFamily: 'sans-serif-condensed'),
              children: [
                TextSpan(text: _isFr ? 'L’AIDE SOCIALE À VOTRE ' : 'SOCIAL SUPPORT AT YOUR '),
                TextSpan(text: 'PORTÉE.', style: TextStyle(color: _accentText)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isFr
                ? 'Lignes d’urgence, refuges, soutien psychosocial et défense des droits au Québec.'
                : 'Emergency lines, shelters, mental health, and advocacy in Quebec.',
            style: TextStyle(fontSize: 13, color: _textMuted, height: 1.35, fontFamily: 'Roboto'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEmergencyGrid() {
    final cells = [
      ('911', _isFr ? 'URGENCE' : 'EMERGENCY', 'tel:911', CivicPalette.vermilion),
      ('811', 'INFO-SOCIAL', 'tel:811', _accentText),
      ('988', 'SUICIDE', 'tel:18662773553', widget.isDark ? CivicPalette.yellowLight : const Color(0xFFD9A700)),
      ('211', _isFr ? 'REFUGES & AID' : 'COMMUNITY AID', 'tel:211', _textPrimary),
    ];

    return Row(
      children: List.generate(cells.length, (idx) {
        final item = cells[idx];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: idx < cells.length - 1 ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _launchUri(item.$3),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder, width: _cardBorderWidth),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: item.$4.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.phone_in_talk_rounded, color: item.$4, size: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'sans-serif-condensed'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _textMuted, fontFamily: 'Roboto'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ==========================================================================
  // SEARCH & CATEGORIES
  // ==========================================================================
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search_rounded, color: _textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary, fontFamily: 'Roboto'),
              decoration: InputDecoration(
                hintText: _isFr ? 'Rechercher refuge, 811, organisme...' : 'Search shelter, 811, service...',
                hintStyle: TextStyle(color: _textMuted, fontSize: 13, fontFamily: 'Roboto'),
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: _textMuted),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: CivicPalette.signalYellow, borderRadius: BorderRadius.circular(22)),
              child: Text(
                _isFr ? 'FILTRER' : 'FILTER',
                style: const TextStyle(color: CivicPalette.darkBg, fontWeight: FontWeight.w900, fontSize: 11.5, fontFamily: 'sans-serif-condensed'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCategorySelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: kCategories.length,
        itemBuilder: (context, idx) {
          final cat = kCategories[idx];
          final selected = _selectedCategory == cat.id;
          return Container(
            margin: EdgeInsets.only(right: idx < kCategories.length - 1 ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedCategory = cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? CivicPalette.signalYellow : _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? CivicPalette.signalYellow : _cardBorder,
                    width: _cardBorderWidth,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(cat.icon, size: 15, color: selected ? CivicPalette.darkBg : _textMuted),
                    const SizedBox(width: 6),
                    Text(
                      cat.label(_isFr),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? CivicPalette.darkBg : _textPrimary,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // BOTTOM NAV & TAB SWITCHER
  // ==========================================================================
  Widget _buildFloatingBottomNav() {
    final navItems = [
      (NavTab.directory, Icons.home_rounded, _isFr ? 'Accueil' : 'Home'),
      (NavTab.wizard, Icons.assistant_rounded, _isFr ? 'Assistant' : 'Wizard'),
      (NavTab.saved, Icons.bookmark_rounded, _isFr ? 'Favoris' : 'Saved'),
      (NavTab.notes, Icons.note_alt_rounded, _isFr ? 'Notes' : 'Notes'),
      (NavTab.docs, Icons.folder_rounded, _isFr ? 'Guides' : 'Docs'),
      (NavTab.more, Icons.more_horiz_rounded, _isFr ? 'Plus' : 'More'),
    ];

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF16181E) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _cardBorder, width: _cardBorderWidth),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: navItems.map((item) {
            final active = _activeTab == item.$1;
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _activeTab = item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: active ? 14 : 10, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? CivicPalette.signalYellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(item.$2, size: 20, color: active ? CivicPalette.darkBg : _textMuted),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.$3,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: CivicPalette.darkBg, fontFamily: 'Roboto'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDesktop) {
    switch (_activeTab) {
      case NavTab.wizard:
        return _buildWizardView();
      case NavTab.notes:
        return _buildPersonalNotesView();
      case NavTab.docs:
        return _buildUsefulDocsView();
      case NavTab.more:
        return _buildMoreView();
      case NavTab.directory:
      case NavTab.saved:
        return _buildDirectoryListView(isDesktop);
    }
  }

  // ==========================================================================
  // DIRECTORY & CARDS
  // ==========================================================================
  Widget _buildDirectoryListView(bool isDesktop) {
    final items = _filteredResources;
    final hasActiveFilter = _searchQuery.trim().isNotEmpty || (_activeTab == NavTab.directory && _selectedCategory != 'ALL');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _activeTab == NavTab.saved
                  ? (_isFr ? 'CONTACTS SAUVEGARDÉS (${items.length})' : 'SAVED CONTACTS (${items.length})')
                  : (_isFr ? 'RÉPERTOIRE (${items.length})' : 'DIRECTORY (${items.length})'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _textPrimary, letterSpacing: 0.5, fontFamily: 'sans-serif-condensed'),
            ),
            Row(
              children: [
                _buildDisplayToggle(DisplayMode.ledger, Icons.view_list_rounded),
                const SizedBox(width: 4),
                _buildDisplayToggle(DisplayMode.grid, Icons.grid_view_rounded),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder, width: _cardBorderWidth),
            ),
            child: Column(
              children: [
                Icon(
                  _activeTab == NavTab.saved && !hasActiveFilter
                      ? Icons.bookmark_border_rounded
                      : Icons.search_off_rounded,
                  size: 40,
                  color: _textMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  _activeTab == NavTab.saved && !hasActiveFilter
                      ? (_isFr ? 'Vos favoris seront visibles ici.' : 'Your favorites will be visible here.')
                      : (_isFr ? 'Aucune ressource trouvée.' : 'No resource found.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
                ),
                if (hasActiveFilter) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CivicPalette.signalYellow,
                      foregroundColor: CivicPalette.darkBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _resetFilters,
                    child: Text(_isFr ? 'Réinitialiser les filtres' : 'Reset filters', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          )
        else if (_displayMode == DisplayMode.ledger)
          Column(children: items.map(_buildResourceCard).toList())
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 2 : 1,
              mainAxisExtent: 220,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, idx) => _buildGridCard(items[idx]),
          ),
      ],
    );
  }

  Widget _buildDisplayToggle(DisplayMode mode, IconData icon) {
    final active = _displayMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _displayMode = mode),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? CivicPalette.signalYellow : _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? CivicPalette.signalYellow : _cardBorder, width: _cardBorderWidth),
        ),
        child: Icon(icon, size: 16, color: active ? CivicPalette.darkBg : _textMuted),
      ),
    );
  }

  Widget _buildResourceCard(SocialResource item) {
    final isSaved = _savedIds.contains(item.id);
    final badgeTextColor = widget.isDark ? CivicPalette.signalYellow : const Color(0xFF856400);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...item.categoryIds.map((cId) {
                      final catObj = kCategories.firstWhere((c) => c.id == cId, orElse: () => kCategories.first);
                      if (catObj.id == 'ALL') return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isDark ? CivicPalette.yellowSubtle : CivicPalette.signalYellow.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CivicPalette.signalYellow.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          catObj.label(_isFr),
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: badgeTextColor, fontFamily: 'Roboto'),
                        ),
                      );
                    }),
                    if (item.isCustom)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CivicPalette.vermilion.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CivicPalette.vermilion.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _isFr ? 'PERSO' : 'CUSTOM',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: CivicPalette.vermilion, fontFamily: 'Roboto'),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.isCustom)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: CivicPalette.vermilion, size: 22),
                      onPressed: () => _confirmDeleteCustomResource(item),
                      tooltip: _isFr ? 'Supprimer ma ressource' : 'Delete my resource',
                    ),
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isSaved ? _accentText : _textMuted,
                      size: 22,
                    ),
                    onPressed: () => _toggleSave(item.id),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.name(_isFr), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto')),
          const SizedBox(height: 4),
          Text(item.desc(_isFr), style: TextStyle(fontSize: 13, color: _textMuted, height: 1.35, fontFamily: 'Roboto')),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openMap(item.address),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: _accentText, size: 15),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.address,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _accentText,
                      decoration: TextDecoration.underline,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CivicPalette.signalYellow,
                    foregroundColor: CivicPalette.darkBg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => _launchUri('tel:${item.phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: Text(item.phone, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, fontFamily: 'sans-serif-condensed')),
                ),
              ),
              const SizedBox(width: 8),
              _buildMiniActionButton(icon: Icons.copy_rounded, onTap: () => _copyNumber(item.phone)),
              const SizedBox(width: 6),
              _buildMiniActionButton(icon: Icons.language_rounded, onTap: () => _launchUri(item.website)),
              const SizedBox(width: 6),
              _buildMiniActionButton(icon: Icons.qr_code_2_rounded, onTap: () => _showContactQRCode(item)),
              const SizedBox(width: 6),
              _buildMiniActionButton(icon: Icons.report_problem_outlined, onTap: () => _showReportIssueDialog(item)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(SocialResource item) {
    final isSaved = _savedIds.contains(item.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.categoryIds.take(2).map((cId) {
                      final catObj = kCategories.firstWhere((c) => c.id == cId, orElse: () => kCategories.first);
                      return Text(
                        catObj.label(_isFr),
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _accentText),
                      );
                    }).toList(),
                  ),
                  Row(
                    children: [
                      if (item.isCustom)
                        InkWell(
                          onTap: () => _confirmDeleteCustomResource(item),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.delete_outline_rounded, color: CivicPalette.vermilion, size: 18),
                          ),
                        ),
                      InkWell(
                        onTap: () => _showReportIssueDialog(item),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.report_problem_outlined, color: _textMuted, size: 18),
                        ),
                      ),
                      InkWell(
                        onTap: () => _toggleSave(item.id),
                        child: Icon(
                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: isSaved ? _accentText : _textMuted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.name(_isFr),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: CivicPalette.signalYellow,
              foregroundColor: CivicPalette.darkBg,
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _launchUri('tel:${item.phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
            icon: const Icon(Icons.phone_rounded, size: 14),
            label: Text(item.phone, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, fontFamily: 'sans-serif-condensed')),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder, width: _cardBorderWidth),
        ),
        child: Icon(icon, size: 18, color: _textPrimary),
      ),
    );
  }

  // ==========================================================================
  // WIZARD VIEW
  // ==========================================================================
  Widget _buildWizardView() {
    final recommended = _resources.where((r) {
      final catMatch = _wizardCatIds.isEmpty || _wizardCatIds.every((cId) => r.categoryIds.contains(cId));
      final regMatch = _wizardRegions.isEmpty ||
          _wizardRegions.contains(kQuebecRegions.first) ||
          r.region == kQuebecRegions.first ||
          _wizardRegions.contains(r.region);
      return catMatch && regMatch;
    }).toList();

    final isGpsRegionActive =
        _detectedWizardRegion != null && _wizardRegions.contains(_detectedWizardRegion);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isFr ? 'Assistant D’Orientation Rapide' : 'Rapid Triage Wizard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 2),
        Text(
          _isFr ? 'Filtrez par catégories et régions.' : 'Filter by categories and regions.',
          style: TextStyle(fontSize: 12, color: _textMuted, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isGpsRegionActive ? CivicPalette.signalYellow : _cardBg,
              foregroundColor: isGpsRegionActive ? CivicPalette.darkBg : _textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isGpsRegionActive ? CivicPalette.signalYellow : _cardBorder,
                  width: _cardBorderWidth,
                ),
              ),
            ),
            onPressed: _isLocatingWizardRegion ? null : _detectUserRegionForWizard,
            icon: _isLocatingWizardRegion
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isGpsRegionActive ? CivicPalette.darkBg : CivicPalette.signalYellow,
              ),
            )
                : Icon(
              Icons.my_location_rounded,
              size: 18,
              color: isGpsRegionActive ? CivicPalette.darkBg : _accentText,
            ),
            label: Text(
              _isLocatingWizardRegion
                  ? (_isFr ? 'LOCALISATION EN COURS...' : 'LOCATING...')
                  : (isGpsRegionActive
                  ? (_isFr
                  ? 'MA RÉGION (GPS) : $_detectedWizardRegion'
                  : 'MY REGION (GPS): $_detectedWizardRegion')
                  : (_isFr
                  ? 'AFFICHER LES RESSOURCES DE MA RÉGION (GPS)'
                  : 'SHOW RESOURCES IN MY REGION (GPS)')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFamily: 'sans-serif-condensed',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _isFr
              ? (_wizardCatIds.isEmpty ? 'Catégories (Toutes) :' : 'Catégories (${_wizardCatIds.length}) :')
              : (_wizardCatIds.isEmpty ? 'Categories (All):' : 'Categories (${_wizardCatIds.length}):'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 6),
        _buildCategoryChecklist(
          maxHeight: 140,
          selectedIds: _wizardCatIds,
          onChanged: (id, checked) {
            setState(() {
              if (checked) {
                _wizardCatIds.add(id);
              } else {
                _wizardCatIds.remove(id);
              }
            });
          },
        ),
        const SizedBox(height: 12),
        Text(
          _isFr
              ? (_wizardRegions.isEmpty ? 'Régions (Toutes) :' : 'Régions (${_wizardRegions.length}) :')
              : (_wizardRegions.isEmpty ? 'Regions (All):' : 'Regions (${_wizardRegions.length}):'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 6),
        _buildWizardRegionMenu(),
        const SizedBox(height: 18),
        Text(
          _isFr ? 'Ressources Recommandées (${recommended.length})' : 'Recommended Resources (${recommended.length})',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 10),
        if (recommended.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cardBorder, width: _cardBorderWidth),
            ),
            child: Text(
              _isFr ? 'Aucune ressource trouvée pour cette sélection.' : 'No resource found for this selection.',
              style: TextStyle(color: _textMuted, fontSize: 13, fontFamily: 'Roboto'),
            ),
          )
        else
          ...recommended.map(_buildResourceCard),
      ],
    );
  }

  Widget _buildCategoryChecklist({
    required double maxHeight,
    required Set<String> selectedIds,
    required void Function(String id, bool checked) onChanged,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
      ),
      child: RawScrollbar(
        thumbColor: CivicPalette.signalYellow,
        radius: const Radius.circular(8),
        thickness: 4,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 2),
          children: kCategories.where((c) => c.id != 'ALL').map((c) {
            final checked = selectedIds.contains(c.id);
            return CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              value: checked,
              activeColor: CivicPalette.signalYellow,
              checkColor: CivicPalette.darkBg,
              secondary: Icon(c.icon, size: 16, color: checked ? _accentText : _textMuted),
              title: Text(
                c.label(_isFr),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: checked ? FontWeight.w800 : FontWeight.w600,
                  color: _textPrimary,
                  fontFamily: 'Roboto',
                ),
              ),
              onChanged: (val) => onChanged(c.id, val ?? false),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWizardRegionMenu() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
      ),
      child: RawScrollbar(
        thumbColor: CivicPalette.signalYellow,
        radius: const Radius.circular(8),
        thickness: 4,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 2),
          children: kQuebecRegions.map((reg) {
            final checked = _wizardRegions.contains(reg);
            return CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              value: checked,
              activeColor: CivicPalette.signalYellow,
              checkColor: CivicPalette.darkBg,
              secondary: Icon(Icons.location_on_rounded, size: 16, color: checked ? _accentText : _textMuted),
              title: Text(
                reg,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: checked ? FontWeight.w800 : FontWeight.w600,
                  color: _textPrimary,
                  fontFamily: 'Roboto',
                ),
              ),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) {
                    if (reg == kQuebecRegions.first) {
                      _wizardRegions = {kQuebecRegions.first};
                    } else {
                      _wizardRegions
                        ..remove(kQuebecRegions.first)
                        ..add(reg);
                    }
                  } else {
                    _wizardRegions.remove(reg);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================================================
  // PERSONAL NOTES & DICTAPHONE VIEW
  // ==========================================================================
  Widget _buildPersonalNotesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_isFr ? 'Carnet De Notes & Mémos Vocaux' : 'Personal Notes & Voice Memos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isRecordingAudio ? CivicPalette.vermilion : _cardBorder,
              width: _cardBorderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRecordingAudio
                          ? CivicPalette.vermilion.withValues(alpha: 0.2)
                          : CivicPalette.signalYellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isRecordingAudio ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isRecordingAudio ? CivicPalette.vermilion : CivicPalette.signalYellow,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isFr ? 'Dictaphone d’Urgence (Mémo Vocal)' : 'Emergency Dictaphone (Voice Memo)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto')),
                        const SizedBox(height: 2),
                        Text(_isFr ? 'Stocké localement sur l’appareil en toute confidentialité' : 'Stored locally on your device in full privacy',
                            style: TextStyle(fontSize: 12, color: _textMuted, fontFamily: 'Roboto')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_isRecordingAudio) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: CivicPalette.vermilion, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      'ENREGISTREMENT EN COURS : ${_recordSeconds.toString().padLeft(2, '0')}s',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: CivicPalette.vermilion, fontFamily: 'sans-serif-condensed'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CivicPalette.vermilion,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _stopVoiceRecording,
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: Text(_isFr ? 'ARRÊTER ET ENREGISTRER LE MÉMO' : 'STOP & SAVE MEMO',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
                ),
              ] else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CivicPalette.signalYellow,
                    foregroundColor: CivicPalette.darkBg,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _startVoiceRecording,
                  icon: const Icon(Icons.mic_rounded, size: 18),
                  label: Text(_isFr ? 'DÉMARRER UN MÉMO VOCAL' : 'START VOICE MEMO',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder, width: _cardBorderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _noteTitleController,
                style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary, fontFamily: 'Roboto'),
                decoration: InputDecoration(
                  hintText: _isFr ? 'Titre de la note écrite...' : 'Written note title...',
                  hintStyle: TextStyle(color: _textMuted, fontSize: 13, fontFamily: 'Roboto'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteBodyController,
                maxLines: 3,
                style: TextStyle(color: _textPrimary, fontSize: 13.5, fontFamily: 'Roboto'),
                decoration: InputDecoration(
                  hintText: _isFr ? 'Détails, dates, numéros de dossier...' : 'Details, dates, case numbers...',
                  hintStyle: TextStyle(color: _textMuted, fontSize: 13, fontFamily: 'Roboto'),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bg,
                  foregroundColor: _textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                  ),
                ),
                onPressed: _addPersonalNote,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(_isFr ? 'Enregistrer la note écrite' : 'Save written note',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _isFr ? 'Mes Notes & Mémos (${_notes.length})' : 'My Notes & Memos (${_notes.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            if (_notes.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: CivicPalette.signalYellow.withValues(alpha: 0.15),
                  foregroundColor: _accentText,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: CivicPalette.signalYellow.withValues(alpha: 0.5)),
                  ),
                ),
                onPressed: _copyAllNotes,
                icon: Icon(Icons.copy_all_rounded, size: 16, color: _accentText),
                label: Text(
                  _isFr ? 'Copier toutes mes notes' : 'Copy all notes',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: _accentText,
                    fontFamily: 'sans-serif-condensed',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_notes.isEmpty)
          Text(_isFr ? 'Aucune note pour le moment.' : 'No notes yet.', style: TextStyle(color: _textMuted, fontFamily: 'Roboto'))
        else
          Column(
            children: _notes.map((note) {
              final isPlaying = _playingAudioPath == note.audioPath;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _cardBorder, width: _cardBorderWidth),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _textPrimary, fontFamily: 'Roboto')),
                          const SizedBox(height: 2),
                          Text(note.dateStr, style: TextStyle(fontSize: 11, color: _accentText, fontWeight: FontWeight.w800, fontFamily: 'Roboto')),
                          if (note.content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(note.content, style: TextStyle(fontSize: 13, color: _textMuted, fontFamily: 'Roboto')),
                          ],
                          if (note.audioPath != null) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPlaying ? CivicPalette.vermilion : CivicPalette.signalYellow,
                                foregroundColor: isPlaying ? Colors.white : CivicPalette.darkBg,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => _playVoiceNote(note.audioPath!),
                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
                              label: Text(
                                isPlaying ? 'PAUSE' : (_isFr ? 'ÉCOUTER LE MÉMO' : 'PLAY VOICE MEMO'),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, fontFamily: 'sans-serif-condensed'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: CivicPalette.vermilion),
                      onPressed: () => _deletePersonalNote(note.id),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ==========================================================================
  // USEFUL DOCUMENTS VIEW (À VENIR)
  // ==========================================================================
  Widget _buildUsefulDocsView() {
    final badgeTextColor = widget.isDark ? CivicPalette.signalYellow : const Color(0xFF856400);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isFr ? 'Guides & Fiches Pratiques' : 'Guides & Practical Sheets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto'),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder, width: _cardBorderWidth),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? CivicPalette.yellowSubtle
                      : CivicPalette.signalYellow.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: CivicPalette.signalYellow.withValues(alpha: 0.5)),
                ),
                child: Icon(Icons.folder_rounded, size: 32, color: badgeTextColor),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? CivicPalette.yellowSubtle
                      : CivicPalette.signalYellow.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CivicPalette.signalYellow.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _isFr ? 'À VENIR' : 'COMING SOON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: badgeTextColor,
                    letterSpacing: 0.8,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isFr
                    ? 'Cette section sera disponible dans une prochaine mise à jour.'
                    : 'This section will be available in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                  height: 1.4,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MORE VIEW
  // ==========================================================================
  Widget _buildMoreView() {
    final isSystemTheme = widget.themeMode == ThemeMode.system;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_isFr ? 'Plus D’Options & Support' : 'More Options & Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto')),
        const SizedBox(height: 12),
        _buildMoreCard(
          icon: Icons.settings_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Paramètres, Données & Accessibilité' : 'Settings, Data & Accessibility',
          subtitle: isSystemTheme
              ? (_isFr
              ? 'Thème du téléphone, synchronisation et options d’accessibilité'
              : 'Device theme, online data sync, and accessibility options')
              : (_isFr
              ? 'Thème, synchronisation des données et options d’accessibilité'
              : 'Theme, online data sync, and accessibility options'),
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.signalYellow,
                foregroundColor: CivicPalette.darkBg,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                await _loadCachedAndRemoteData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: CivicPalette.signalYellow,
                    behavior: SnackBarBehavior.floating,
                    content: Text(_isFr ? 'Actualisé avec succès !' : 'Data updated successfully !',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: CivicPalette.darkBg)),
                  ),
                );
              },
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text(_isFr ? 'Actualiser les données en ligne' : 'Refresh online data',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _bg,
                foregroundColor: _textPrimary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                ),
              ),
              onPressed: widget.onToggleDark,
              icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18),
              label: Text(
                widget.isDark
                    ? (_isFr ? 'Passer en mode clair' : 'Switch to light mode')
                    : (_isFr ? 'Passer en mode sombre' : 'Switch to dark mode'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
              ),
            ),
            if (!isSystemTheme) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: widget.onUseSystemTheme,
                  icon: Icon(Icons.smartphone_rounded, size: 16, color: _accentText),
                  label: Text(
                    _isFr ? 'Utiliser le thème du téléphone' : 'Use device theme',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _accentText,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _bg,
                foregroundColor: _textPrimary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                ),
              ),
              onPressed: _openAccessibilitySheet,
              icon: const Icon(Icons.accessibility_new_rounded, size: 18, color: CivicPalette.signalYellow),
              label: Text(
                _isFr ? 'Options d’accessibilité' : 'Accessibility Options',
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.add_location_alt_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Ajouter une ressource locale' : 'Add Local Resource',
          subtitle: _isFr
              ? 'Enregistrer un contact personnel ou proposer un organisme à Indexocial'
              : 'Save a personal contact or suggest an organization to Indexocial',
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.signalYellow,
                foregroundColor: CivicPalette.darkBg,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _openAddResourceSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                _isFr ? 'Ouvrir le formulaire d’ajout' : 'Open Add Resource Form',
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.explore_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Tour de l’application' : 'App Tour & Features',
          subtitle: _isFr
              ? 'Visite guidée rapide des fonctionnalités d’Indexocial QC'
              : 'Quick guided walkthrough of Indexocial QC features',
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.signalYellow,
                foregroundColor: CivicPalette.darkBg,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _openAppTourSheet,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: Text(
                _isFr ? 'Lancer le tour de l’application' : 'Start App Tour',
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.vibration_rounded,
          iconColor: CivicPalette.vermilion,
          title: _isFr ? 'Mode « Urgence Discrète »' : 'Panic / Quick Hide Mode',
          subtitle: _isFr ? 'Secouez le téléphone pour masquer l’application' : 'Shake device to instantly hide app',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: CivicPalette.signalYellow,
              activeTrackColor: CivicPalette.yellowSubtle,
              title: Text(_isFr ? 'Détection de secousse active' : 'Shake detection active',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textPrimary, fontFamily: 'Roboto')),
              subtitle: Text(
                _isFr
                    ? 'Un geste rapide de secousse redirige immédiatement vers Google.ca.'
                    : 'A quick shake gesture instantly redirects to Google.ca.',
                style: TextStyle(fontSize: 11.5, color: _textMuted, fontFamily: 'Roboto'),
              ),
              value: _enableShakeHide,
              onChanged: (val) => setState(() => _enableShakeHide = val),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.vermilion,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _quickHideEmergency,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(_isFr ? 'Tester la sortie rapide (✕ HIDE)' : 'Test Quick Hide (✕ HIDE)',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.support_agent_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Support Technique & Signalement' : 'Technical Support & Reporting',
          subtitle: _isFr ? 'Signaler un bogue ou proposer une ressource' : 'Report a bug or suggest a resource',
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.signalYellow,
                foregroundColor: CivicPalette.darkBg,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _showSupportContactDialog,
              icon: const Icon(Icons.email_rounded, size: 18),
              label: Text(_isFr ? 'Contacter le support' : 'Contact Support',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.local_cafe_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Faire un don (Ko-fi)' : 'Donate (Ko-fi)',
          subtitle: _isFr
              ? 'Indexocial est gratuit et sans publicité. Soutenez le développement de l’app !'
              : 'Indexocial is free and ad-free. Support the development of the app!',
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CivicPalette.signalYellow,
                foregroundColor: CivicPalette.darkBg,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => _launchUri(_kofiSupportUrl),
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: Text(
                _isFr ? 'Soutenir sur Ko-fi' : 'Support on Ko-fi',
                style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.account_balance_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Sources officielles' : 'Official Sources',
          subtitle: _isFr
              ? 'Application indépendante (non gouvernementale). Liens vers les portails officiels :'
              : 'Independent app (non-government). Links to official portals:',
          children: [
            _buildOfficialSourceButton(
              label: _isFr ? 'Gouvernement du Québec (quebec.ca)' : 'Government of Quebec (quebec.ca)',
              url: _quebecCaUrl,
            ),
            const SizedBox(height: 8),
            _buildOfficialSourceButton(
              label: _isFr ? 'Tribunal administratif du logement (tal.gouv.qc.ca)' : 'Rental Tribunal (tal.gouv.qc.ca)',
              url: _talGovQcUrl,
            ),
            const SizedBox(height: 8),
            _buildOfficialSourceButton(
              label: _isFr ? 'Ligne d’aide 988 (988.ca)' : 'Suicide Crisis Helpline 988 (988.ca)',
              url: _suicideHelpline988Url,
            ),
            const SizedBox(height: 8),
            _buildOfficialSourceButton(
              label: _isFr ? 'Environnement Canada — Météo (meteo.gc.ca)' : 'Environment Canada — Weather (meteo.gc.ca)',
              url: _meteoGcUrl,
            ),
            const SizedBox(height: 10),
            Text(
              _isFr
                  ? 'Répertoire communautaire (organisme non gouvernemental) : 211qc.ca'
                  : 'Community directory (non-government organization): 211qc.ca',
              style: TextStyle(fontSize: 11.5, color: _textMuted, fontFamily: 'Roboto'),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => _launchUri(_twoOneOneQcUrl),
              icon: Icon(Icons.open_in_new_rounded, size: 15, color: _accentText),
              label: Text(
                'https://www.211qc.ca',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _accentText,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMoreCard(
          icon: Icons.gavel_rounded,
          iconColor: CivicPalette.signalYellow,
          title: _isFr ? 'Conditions & Confidentialité' : 'Terms & Privacy',
          subtitle: _isFr ? 'Avis légaux et politique de confidentialité' : 'Legal notices and privacy policy',
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _bg,
                foregroundColor: _textPrimary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                ),
              ),
              onPressed: () => setState(() => _hasAcceptedDisclaimer = false),
              icon: const Icon(Icons.description_rounded, size: 18),
              label: Text(_isFr ? 'Lire les conditions d’utilisation' : 'Read Terms of Use',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _bg,
                foregroundColor: _textPrimary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
                ),
              ),
              onPressed: _openPrivacyPolicyModal,
              icon: const Icon(Icons.privacy_tip_rounded, size: 18),
              label: Text(_isFr ? 'Politique de confidentialité' : 'Privacy Policy',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'sans-serif-condensed')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficialSourceButton({required String label, required String url}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
        minimumSize: const Size(double.infinity, 42),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _cardBorder, width: _cardBorderWidth),
        ),
      ),
      onPressed: () => _launchUri(url),
      icon: Icon(Icons.open_in_new_rounded, size: 16, color: _accentText),
      label: Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _textPrimary, fontFamily: 'Roboto'),
        ),
      ),
    );
  }

  Widget _buildMoreCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder, width: _cardBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _textPrimary, fontFamily: 'Roboto')),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: _textMuted, fontFamily: 'Roboto')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}