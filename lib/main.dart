import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Brightness, ColorScheme, LinearProgressIndicator, ThemeData, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history.dart';
import 'l10n/generated/app_localizations.dart';
import 'rolling_stock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadRollingStockCatalog();
  runApp(const WakareeruApp());
}

const String appDisplayName = 'Wakareeru';
const String defaultApiBaseUrl = 'http://159.89.193.182:8787';
const Color wakareeruBlue = Color(0xFF007AFF);
const Color wakareeruMint = Color(0xFF00B7A8);
const Color wakareeruAmber = Color(0xFFFF9F0A);
const Color wakareeruViolet = Color(0xFFAF52DE);
const double appCornerRadius = 28;
const double cardCornerRadius = appCornerRadius;
const double controlCornerRadius = 14;

/// 识别结果的强调色：高置信用薄荷绿，低置信用琥珀，易混淆用紫色。
Color subjectAccent(DetectedSubject subject) {
  if (subject.isConfused) {
    return wakareeruViolet;
  }
  if (subject.isLowConfidence) {
    return wakareeruAmber;
  }
  return wakareeruMint;
}

/// 分类状态对应的短标签，确定无误时返回 null（不显示徽标）。
String? subjectStatusLabel(BuildContext context, DetectedSubject subject) {
  final strings = l10n(context);
  if (subject.isConfused) {
    return strings.statusConfused;
  }
  switch (subject.classificationStatus) {
    case 'classified':
      return null;
    case 'low_confidence':
      return strings.statusLowConfidence;
    case 'no_detection':
      return strings.statusNoDetection;
    case 'unknown':
      return null;
    default:
      return subject.classificationStatus;
  }
}

/// 识别对象的「身份色」：运营公司色优先，否则车辆类别色。
/// 这是駅名標式色带与检测框用的颜色，承载铁道辨识度。
Color subjectStockColor(DetectedSubject subject) {
  return resolveStockColor(
    operator: subject.operator,
    type: subject.stockType,
    powerType: subject.powerType,
    label: subject.displayTitle,
  );
}

List<(String, String)> predictionMetadataRows(
  BuildContext context,
  PredictionEntry entry, {
  bool detailed = false,
}) {
  final strings = l10n(context);
  final rows = <(String, String)>[];
  if (entry.operator != null) {
    rows.add((strings.collectionOperator, entry.operator!));
  }
  if (detailed && entry.operatorJp != null) {
    rows.add(('operator_jp', entry.operatorJp!));
  }
  if (detailed && entry.operatorEn != null) {
    rows.add(('operator_en', entry.operatorEn!));
  }
  if (entry.stockType != null) {
    rows.add((detailed ? 'type' : strings.vehicleType, entry.stockType!));
  }
  if (entry.powerType != null) {
    rows.add((detailed ? 'power_type' : strings.powerType, entry.powerType!));
  }
  if (detailed && entry.fullName != null) {
    rows.add(('full_name', entry.fullName!));
  }
  if (detailed && entry.wikiTitle != null) {
    rows.add(('wiki_title', entry.wikiTitle!));
  }
  if (entry.bandai != null) {
    rows.add((detailed ? 'bandai' : strings.bandai, entry.bandai!));
  }
  if (entry.submodel != null) {
    rows.add((detailed ? 'submodel' : strings.submodel, entry.submodel!));
  }
  if (entry.specialLivery != null) {
    rows.add((
      detailed ? 'special_livery' : strings.livery,
      entry.specialLivery!,
    ));
  }
  if (entry.specialFormation != null) {
    rows.add((
      detailed ? 'special_formation' : strings.formation,
      entry.specialFormation!,
    ));
  }
  return rows;
}

bool isAppDark(BuildContext context) {
  return CupertinoTheme.of(context).brightness == Brightness.dark;
}

AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context);

Color adaptiveColor(BuildContext context, Color light, Color dark) {
  return isAppDark(context) ? dark : light;
}

String _formatRecordTime(BuildContext context, DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}/${two(time.month)}/${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

class WakareeruApp extends StatefulWidget {
  const WakareeruApp({super.key});

  @override
  State<WakareeruApp> createState() => _WakareeruAppState();
}

class _WakareeruAppState extends State<WakareeruApp> {
  static const String _localePreferenceKey = 'wakareeru_locale_code';

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocalePreference();
  }

  void _setThemeMode(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
  }

  Future<void> _loadLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePreferenceKey);
    if (!mounted || code == null || code.isEmpty) {
      return;
    }
    setState(() => _locale = Locale(code));
  }

  Future<void> _setLocale(Locale? locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localePreferenceKey);
    } else {
      await prefs.setString(_localePreferenceKey, locale.languageCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: wakareeruBlue,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: wakareeruBlue,
      brightness: Brightness.dark,
    );

    return AdaptiveApp(
      title: appDisplayName,
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      materialLightTheme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
      ),
      materialDarkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      cupertinoLightTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: wakareeruBlue,
        scaffoldBackgroundColor: Color(0xFFF2F4F8),
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: wakareeruBlue,
      ),
      cupertino: (context, target) =>
          const CupertinoAppData(debugShowCheckedModeBanner: false),
      material: (context, target) =>
          const MaterialAppData(debugShowCheckedModeBanner: false),
      home: WakareeruShell(
        themeMode: _themeMode,
        locale: _locale,
        onThemeModeChanged: _setThemeMode,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}

class WakareeruShell extends StatefulWidget {
  const WakareeruShell({
    super.key,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<WakareeruShell> createState() => _WakareeruShellState();
}

class _WakareeruShellState extends State<WakareeruShell> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _apiBaseController = TextEditingController(
    text: const String.fromEnvironment(
      'WAKAREERU_API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    ),
  );

  final HistoryStore _history = HistoryStore();

  int _selectedIndex = 0;
  int _topK = 5;
  XFile? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;
  GatewayInferenceResult? _result;
  bool _savedCurrent = false;

  @override
  void initState() {
    super.initState();
    _history.load();
  }

  @override
  void dispose() {
    _apiBaseController.dispose();
    _history.dispose();
    super.dispose();
  }

  /// 把识别结果的每个对象保存到本地记录。
  Future<void> _saveResultToHistory(
    GatewayInferenceResult result, {
    Uint8List? thumbnailBytes,
  }) async {
    final subjects = result.subjects;
    if (subjects.isEmpty || _savedCurrent) {
      return;
    }
    final base = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final best = subject.best;
      if (best == null) {
        continue;
      }
      final recordId = base + i;
      final thumbnailPath = thumbnailBytes == null
          ? null
          : await _writeHistoryThumbnail(thumbnailBytes, recordId);
      debugPrint(
        '[wakareeru history] add id=$recordId label=${best.label} '
        'thumbnail=${thumbnailPath ?? 'null'}',
      );
      await _history.add(
        HistoryRecord(
          id: recordId,
          label: best.label,
          confidence: best.score,
          operatorJp: best.operatorJp,
          operatorEn: best.operatorEn,
          powerType: best.powerType,
          wikiTitle: best.wikiTitle,
          bandai: best.bandai,
          submodel: best.submodel,
          specialFormation: best.specialFormation,
          specialLivery: best.specialLivery,
          thumbnailPath: thumbnailPath,
        ),
      );
    }
    HapticFeedback.mediumImpact();
    setState(() => _savedCurrent = true);
  }

  Future<void> _saveCurrentToHistory() async {
    final result = _result;
    if (result == null) {
      return;
    }
    final image = _selectedImage;
    final thumbnailBytes = image == null
        ? null
        : (await _prepareInferenceImage(image, l10n(context))).bytes;
    await _saveResultToHistory(result, thumbnailBytes: thumbnailBytes);
  }

  Future<String?> _writeHistoryThumbnail(Uint8List bytes, int id) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 640);
      final frame = await codec.getNextFrame();
      try {
        final pngData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (pngData == null) {
          return null;
        }
        final thumbDir = await _historyThumbnailDirectory();
        if (!await thumbDir.exists()) {
          await thumbDir.create(recursive: true);
        }
        final file = File('${thumbDir.path}/$id.png');
        await file.writeAsBytes(
          pngData.buffer.asUint8List(
            pngData.offsetInBytes,
            pngData.lengthInBytes,
          ),
          flush: true,
        );
        debugPrint(
          '[wakareeru history] thumbnail written id=$id path=${file.path} '
          'sourceBytes=${bytes.length} pngBytes=${pngData.lengthInBytes}',
        );
        return file.path;
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    } catch (error) {
      debugPrint('[wakareeru history] thumbnail failed id=$id: $error');
      return null;
    }
  }

  Future<Directory> _historyThumbnailDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return Directory('${dir.path}/history_thumbnails');
    } catch (error) {
      debugPrint(
        '[wakareeru history] documents directory unavailable, '
        'using temp fallback: $error',
      );
      return Directory(
        '${Directory.systemTemp.path}/wakareeru_history_thumbnails',
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (image == null) {
      return;
    }
    setState(() {
      _selectedImage = image;
      _errorMessage = null;
      _result = null;
      _savedCurrent = false;
    });
  }

  Future<void> _runInference() async {
    final image = _selectedImage;
    if (image == null) {
      setState(() => _errorMessage = l10n(context).selectImageFirst);
      return;
    }

    final endpoint = _resolveEndpoint(_apiBaseController.text.trim());
    if (endpoint == null) {
      setState(() => _errorMessage = l10n(context).invalidApiUrl);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _savedCurrent = false;
    });

    try {
      final preparedImage = await _prepareInferenceImage(image, l10n(context));
      _logUploadDebug('prepared', preparedImage.debugMap);
      final request = http.MultipartRequest('POST', endpoint)
        ..fields['top_k'] = _topK.toString();

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          preparedImage.bytes,
          filename: preparedImage.filename,
          contentType: preparedImage.contentType,
        ),
      );
      _logUploadDebug('request', {
        'endpoint': endpoint.toString(),
        'top_k': _topK,
        'filename': preparedImage.filename,
        'contentType': preparedImage.contentType.toString(),
        'bytes': preparedImage.bytes.length,
        'signature': _byteSignature(preparedImage.bytes),
      });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      _logUploadDebug('response', {
        'status': response.statusCode,
        'reasonPhrase': response.reasonPhrase,
        'contentType': response.headers['content-type'],
        'bodyPreview': _shortDebugText(responseBody),
      });
      final decoded = responseBody.isEmpty ? null : jsonDecode(responseBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GatewayApiException.fromPayload(response.statusCode, decoded);
      }
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Gateway response is not a JSON object.');
      }

      final result = GatewayInferenceResult.fromJson(decoded);
      _logResultMetadata(result);
      setState(() => _result = result);
      await _saveResultToHistory(result, thumbnailBytes: preparedImage.bytes);
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<_PreparedInferenceImage> _prepareInferenceImage(
    XFile image,
    AppLocalizations strings,
  ) async {
    final bytes = await image.readAsBytes();
    final originalKind = _imageKind(bytes);
    _logUploadDebug('picked', {
      'name': image.name,
      'path': image.path,
      'mimeType': image.mimeType,
      'bytes': bytes.length,
      'kind': originalKind,
      'signature': _byteSignature(bytes),
    });
    if (originalKind != null) {
      return _PreparedInferenceImage(
        bytes: bytes,
        filename: image.name,
        contentType: _contentTypeForKind(originalKind),
        converted: false,
        originalKind: originalKind,
      );
    }

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    try {
      final pngData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngData == null) {
        throw FormatException(strings.unsupportedImageConversion);
      }
      final convertedBytes = pngData.buffer.asUint8List(
        pngData.offsetInBytes,
        pngData.lengthInBytes,
      );
      return _PreparedInferenceImage(
        bytes: convertedBytes,
        filename: _pngFilenameFor(image.name),
        contentType: MediaType('image', 'png'),
        converted: true,
        originalKind: originalKind ?? 'unsupported',
      );
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  String? _imageKind(Uint8List bytes) {
    if (_hasJpegSignature(bytes)) {
      return 'jpeg';
    }
    if (_hasPngSignature(bytes)) {
      return 'png';
    }
    if (_hasWebpSignature(bytes)) {
      return 'webp';
    }
    return null;
  }

  MediaType _contentTypeForKind(String kind) => switch (kind) {
    'jpeg' => MediaType('image', 'jpeg'),
    'png' => MediaType('image', 'png'),
    'webp' => MediaType('image', 'webp'),
    _ => MediaType('application', 'octet-stream'),
  };

  bool _hasJpegSignature(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  bool _hasPngSignature(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  bool _hasWebpSignature(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }

  String _byteSignature(Uint8List bytes, [int maxBytes = 16]) {
    return bytes
        .take(math.min(bytes.length, maxBytes))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  String _shortDebugText(String text, [int maxLength = 500]) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) {
      return compact;
    }
    return '${compact.substring(0, maxLength)}...';
  }

  void _logUploadDebug(String stage, Map<String, Object?> values) {
    debugPrint('[wakareeru upload][$stage] ${jsonEncode(values)}');
  }

  void _logResultMetadata(GatewayInferenceResult result) {
    for (var i = 0; i < result.subjects.length; i++) {
      final best = result.subjects[i].best;
      if (best == null) {
        debugPrint('[wakareeru meta][$i] no best prediction');
        continue;
      }
      final values = {
        'label': best.label,
        'score': best.score,
        'wiki_title': best.wikiTitle,
        'power_type': best.powerType,
        'stock_type': best.stockType,
        'operator_jp': best.operatorJp,
        'operator_en': best.operatorEn,
        'submodel': best.submodel,
        'bandai': best.bandai,
        'special_formation': best.specialFormation,
        'special_livery': best.specialLivery,
      };
      debugPrint('[wakareeru meta][$i] ${jsonEncode(values)}');
    }
  }

  String _pngFilenameFor(String filename) {
    final fallback = filename.trim().isEmpty ? 'wakareeru-image' : filename;
    final dotIndex = fallback.lastIndexOf('.');
    final basename = dotIndex <= 0 ? fallback : fallback.substring(0, dotIndex);
    return '$basename.png';
  }

  Uri? _resolveEndpoint(String baseUrl) {
    if (baseUrl.isEmpty) {
      return null;
    }
    final Uri uri;
    try {
      uri = Uri.parse(baseUrl);
    } on FormatException {
      return null;
    }
    if (!uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    if (uri.path.isEmpty || uri.path == '/') {
      return uri.replace(path: '/v1/infer');
    }
    if (uri.path.endsWith('/v1/infer')) {
      return uri;
    }
    return uri.replace(
      path: '${uri.path.replaceAll(RegExp(r'/+$'), '')}/v1/infer',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RecognitionPage(
        image: _selectedImage,
        result: _result,
        errorMessage: _errorMessage,
        isLoading: _isLoading,
        savedCurrent: _savedCurrent,
        onPickCamera: () => _pickImage(ImageSource.camera),
        onPickGallery: () => _pickImage(ImageSource.gallery),
        onRunInference: _runInference,
        onSaveToHistory: _saveCurrentToHistory,
      ),
      HistoryPage(
        history: _history,
        onStartRecognition: () => setState(() => _selectedIndex = 0),
      ),
      SettingsPage(
        apiBaseController: _apiBaseController,
        themeMode: widget.themeMode,
        locale: widget.locale,
        onThemeModeChanged: widget.onThemeModeChanged,
        onLocaleChanged: widget.onLocaleChanged,
        topK: _topK,
        onTopKChanged: (value) => setState(() => _topK = value),
        onChanged: () => setState(() {}),
      ),
    ];

    final inactiveColor = adaptiveColor(
      context,
      CupertinoColors.inactiveGray,
      const Color(0xFF8E8E93),
    );
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final tabBarHeight = bottomInset > 0 ? 56.0 : 50.0;
    final strings = l10n(context);
    final cupertinoItems = [
      BottomNavigationBarItem(
        icon: const Icon(CupertinoIcons.sparkles),
        activeIcon: const Icon(CupertinoIcons.sparkles),
        label: strings.tabRecognize,
      ),
      BottomNavigationBarItem(
        icon: const Icon(CupertinoIcons.square_stack_3d_up),
        activeIcon: const Icon(CupertinoIcons.square_stack_3d_up_fill),
        label: strings.tabHistory,
      ),
      BottomNavigationBarItem(
        icon: const Icon(CupertinoIcons.slider_horizontal_3),
        activeIcon: const Icon(CupertinoIcons.slider_horizontal_3),
        label: strings.tabSettings,
      ),
    ];

    return AdaptiveScaffold(
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        useNativeBottomBar: true,
        selectedItemColor: wakareeruBlue,
        unselectedItemColor: inactiveColor,
        cupertinoTabBar: CupertinoTabBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          activeColor: wakareeruBlue,
          inactiveColor: inactiveColor,
          height: tabBarHeight,
          items: cupertinoItems,
        ),
        items: [
          AdaptiveNavigationDestination(
            icon: 'sparkles.rectangle.stack.fill',
            selectedIcon: 'sparkles.rectangle.stack.fill',
            label: strings.tabRecognize,
          ),
          AdaptiveNavigationDestination(
            icon: 'tram.fill',
            selectedIcon: 'tram.fill',
            label: strings.tabHistory,
          ),
          AdaptiveNavigationDestination(
            icon: 'slider.horizontal.3',
            selectedIcon: 'slider.horizontal.3',
            label: strings.tabSettings,
          ),
        ],
      ),
      minimizeBehavior: TabBarMinimizeBehavior.never,
      enableBlur: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }
}

class _PreparedInferenceImage {
  const _PreparedInferenceImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.converted,
    required this.originalKind,
  });

  final Uint8List bytes;
  final String filename;
  final MediaType contentType;
  final bool converted;
  final String originalKind;

  Map<String, Object?> get debugMap => {
    'filename': filename,
    'contentType': contentType.toString(),
    'converted': converted,
    'originalKind': originalKind,
    'bytes': bytes.length,
  };
}

class RecognitionPage extends StatelessWidget {
  const RecognitionPage({
    super.key,
    required this.image,
    required this.result,
    required this.errorMessage,
    required this.isLoading,
    required this.savedCurrent,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRunInference,
    required this.onSaveToHistory,
  });

  final XFile? image;
  final GatewayInferenceResult? result;
  final String? errorMessage;
  final bool isLoading;
  final bool savedCurrent;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRunInference;
  final VoidCallback onSaveToHistory;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final subjects = result?.subjects ?? const <DetectedSubject>[];
    return AppBackdrop(
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, topInset + 18, 18, 118),
        children: [
          const AppWordmark(),
          const SizedBox(height: 18),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ImagePreview(
                  image: image,
                  subjects: subjects,
                  onSubjectTap: (subject) =>
                      showSubjectDetail(context, subject),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AdaptiveButton.child(
                          onPressed: isLoading ? null : onPickCamera,
                          style: AdaptiveButtonStyle.glass,
                          size: AdaptiveButtonSize.large,
                          child: ButtonLabel(
                            icon: CupertinoIcons.camera_fill,
                            text: strings.camera,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdaptiveButton.child(
                          onPressed: isLoading ? null : onPickGallery,
                          style: AdaptiveButtonStyle.glass,
                          size: AdaptiveButtonSize.large,
                          child: ButtonLabel(
                            icon: CupertinoIcons.photo_on_rectangle,
                            text: strings.gallery,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: AdaptiveButton.child(
                    onPressed: isLoading ? null : onRunInference,
                    style: AdaptiveButtonStyle.prominentGlass,
                    color: wakareeruBlue,
                    size: AdaptiveButtonSize.large,
                    child: isLoading
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : ButtonLabel(
                            icon: CupertinoIcons.bolt_fill,
                            text: strings.startRecognition,
                            color: CupertinoColors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            StatusBanner(message: errorMessage!, isError: true),
          ],
          if (isLoading) ...[
            const SizedBox(height: 16),
            ResultPlaceholder(message: strings.recognizing),
          ] else if (subjects.isNotEmpty) ...[
            const SizedBox(height: 18),
            ResultHeader(
              count: subjects.length,
              saved: savedCurrent,
              onSave: onSaveToHistory,
            ),
            const SizedBox(height: 12),
            for (final subject in subjects) ...[
              VehicleCard(
                subject: subject,
                onTap: () => showSubjectDetail(context, subject),
              ),
              const SizedBox(height: 12),
            ],
          ] else if (result != null) ...[
            const SizedBox(height: 16),
            ResultPlaceholder(
              message: strings.noVehicleDetected,
              isEmpty: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// 識別記録（本地收藏）页：集邮式网格 + 收藏统计。
class HistoryPage extends StatelessWidget {
  const HistoryPage({
    super.key,
    required this.history,
    required this.onStartRecognition,
  });

  final HistoryStore history;
  final VoidCallback onStartRecognition;

  void _confirmClear(BuildContext context) {
    final strings = l10n(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(strings.clearHistoryTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(strings.clearHistoryMessage),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              history.clear();
              Navigator.of(dialogContext).pop();
            },
            child: Text(strings.clear),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return AppBackdrop(
      child: AnimatedBuilder(
        animation: history,
        builder: (context, _) {
          final records = history.records;
          return ListView(
            padding: EdgeInsets.fromLTRB(18, topInset + 18, 18, 118),
            children: [
              Row(
                children: [
                  Expanded(child: PageTitle(title: strings.historyTitle)),
                  if (records.isNotEmpty)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      onPressed: () => _confirmClear(context),
                      child: Text(
                        strings.clear,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (!history.isLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (records.isEmpty)
                _EmptyHistory(onStart: onStartRecognition)
              else ...[
                CollectionStats(history: history),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                  children: [
                    for (final record in records)
                      HistoryCard(
                        record: record,
                        onTap: () =>
                            showHistoryRecordDetail(context, record, history),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 收藏统计（系列 / 事業者 / 記録 计数）。
class CollectionStats extends StatelessWidget {
  const CollectionStats({super.key, required this.history});

  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          _StatCell(
            value: history.seriesCount,
            label: l10n(context).seriesCountLabel,
          ),
          _StatCell(
            value: history.operatorCount,
            label: l10n(context).operatorCountLabel,
          ),
          _StatCell(
            value: history.recordCount,
            label: l10n(context).recordCountLabel,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}

/// 单条识别记录卡（集邮卡）。
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.record, required this.onTap});

  final HistoryRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final color = resolveStockColor(
      operator: record.operator,
      type: record.stockType,
      powerType: record.powerTypeEffective,
      label: record.label,
    );
    final category = stockCategoryInfo(
      resolveCategory(
        type: record.stockType,
        powerType: record.powerTypeEffective,
        label: record.label,
      ),
    );
    final parts = parseSeries(record.label);
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    final time = record.time;
    final subtitle = '${record.operator ?? category.jp} · ${category.jp}';
    final timeText = _formatRecordTime(context, time);
    final fill = adaptiveColor(
      context,
      CupertinoColors.white.withValues(alpha: 0.78),
      const Color(0xFF161B26).withValues(alpha: 0.92),
    );
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.10)
        : CupertinoColors.white.withValues(alpha: 0.5);

    return RoundedCardSurface(
      fill: fill,
      borderColor: borderColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HistoryThumbnail(path: record.thumbnailPath, fallback: color),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 32,
                      color: color.withValues(alpha: 0.92),
                      alignment: Alignment.center,
                      child: Icon(
                        category.icon,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parts.base,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n(context).confidenceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ),
                      Text(
                        '${(record.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryThumbnail extends StatelessWidget {
  const HistoryThumbnail({
    super.key,
    required this.path,
    required this.fallback,
  });

  final String? path;
  final Color fallback;

  static bool _loggedMissingPath = false;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path == null || path.isEmpty) {
      if (!_loggedMissingPath) {
        _loggedMissingPath = true;
        debugPrint(
          '[wakareeru history] thumbnail missing path for existing records; '
          'new records should get thumbnail_path after recognition',
        );
      }
      return ColoredBox(color: fallback.withValues(alpha: 0.18));
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '[wakareeru history] thumbnail render failed path=$path '
          'exists=${File(path).existsSync()} error=$error',
        );
        return ColoredBox(color: fallback.withValues(alpha: 0.18));
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      child: Column(
        children: [
          Icon(CupertinoIcons.tram_fill, size: 46, color: muted),
          const SizedBox(height: 14),
          Text(
            strings.emptyHistoryTitle,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            strings.emptyHistoryMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          CupertinoButton(
            color: wakareeruBlue,
            borderRadius: BorderRadius.circular(controlCornerRadius),
            onPressed: onStart,
            child: Text(
              strings.startRecognizingHistory,
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出本地记录的详情面板（含删除）。
void showHistoryRecordDetail(
  BuildContext context,
  HistoryRecord record,
  HistoryStore history,
) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => HistoryRecordSheet(record: record, history: history),
  );
}

class HistoryRecordSheet extends StatelessWidget {
  const HistoryRecordSheet({
    super.key,
    required this.record,
    required this.history,
  });

  final HistoryRecord record;
  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final color = resolveStockColor(
      operator: record.operator,
      type: record.stockType,
      powerType: record.powerTypeEffective,
      label: record.label,
    );
    final category = stockCategoryInfo(
      resolveCategory(
        type: record.stockType,
        powerType: record.powerTypeEffective,
        label: record.label,
      ),
    );
    final parts = parseSeries(record.label);
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    final time = record.time;
    final wikiUrl = wikipediaUrl(record.wikiTitleEffective);
    final dateText = _formatRecordTime(context, time);

    final metaRows = <(String, String)>[
      if (record.operator != null)
        (l10n(context).collectionOperator, record.operator!),
      (l10n(context).vehicleType, record.stockType ?? category.jp),
      (l10n(context).powerType, record.powerTypeEffective ?? category.jp),
      (
        l10n(context).confidenceLabel,
        '${(record.confidence * 100).toStringAsFixed(1)}%',
      ),
      if (record.bandai != null) (l10n(context).bandai, record.bandai!),
      if (record.submodel != null) (l10n(context).submodel, record.submodel!),
      if (record.specialLivery != null)
        (l10n(context).livery, record.specialLivery!),
      if (record.specialFormation != null)
        (l10n(context).formation, record.specialFormation!),
      (l10n(context).recordedAt, dateText),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12161F) : const Color(0xFFF7F9FF),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(appCornerRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: RoundedCardSurface(
                fill: adaptiveColor(
                  context,
                  CupertinoColors.white.withValues(alpha: 0.78),
                  const Color(0xFF161B26).withValues(alpha: 0.92),
                ),
                borderColor: color.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 180,
                      child: HistoryThumbnail(
                        path: record.thumbnailPath,
                        fallback: color,
                      ),
                    ),
                    Container(
                      color: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            category.icon,
                            size: 15,
                            color: CupertinoColors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            category.jp,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(record.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parts.base,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (parts.variant != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              parts.variant!,
                              style: TextStyle(
                                fontSize: 13,
                                color: muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          for (final row in metaRows)
                            _MetaRow(label: row.$1, value: row.$2),
                          if (wikiUrl != null) ...[
                            const SizedBox(height: 4),
                            _CopyLinkButton(
                              url: wikiUrl,
                              label: l10n(context).openWikipedia,
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(controlCornerRadius),
                  onPressed: () {
                    history.removeById(record.id);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    l10n(context).deleteFromHistory,
                    style: TextStyle(
                      color: CupertinoColors.systemRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.apiBaseController,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.topK,
    required this.onTopKChanged,
    required this.onChanged,
  });

  final TextEditingController apiBaseController;
  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final int topK;
  final ValueChanged<int> onTopKChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final selectedThemeIndex = switch (themeMode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };
    final selectedLocaleIndex = switch (locale?.languageCode) {
      'zh' => 1,
      'ja' => 2,
      'en' => 3,
      _ => 0,
    };
    return AppBackdrop(
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, topInset + 18, 18, 118),
        children: [
          PageTitle(title: strings.settingsTitle),
          const SizedBox(height: 18),
          const AccountCard(),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  icon: CupertinoIcons.circle_lefthalf_fill,
                  text: strings.theme,
                ),
                const SizedBox(height: 12),
                AdaptiveSegmentedControl(
                  labels: [
                    strings.themeSystem,
                    strings.themeLight,
                    strings.themeDark,
                  ],
                  selectedIndex: selectedThemeIndex,
                  onValueChanged: (index) => onThemeModeChanged(switch (index) {
                    1 => ThemeMode.light,
                    2 => ThemeMode.dark,
                    _ => ThemeMode.system,
                  }),
                  color: wakareeruBlue,
                  height: 40,
                ),
                const SizedBox(height: 18),
                SectionLabel(
                  icon: CupertinoIcons.globe,
                  text: strings.language,
                ),
                const SizedBox(height: 12),
                AdaptiveSegmentedControl(
                  labels: [
                    strings.languageSystem,
                    strings.languageChinese,
                    strings.languageJapanese,
                    strings.languageEnglish,
                  ],
                  selectedIndex: selectedLocaleIndex,
                  onValueChanged: (index) => onLocaleChanged(switch (index) {
                    1 => const Locale('zh'),
                    2 => const Locale('ja'),
                    3 => const Locale('en'),
                    _ => null,
                  }),
                  color: wakareeruBlue,
                  height: 40,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(icon: CupertinoIcons.link, text: strings.gateway),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: apiBaseController,
                  placeholder: defaultApiBaseUrl,
                  clearButtonMode: OverlayVisibilityMode.editing,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => onChanged(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: adaptiveColor(
                      context,
                      const Color(0xFFFFFFFF).withValues(alpha: 0.72),
                      const Color(0xFF1A1F2C).withValues(alpha: 0.86),
                    ),
                    borderRadius: BorderRadius.circular(controlCornerRadius),
                    border: Border.all(
                      color: adaptiveColor(
                        context,
                        const Color(0x4D3C3C43),
                        const Color(0x66AEB2BD),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                StepperRow(
                  label: 'top_k',
                  value: topK,
                  onChanged: onTopKChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  icon: CupertinoIcons.info_circle,
                  text: strings.about,
                ),
                const SizedBox(height: 12),
                InfoMetric(label: strings.appLabel, value: appDisplayName),
                const SizedBox(height: 8),
                InfoMetric(
                  label: strings.dataSource,
                  value: 'Wikipedia · Commons',
                ),
                const SizedBox(height: 8),
                const InfoMetric(
                  label: 'GitHub',
                  value: 'wakareeru-team/wakareeru',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出“即将推出”提示框，用于登录、历史等尚未实现的占位入口。
void showComingSoon(BuildContext context, String feature) {
  final strings = l10n(context);
  showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(feature),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(strings.comingSoonMessage),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.ok),
        ),
      ],
    ),
  );
}

/// 账户卡片：当前匿名使用，预留 Sign in with Apple 入口（占位）。
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            icon: CupertinoIcons.person_crop_circle,
            text: strings.account,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [wakareeruBlue, wakareeruMint],
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.person_fill,
                  color: CupertinoColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.anonymousUser,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.anonymousUserSubtitle,
                      style: TextStyle(fontSize: 13, color: muted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppleSignInButton(
            onPressed: () => showComingSoon(context, strings.signInWithApple),
          ),
        ],
      ),
    );
  }
}

/// Sign in with Apple 占位按钮。正式实现时替换为 sign_in_with_apple 包提供的
/// 官方 SignInWithAppleButton（需要原生 entitlement，故当前仅占位）。
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final background = isDark ? CupertinoColors.white : CupertinoColors.black;
    final foreground = isDark ? CupertinoColors.black : CupertinoColors.white;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderRadius: BorderRadius.circular(controlCornerRadius),
        color: background,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_fill, size: 20, color: foreground),
            const SizedBox(width: 8),
            Text(
              l10n(context).signInWithApple,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置页中可点击的功能行（图标 + 标题 + 副标题 + 右箭头）。
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: wakareeruBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF090B10), Color(0xFF111827), Color(0xFF0B1320)]
              : const [Color(0xFFF7FAFF), Color(0xFFEFF7F6), Color(0xFFF5F5FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 28,
            right: -70,
            child: SoftOrb(
              color: wakareeruMint.withValues(alpha: 0.18),
              size: 220,
            ),
          ),
          Positioned(
            top: 160,
            left: -80,
            child: SoftOrb(
              color: wakareeruBlue.withValues(alpha: 0.15),
              size: 240,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class SoftOrb extends StatelessWidget {
  const SoftOrb({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// 顶部精简标识（无玻璃框）：小 logo + 品牌名 + 一行说明。
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [wakareeruBlue, wakareeruMint],
            ),
          ),
          child: const Icon(
            CupertinoIcons.tram_fill,
            color: CupertinoColors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            appDisplayName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final fillColor = isDark
        ? const Color(0xFF171C27).withValues(alpha: 0.88)
        : const Color(0xFFF8FAFF).withValues(alpha: 0.42);
    return AdaptiveBlurView(
      blurStyle: BlurStyle.systemThinMaterial,
      borderRadius: BorderRadius.circular(appCornerRadius),
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(appCornerRadius),
          border: Border.all(
            color: isDark
                ? CupertinoColors.white.withValues(alpha: 0.12)
                : CupertinoColors.white.withValues(alpha: 0.36),
            width: 0.8,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class RoundedCardSurface extends StatelessWidget {
  const RoundedCardSurface({
    super.key,
    required this.child,
    required this.fill,
    required this.borderColor,
    this.radius = cardCornerRadius,
  });

  final Widget child;
  final Color fill;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: ColoredBox(color: fill, child: child),
      ),
    );
  }
}

/// 解码后的预览数据：原始字节 + 原图像素尺寸（用于把 bbox 映射到画布）。
class _PreviewData {
  const _PreviewData(this.bytes, this.imageSize);

  final Uint8List bytes;
  final Size imageSize;
}

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.image,
    required this.subjects,
    this.onSubjectTap,
  });

  final XFile? image;
  final List<DetectedSubject> subjects;
  final ValueChanged<DetectedSubject>? onSubjectTap;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  Future<_PreviewData>? _previewFuture;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoad();
  }

  void _maybeLoad() {
    final image = widget.image;
    if (image == null) {
      _previewFuture = null;
      _loadedPath = null;
      return;
    }
    // 仅当选择了新图片时才重新解码，避免推理完成后的重建导致闪烁。
    if (image.path != _loadedPath) {
      _loadedPath = image.path;
      _previewFuture = _loadPreview(image);
    }
  }

  Future<_PreviewData> _loadPreview(XFile file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    return _PreviewData(bytes, size);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final radius = const BorderRadius.vertical(
      top: Radius.circular(appCornerRadius),
    );

    if (widget.image == null || _previewFuture == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF04070D),
                      Color(0xFF0B1825),
                      Color(0xFF12303A),
                    ]
                  : const [
                      Color(0xFF0B1220),
                      Color(0xFF174C65),
                      Color(0xFFB4EEF1),
                    ],
            ),
            borderRadius: radius,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 22,
                child: const Icon(
                  CupertinoIcons.tram_fill,
                  color: CupertinoColors.white,
                  size: 54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: const Color(0xFF05070D),
          child: FutureBuilder<_PreviewData>(
            future: _previewFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }
              final data = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final canvas = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  // 以 BoxFit.contain 计算图片在画布中的实际显示矩形，
                  // 再把原图像素坐标的 bbox 映射进去。
                  final fit = _containRect(data.imageSize, canvas);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(data.bytes, fit: BoxFit.contain),
                      for (final subject in widget.subjects)
                        if (subject.box != null)
                          SubjectBoxOverlay(
                            subject: subject,
                            rect: _mapBox(subject.box!, data.imageSize, fit),
                            onTap: widget.onSubjectTap == null
                                ? null
                                : () => widget.onSubjectTap!(subject),
                          ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// BoxFit.contain：返回图片在画布中居中显示的矩形（含 letterbox 偏移）。
Rect _containRect(Size imageSize, Size canvas) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return Offset.zero & canvas;
  }
  final scale = math.min(
    canvas.width / imageSize.width,
    canvas.height / imageSize.height,
  );
  final destW = imageSize.width * scale;
  final destH = imageSize.height * scale;
  return Rect.fromLTWH(
    (canvas.width - destW) / 2,
    (canvas.height - destH) / 2,
    destW,
    destH,
  );
}

/// 把原图像素空间的 bbox 映射到画布上的显示矩形。
Rect _mapBox(SubjectBox box, Size imageSize, Rect fit) {
  final src = box.toImageRect(imageSize);
  final scaleX = fit.width / imageSize.width;
  final scaleY = fit.height / imageSize.height;
  return Rect.fromLTWH(
    fit.left + src.left * scaleX,
    fit.top + src.top * scaleY,
    src.width * scaleX,
    src.height * scaleY,
  );
}

class SubjectBoxOverlay extends StatelessWidget {
  const SubjectBoxOverlay({
    super.key,
    required this.subject,
    required this.rect,
    this.onTap,
  });

  final DetectedSubject subject;
  final Rect rect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = subjectStockColor(subject);
    final confidence = subject.confidence;
    final base = parseSeries(subject.displayTitle).base;
    final label = confidence != null && confidence > 0
        ? '$base  ${(confidence * 100).toStringAsFixed(0)}%'
        : base;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 2.4),
            borderRadius: BorderRadius.circular(cardCornerRadius),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xCC05070D),
                borderRadius: BorderRadius.circular(controlCornerRadius),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ButtonLabel extends StatelessWidget {
  const ButtonLabel({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        color ??
        adaptiveColor(context, CupertinoColors.black, CupertinoColors.white);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: labelColor),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: labelColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? adaptiveColor(
            context,
            CupertinoColors.systemRed,
            const Color(0xFFFF453A),
          )
        : wakareeruMint;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? CupertinoIcons.exclamationmark_triangle_fill
                : CupertinoIcons.check_mark_circled_solid,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// 识别结果区头部：对象数 + 「保存到记录」按钮。
class ResultHeader extends StatelessWidget {
  const ResultHeader({
    super.key,
    required this.count,
    required this.saved,
    required this.onSave,
  });

  final int count;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return Row(
      children: [
        Text(
          strings.recognitionResults,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Text(
          strings.carsCount(count),
          style: TextStyle(fontSize: 14, color: muted),
        ),
        const Spacer(),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          borderRadius: BorderRadius.circular(999),
          color: saved
              ? CupertinoColors.systemGrey.withValues(alpha: 0.22)
              : wakareeruBlue,
          onPressed: saved ? null : onSave,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                saved
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.tray_arrow_down,
                size: 16,
                color: saved ? muted : CupertinoColors.white,
              ),
              const SizedBox(width: 6),
              Text(
                saved ? strings.savedAutomatically : strings.saveToHistory,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: saved ? muted : CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 识别中 / 空结果的占位卡片。
class ResultPlaceholder extends StatelessWidget {
  const ResultPlaceholder({
    super.key,
    required this.message,
    this.isEmpty = false,
  });

  final String message;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return GlassPanel(
      child: Row(
        children: [
          if (isEmpty)
            Icon(CupertinoIcons.search, size: 20, color: muted)
          else
            const CupertinoActivityIndicator(radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, color: muted, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// 駅名標式车辆卡：线路/公司色带 + 番号大字 + 百科元数据 + top-k 候选。
class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.subject, this.onTap});

  final DetectedSubject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final color = subjectStockColor(subject);
    final category = stockCategoryInfo(
      resolveCategory(
        type: subject.stockType,
        powerType: subject.powerType,
        label: subject.displayTitle,
      ),
    );
    final parts = parseSeries(subject.displayTitle);
    final confidence = (subject.confidence ?? 0).clamp(0, 1).toDouble();
    final strings = l10n(context);
    final statusLabel = subjectStatusLabel(context, subject);
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    final operator = subject.operator;
    final best = subject.best;
    final wikiUrl = subject.best?.wikiUrl;

    final metaRows = best == null
        ? <(String, String)>[]
        : predictionMetadataRows(context, best);
    final others = subject.topK.length > 1
        ? subject.topK.sublist(1, math.min(subject.topK.length, 4))
        : const <PredictionEntry>[];
    final fill = adaptiveColor(
      context,
      CupertinoColors.white.withValues(alpha: 0.78),
      const Color(0xFF161B26).withValues(alpha: 0.92),
    );
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.10)
        : CupertinoColors.white.withValues(alpha: 0.5);

    return RoundedCardSurface(
      fill: fill,
      borderColor: borderColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Icon(category.icon, size: 15, color: CupertinoColors.white),
                  const SizedBox(width: 7),
                  Text(
                    category.jp,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const Spacer(),
                  if (operator != null)
                    Text(
                      operator,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    parts.base,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                if (statusLabel != null) ...[
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    label: statusLabel,
                                    color: subjectAccent(subject),
                                  ),
                                ],
                              ],
                            ),
                            if (parts.variant != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                parts.variant!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: confidence,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFE5E5EA),
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final row in metaRows)
                    _MetaRow(label: row.$1, value: row.$2),
                  if (wikiUrl != null) ...[
                    const SizedBox(height: 6),
                    _CopyLinkButton(url: wikiUrl, label: strings.openWikipedia),
                  ],
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      strings.otherCandidates,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in others)
                      _CandidateRow(entry: entry, color: muted),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        strings.details,
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 13,
                        color: muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片内的元数据行（label 固定宽 + value）。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(fontSize: 13, color: muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片内紧凑的 top-k 候选行。
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.entry, required this.color});

  final PredictionEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final value = entry.score.clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: isDark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFE5E5EA),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text(
              '${(value * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          child: const Icon(CupertinoIcons.minus_circle),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: value >= 20 ? null : () => onChanged(value + 1),
          child: const Icon(CupertinoIcons.plus_circle),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: wakareeruBlue, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class InfoMetric extends StatelessWidget {
  const InfoMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: adaptiveColor(
          context,
          CupertinoColors.white.withValues(alpha: 0.62),
          const Color(0xFF1A2231).withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: adaptiveColor(
                  context,
                  const Color(0x993C3C43),
                  const Color(0x99EBEBF5),
                ),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class GatewayApiException implements Exception {
  const GatewayApiException(this.message);

  final String message;

  factory GatewayApiException.fromPayload(int statusCode, Object? payload) {
    if (payload is Map<String, dynamic>) {
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code']?.toString();
        final message = error['message']?.toString();
        final requestId = error['request_id']?.toString();
        return GatewayApiException(
          ['HTTP $statusCode', ?code, ?message, ?requestId].join(' · '),
        );
      }
    }
    return GatewayApiException('HTTP $statusCode');
  }

  @override
  String toString() => message;
}

class GatewayInferenceResult {
  const GatewayInferenceResult({
    required this.subjects,
    required this.status,
    required this.raw,
  });

  final List<DetectedSubject> subjects;
  final String? status;
  final Map<String, dynamic> raw;

  factory GatewayInferenceResult.fromJson(Map<String, dynamic> json) {
    // 网关把真正的载荷包在 output 里（RunPod 同步响应），先解包再读取。
    final root = json['output'] is Map<String, dynamic>
        ? json['output'] as Map<String, dynamic>
        : json;

    final subjects = <DetectedSubject>[];
    final rawSubjects =
        root['subjects'] ?? root['detections'] ?? root['objects'];
    if (rawSubjects is Iterable) {
      for (final entry in rawSubjects) {
        final subject = DetectedSubject.fromJson(entry);
        if (subject != null) {
          subjects.add(subject);
        }
      }
    }
    return GatewayInferenceResult(
      subjects: subjects,
      status: root['status']?.toString(),
      raw: json,
    );
  }
}

class DetectedSubject {
  const DetectedSubject({
    required this.topK,
    required this.topPrediction,
    required this.groupCandidates,
    required this.classificationStatus,
    this.confusionGroup,
    this.box,
    this.detectionScore,
    this.detectionLabel,
    this.index,
  });

  /// 分类候选列表（classification.top_k）。
  final List<PredictionEntry> topK;

  /// 置信最高的分类（classification.top_prediction）。
  final PredictionEntry? topPrediction;

  /// 易混淆时的同组候选（classification.group_candidates）。
  final List<PredictionEntry> groupCandidates;

  /// classified / low_confidence / no_detection / confusion / ...
  final String classificationStatus;
  final String? confusionGroup;

  /// 检测框（detection.bbox，原图像素 xyxy）。
  final SubjectBox? box;
  final double? detectionScore;
  final String? detectionLabel;
  final int? index;

  PredictionEntry? get best =>
      topPrediction ?? (topK.isNotEmpty ? topK.first : null);

  String get displayTitle => best?.label ?? detectionLabel ?? 'Unknown';

  double? get confidence => best?.score;

  /// 列表副标题：有元数据描述时显示（网关补充 description 后自动出现）。
  String? get subtitle => best?.subtitle;

  // 最佳候选的细粒度元数据，便于卡片直接读取。
  String? get operator => best?.operator;
  String? get operatorJp => best?.operatorJp;
  String? get operatorEn => best?.operatorEn;
  String? get powerType => best?.powerType;
  String? get stockType => best?.stockType;
  String? get bandai => best?.bandai;
  String? get submodel => best?.submodel;
  String? get wikiTitle => best?.wikiTitle;
  String? get specialFormation => best?.specialFormation;
  String? get specialLivery => best?.specialLivery;

  bool get isLowConfidence => classificationStatus == 'low_confidence';

  bool get isConfused =>
      confusionGroup != null || classificationStatus == 'confusion';

  static DetectedSubject? fromJson(dynamic value) {
    if (value is! Map) {
      // 兼容直接给出预测项（字符串 / 数组）的简单形态。
      final prediction = PredictionEntry.fromJson(value);
      if (prediction == null) {
        return null;
      }
      return DetectedSubject(
        topK: [prediction],
        topPrediction: prediction,
        groupCandidates: const [],
        classificationStatus: 'classified',
      );
    }
    final map = value.cast<String, dynamic>();
    final classification = map['classification'] is Map
        ? (map['classification'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final detection = map['detection'] is Map
        ? (map['detection'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final topK = _parsePredictions(
      classification['top_k'] ?? map['top_k'] ?? map['predictions'],
    );
    var topPrediction = classification['top_prediction'] != null
        ? PredictionEntry.fromJson(classification['top_prediction'])
        : null;
    topPrediction ??= topK.isNotEmpty ? topK.first : null;
    // 兜底：整个对象本身就是一个预测项。
    if (topPrediction == null && topK.isEmpty) {
      final direct = PredictionEntry.fromJson(map);
      if (direct != null && direct.label != 'Unknown') {
        topPrediction = direct;
        topK.add(direct);
      }
    }

    return DetectedSubject(
      topK: topK,
      topPrediction: topPrediction,
      groupCandidates: _parsePredictions(classification['group_candidates']),
      classificationStatus:
          classification['status']?.toString() ?? 'classified',
      confusionGroup: classification['confusion_group']?.toString(),
      box: SubjectBox.fromAny(
        detection['bbox'] ?? map['bbox'] ?? map['box'] ?? map['crop_box'],
      ),
      detectionScore: PredictionEntry.parseDoubleOrNull(
        detection['score'] ?? map['score'] ?? map['confidence'],
      ),
      detectionLabel: detection['label']?.toString(),
      index: PredictionEntry.parseIntOrNull(map['index']),
    );
  }

  static List<PredictionEntry> _parsePredictions(dynamic value) {
    final result = <PredictionEntry>[];
    if (value is Iterable) {
      for (final entry in value) {
        final prediction = PredictionEntry.fromJson(entry);
        if (prediction != null && prediction.label.isNotEmpty) {
          result.add(prediction);
        }
      }
    }
    return result;
  }
}

class SubjectBox {
  const SubjectBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.normalized,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  /// 坐标是否为 0..1 归一化（否则按原图像素处理）。
  final bool normalized;

  /// 还原为原图像素空间的矩形（按尺寸缩放并裁剪到边界）。
  Rect toImageRect(Size imageSize) {
    final w = imageSize.width;
    final h = imageSize.height;
    final left = (normalized ? x1 * w : x1).clamp(0.0, w).toDouble();
    final top = (normalized ? y1 * h : y1).clamp(0.0, h).toDouble();
    final right = (normalized ? x2 * w : x2).clamp(0.0, w).toDouble();
    final bottom = (normalized ? y2 * h : y2).clamp(0.0, h).toDouble();
    return Rect.fromLTRB(
      math.min(left, right),
      math.min(top, bottom),
      math.max(left, right),
      math.max(top, bottom),
    );
  }

  static bool _isNormalized(List<double> values) =>
      values.every((value) => value >= 0 && value <= 1);

  static SubjectBox? fromAny(dynamic value) {
    // 网关返回数组 [x1, y1, x2, y2]（原图像素，左上 + 右下）。
    if (value is List && value.length >= 4) {
      final numbers = value.take(4).map(PredictionEntry.parseDouble).toList();
      if (numbers.any((item) => item.isNaN)) {
        return null;
      }
      return SubjectBox(
        x1: numbers[0],
        y1: numbers[1],
        x2: numbers[2],
        y2: numbers[3],
        normalized: _isNormalized(numbers),
      );
    }
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      if (map.containsKey('x1') || map.containsKey('x2')) {
        final x1 = PredictionEntry.parseDouble(map['x1'] ?? map['left']);
        final y1 = PredictionEntry.parseDouble(map['y1'] ?? map['top']);
        final x2 = PredictionEntry.parseDouble(map['x2'] ?? map['right']);
        final y2 = PredictionEntry.parseDouble(map['y2'] ?? map['bottom']);
        final values = [x1, y1, x2, y2];
        if (values.any((item) => item.isNaN)) {
          return null;
        }
        return SubjectBox(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          normalized: _isNormalized(values),
        );
      }
      // 兼容 xywh（左上 + 宽高）写法。
      final x = PredictionEntry.parseDouble(map['x'] ?? map['left']);
      final y = PredictionEntry.parseDouble(map['y'] ?? map['top']);
      final width = PredictionEntry.parseDouble(map['width'] ?? map['w']);
      final height = PredictionEntry.parseDouble(map['height'] ?? map['h']);
      if ([x, y, width, height].any((item) => item.isNaN)) {
        return null;
      }
      return SubjectBox(
        x1: x,
        y1: y,
        x2: x + width,
        y2: y + height,
        normalized: _isNormalized([x, y, x + width, y + height]),
      );
    }
    return null;
  }
}

class PredictionEntry {
  const PredictionEntry({
    required this.label,
    required this.score,
    this.labelId,
    String? series,
    String? submodel,
    String? bandai,
    String? operatorJp,
    String? operatorEn,
    String? powerType,
    String? specialFormation,
    String? specialLivery,
    String? wikiTitle,
    String? wikiUrlRaw,
    this.description,
    this.localizedNames = const {},
  }) : _series = series,
       _submodel = submodel,
       _bandai = bandai,
       _operatorJp = operatorJp,
       _operatorEn = operatorEn,
       _powerType = powerType,
       _specialFormation = specialFormation,
       _specialLivery = specialLivery,
       _wikiTitle = wikiTitle,
       _wikiUrlRaw = wikiUrlRaw;

  final String label;
  final double score;
  final int? labelId;

  // 网关原始字段（当前多为空，未来网关可逐条带出）。
  final String? _series;
  final String? _submodel;
  final String? _bandai;
  final String? _operatorJp;
  final String? _operatorEn;
  final String? _powerType;
  final String? _specialFormation;
  final String? _specialLivery;
  final String? _wikiTitle;
  final String? _wikiUrlRaw;
  final String? description;
  final Map<String, String> localizedNames;

  /// 打包标签表里的元数据（按 label 查），用于网关字段缺失时补全。
  StockMeta? get _meta => catalogLookup(label);

  String? get rawLabel => labelId?.toString();

  // 「有效值」= 网关字段优先，否则退回打包标签表。
  String? get series => _series;
  String? get submodel => _submodel;
  String? get bandai => _bandai;
  String? get specialFormation => _specialFormation;
  String? get specialLivery => _specialLivery;
  String? get operatorJp => _operatorJp ?? _meta?.operatorJp;
  String? get operatorEn => _operatorEn ?? _meta?.operatorEn;
  String? get operator => operatorJp ?? operatorEn;
  String? get powerType => _powerType ?? _meta?.power;
  String? get stockType => _meta?.type; // 车种（含新幹線），仅标签表有
  String? get fullName => _meta?.fullName;
  String? get wikiTitle => _wikiTitle ?? _meta?.wiki;

  /// 维基链接：优先后端给的完整 URL，否则由 wiki_title 拼日文维基。
  String? get wikiUrl => _wikiUrlRaw ?? wikipediaUrl(wikiTitle);

  String? get subtitle {
    if (description != null && description!.isNotEmpty) {
      return description;
    }
    return null;
  }

  static PredictionEntry? fromJson(dynamic json) {
    if (json is Map) {
      final map = json.cast<String, dynamic>();
      final labelValue =
          map['label'] ??
          map['name'] ??
          map['class_name'] ??
          map['fine_grained_series'] ??
          map['series'] ??
          map['top_label'];
      final label = labelValue?.toString();
      if (label == null || label.isEmpty) {
        return null;
      }
      return PredictionEntry(
        label: label,
        score: parseDouble(
          map['probability'] ??
              map['score'] ??
              map['confidence'] ??
              map['prob'],
        ),
        labelId: parseIntOrNull(
          map['label_id'] ?? map['id'] ?? map['raw_label'],
        ),
        series: _firstString(map, const ['series', 'base_series']),
        submodel: _firstString(map, const ['submodel', 'sub_model']),
        bandai: _firstString(map, const ['bandai', '番台']),
        operatorJp: _operatorString(
          map['operator_jp'] ?? map['operator_jp_json'] ?? map['operators_jp'],
        ),
        operatorEn: _operatorString(
          map['operator_en'] ??
              map['operator_en_json'] ??
              map['operator'] ??
              map['operators'],
        ),
        powerType: _firstString(map, const ['power_type', 'powerType']),
        specialFormation: _firstString(map, const [
          'special_formation',
          'formation',
        ]),
        specialLivery: _firstString(map, const ['special_livery', 'livery']),
        wikiTitle: _firstString(map, const ['wiki_title', 'wikiTitle']),
        wikiUrlRaw: _firstString(map, const [
          'wiki_url',
          'wikipedia',
          'wiki',
          'url',
        ]),
        description: _firstString(map, const [
          'description',
          'desc',
          'summary',
        ]),
        localizedNames: _parseLocalized(
          map['names'] ?? map['i18n'] ?? map['localized'] ?? map['labels'],
        ),
      );
    }
    if (json is List && json.length >= 2) {
      return PredictionEntry(
        label: json[0].toString(),
        score: parseDouble(json[1]),
      );
    }
    if (json != null && json.toString().isNotEmpty) {
      return PredictionEntry(label: json.toString(), score: 0);
    }
    return null;
  }

  static double parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? double.nan;
  }

  static double? parseDoubleOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final result = parseDouble(value);
    return result.isNaN ? null : result;
  }

  static int? parseIntOrNull(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  /// 运营公司可能是字符串、JSON 数组字符串，或已解析的数组；统一取第一个非空值。
  static String? _operatorString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is List) {
      for (final item in value) {
        if (item != null && item.toString().isNotEmpty) {
          return item.toString();
        }
      }
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text.replaceAll("'", '"'));
        if (decoded is List) {
          for (final item in decoded) {
            if (item != null && item.toString().isNotEmpty) {
              return item.toString();
            }
          }
        }
      } catch (_) {
        // 不是合法 JSON 数组就当普通字符串返回。
      }
    }
    return text;
  }

  static Map<String, String> _parseLocalized(dynamic value) {
    if (value is Map) {
      final result = <String, String>{};
      value.forEach((key, dynamic item) {
        if (item != null && item.toString().isNotEmpty) {
          result[key.toString()] = item.toString();
        }
      });
      return result;
    }
    return const {};
  }
}

/// 弹出某个识别对象的详情面板（候选系列、检测信息、可扩展元数据）。
void showSubjectDetail(BuildContext context, DetectedSubject subject) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => SubjectDetailSheet(subject: subject),
  );
}

class SubjectDetailSheet extends StatelessWidget {
  const SubjectDetailSheet({super.key, required this.subject});

  final DetectedSubject subject;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final accent = subjectAccent(subject);
    final strings = l10n(context);
    final statusLabel = subjectStatusLabel(context, subject);
    final confidence = subject.confidence;
    final best = subject.best;
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12161F) : const Color(0xFFF7F9FF),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(appCornerRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subject.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (statusLabel != null) ...[
                              const SizedBox(width: 8),
                              StatusChip(label: statusLabel, color: accent),
                            ],
                          ],
                        ),
                        if (confidence != null && confidence > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            strings.confidence(
                              (confidence * 100).toStringAsFixed(1),
                            ),
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: muted,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (subject.topK.isNotEmpty)
                    _DetailSection(
                      title: strings.candidateSeries,
                      child: Column(
                        children: [
                          for (var i = 0; i < subject.topK.length; i++)
                            _PredictionBar(
                              entry: subject.topK[i],
                              color: i == 0 ? accent : muted,
                              emphasize: i == 0,
                            ),
                        ],
                      ),
                    ),
                  if (subject.groupCandidates.isNotEmpty)
                    _DetailSection(
                      title: strings.confusionCandidates,
                      child: Column(
                        children: [
                          for (final entry in subject.groupCandidates)
                            _PredictionBar(
                              entry: entry,
                              color: wakareeruViolet,
                            ),
                        ],
                      ),
                    ),
                  _DetailSection(
                    title: strings.detectionInfo,
                    child: Column(
                      children: [
                        if (subject.detectionLabel != null)
                          _DetailMetric(
                            label: strings.detectionTarget,
                            value: subject.detectionLabel!,
                          ),
                        if (subject.detectionScore != null)
                          _DetailMetric(
                            label: strings.detectionConfidence,
                            value:
                                '${(subject.detectionScore! * 100).toStringAsFixed(1)}%',
                          ),
                        if (subject.box != null)
                          _DetailMetric(
                            label: strings.cropBox,
                            value: _formatBox(subject.box!),
                          ),
                        if (best?.labelId != null)
                          _DetailMetric(
                            label: strings.labelId,
                            value: best!.labelId.toString(),
                          ),
                      ],
                    ),
                  ),
                  _DetailSection(
                    title: strings.moreInfo,
                    child: _MetadataView(entry: best, muted: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBox(SubjectBox box) {
    String f(double v) =>
        box.normalized ? v.toStringAsFixed(3) : v.round().toString();
    final w = box.x2 - box.x1;
    final h = box.y2 - box.y1;
    final unit = box.normalized ? '' : ' px';
    return '[${f(box.x1)}, ${f(box.y1)}, ${f(box.x2)}, ${f(box.y2)}] · '
        '${f(w)}×${f(h)}$unit';
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A2231).withValues(alpha: 0.9)
                  : CupertinoColors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(cardCornerRadius),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PredictionBar extends StatelessWidget {
  const _PredictionBar({
    required this.entry,
    required this.color,
    this.emphasize = false,
  });

  final PredictionEntry entry;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    final value = entry.score.clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF3A3A3C)
                  : const Color(0xFFE5E5EA),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = adaptiveColor(
      context,
      const Color(0x993C3C43),
      const Color(0x99EBEBF5),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 14, color: muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 可扩展元数据视图：网关补充描述 / 维基链接 / 多语言名称后自动渲染，
/// 当前为空时给出占位说明。
class _MetadataView extends StatelessWidget {
  const _MetadataView({required this.entry, required this.muted});

  final PredictionEntry? entry;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final description = entry?.description;
    final wikiUrl = entry?.wikiUrl;
    final localized = entry?.localizedNames ?? const <String, String>{};

    final rows = entry == null
        ? <(String, String)>[]
        : predictionMetadataRows(context, entry, detailed: true);

    final hasMeta =
        rows.isNotEmpty ||
        description != null ||
        wikiUrl != null ||
        localized.isNotEmpty;

    if (!hasMeta) {
      return Text(
        l10n(context).metadataUnavailable,
        style: TextStyle(fontSize: 13, height: 1.35, color: muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null) ...[
          Text(description, style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
        ],
        for (final row in rows) _DetailMetric(label: row.$1, value: row.$2),
        for (final name in localized.entries)
          _DetailMetric(label: name.key, value: name.value),
        if (wikiUrl != null) ...[
          const SizedBox(height: 6),
          _CopyLinkButton(url: wikiUrl, label: l10n(context).openWikipedia),
        ],
      ],
    );
  }
}

class _CopyLinkButton extends StatefulWidget {
  const _CopyLinkButton({required this.url, this.label});

  final String url;

  /// 给定时展示该文案（如「Wikipedia でひらく」），否则展示原始 URL。
  final String? label;

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    await HapticFeedback.selectionClick();
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resting = widget.label ?? widget.url;
    final restingIcon = widget.label != null
        ? CupertinoIcons.link
        : CupertinoIcons.doc_on_clipboard;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _copy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _copied ? CupertinoIcons.checkmark_alt : restingIcon,
            size: 16,
            color: wakareeruBlue,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _copied ? l10n(context).copiedLink : resting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: wakareeruBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
