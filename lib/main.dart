import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Brightness, ColorScheme, LinearProgressIndicator, ThemeData, ThemeMode;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const WakareeruApp());
}

const String appDisplayName = 'わかれーる';
const Color wakareeruBlue = Color(0xFF007AFF);
const Color wakareeruMint = Color(0xFF00B7A8);

bool isAppDark(BuildContext context) {
  return CupertinoTheme.of(context).brightness == Brightness.dark;
}

Color adaptiveColor(BuildContext context, Color light, Color dark) {
  return isAppDark(context) ? dark : light;
}

class WakareeruApp extends StatefulWidget {
  const WakareeruApp({super.key});

  @override
  State<WakareeruApp> createState() => _WakareeruAppState();
}

class _WakareeruAppState extends State<WakareeruApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
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
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class WakareeruShell extends StatefulWidget {
  const WakareeruShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<WakareeruShell> createState() => _WakareeruShellState();
}

class _WakareeruShellState extends State<WakareeruShell> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _apiBaseController = TextEditingController(
    text: const String.fromEnvironment(
      'WAKAREERU_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    ),
  );

  int _selectedIndex = 0;
  int _topK = 5;
  XFile? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;
  GatewayInferenceResult? _result;

  @override
  void dispose() {
    _apiBaseController.dispose();
    super.dispose();
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
    });
  }

  Future<void> _runInference() async {
    final image = _selectedImage;
    if (image == null) {
      setState(() => _errorMessage = '先选择一张车辆图片。');
      return;
    }

    final endpoint = _resolveEndpoint(_apiBaseController.text.trim());
    if (endpoint == null) {
      setState(() => _errorMessage = 'API 地址无效。');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final request = http.MultipartRequest('POST', endpoint)
        ..fields['top_k'] = _topK.toString();

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            await image.readAsBytes(),
            filename: image.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final decoded = responseBody.isEmpty ? null : jsonDecode(responseBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GatewayApiException.fromPayload(response.statusCode, decoded);
      }
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Gateway response is not a JSON object.');
      }

      setState(() => _result = GatewayInferenceResult.fromJson(decoded));
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        onPickCamera: () => _pickImage(ImageSource.camera),
        onPickGallery: () => _pickImage(ImageSource.gallery),
        onRunInference: _runInference,
      ),
      SettingsPage(
        apiBaseController: _apiBaseController,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
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
    final cupertinoItems = const [
      BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.sparkles),
        activeIcon: Icon(CupertinoIcons.sparkles),
        label: '识别',
      ),
      BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.slider_horizontal_3),
        activeIcon: Icon(CupertinoIcons.slider_horizontal_3),
        label: '设置',
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
        items: const [
          AdaptiveNavigationDestination(
            icon: 'sparkles.rectangle.stack.fill',
            selectedIcon: 'sparkles.rectangle.stack.fill',
            label: '识别',
          ),
          AdaptiveNavigationDestination(
            icon: 'slider.horizontal.3',
            selectedIcon: 'slider.horizontal.3',
            label: '设置',
          ),
        ],
      ),
      minimizeBehavior: TabBarMinimizeBehavior.never,
      enableBlur: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }
}

class RecognitionPage extends StatelessWidget {
  const RecognitionPage({
    super.key,
    required this.image,
    required this.result,
    required this.errorMessage,
    required this.isLoading,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRunInference,
  });

  final XFile? image;
  final GatewayInferenceResult? result;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRunInference;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return AppBackdrop(
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, topInset + 18, 18, 118),
        children: [
          const BrandHeader(),
          const SizedBox(height: 18),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ImagePreview(
                  image: image,
                  subjects: result?.subjects ?? const [],
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
                          child: const ButtonLabel(
                            icon: CupertinoIcons.camera_fill,
                            text: '拍照',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdaptiveButton.child(
                          onPressed: isLoading ? null : onPickGallery,
                          style: AdaptiveButtonStyle.glass,
                          size: AdaptiveButtonSize.large,
                          child: const ButtonLabel(
                            icon: CupertinoIcons.photo_on_rectangle,
                            text: '相册',
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
                        : const ButtonLabel(
                            icon: CupertinoIcons.bolt_fill,
                            text: '开始识别',
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
          const SizedBox(height: 14),
          ResultPanel(result: result, isLoading: isLoading),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.apiBaseController,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.topK,
    required this.onTopKChanged,
    required this.onChanged,
  });

  final TextEditingController apiBaseController;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final int topK;
  final ValueChanged<int> onTopKChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final selectedThemeIndex = switch (themeMode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };
    return AppBackdrop(
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, topInset + 18, 18, 118),
        children: [
          const PageTitle(title: '连接设置'),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(
                  icon: CupertinoIcons.circle_lefthalf_fill,
                  text: '主题',
                ),
                const SizedBox(height: 12),
                AdaptiveSegmentedControl(
                  labels: const ['系统', '浅色', '深色'],
                  selectedIndex: selectedThemeIndex,
                  onValueChanged: (index) => onThemeModeChanged(switch (index) {
                    1 => ThemeMode.light,
                    2 => ThemeMode.dark,
                    _ => ThemeMode.system,
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
                const SectionLabel(icon: CupertinoIcons.link, text: 'Gateway'),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: apiBaseController,
                  placeholder: 'http://127.0.0.1:8787',
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
                    borderRadius: BorderRadius.circular(14),
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
              children: const [
                SectionLabel(icon: CupertinoIcons.info_circle, text: '关于'),
                SizedBox(height: 12),
                InfoMetric(label: '应用', value: appDisplayName),
                SizedBox(height: 8),
                InfoMetric(label: 'GitHub', value: 'SniperPigeon/wakareeru'),
              ],
            ),
          ),
        ],
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

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [wakareeruBlue, wakareeruMint],
              ),
            ),
            child: const Icon(
              CupertinoIcons.tram_fill,
              color: CupertinoColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  appDisplayName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Japanese rolling stock recognition',
                  style: TextStyle(
                    fontSize: 13,
                    color: adaptiveColor(
                      context,
                      const Color(0x993C3C43),
                      const Color(0x99EBEBF5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(28),
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

class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key, required this.image, required this.subjects});

  final XFile? image;
  final List<DetectedSubject> subjects;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDark(context);
    if (image == null) {
      return AspectRatio(
        aspectRatio: 1.18,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: const [
              Positioned(
                left: 20,
                top: 22,
                child: Icon(
                  CupertinoIcons.tram_fill,
                  color: CupertinoColors.white,
                  size: 54,
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Text(
                  'Drop in a train photo.\nThe model will read the series signal.',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: AspectRatio(
        aspectRatio: 1.18,
        child: FutureBuilder<Uint8List>(
          future: image!.readAsBytes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(snapshot.data!, fit: BoxFit.cover),
                    for (final subject in subjects)
                      if (subject.box != null)
                        SubjectBoxOverlay(subject: subject, canvasSize: size),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SubjectBoxOverlay extends StatelessWidget {
  const SubjectBoxOverlay({
    super.key,
    required this.subject,
    required this.canvasSize,
  });

  final DetectedSubject subject;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final box = subject.box!;
    final rect = box.toRect(canvasSize);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: wakareeruMint, width: 2.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xCC05070D),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              subject.displayTitle,
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

class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.result, required this.isLoading});

  final GatewayInferenceResult? result;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final subjects = result?.subjects ?? const <DetectedSubject>[];
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel(
                icon: CupertinoIcons.chart_bar_alt_fill,
                text: '识别结果',
              ),
              const Spacer(),
              if (isLoading) const CupertinoActivityIndicator(radius: 10),
            ],
          ),
          const SizedBox(height: 16),
          if (subjects.isEmpty)
            Text(
              isLoading ? '识别中。' : '选择图片后开始识别。',
              style: TextStyle(
                fontSize: 15,
                color: adaptiveColor(
                  context,
                  const Color(0x993C3C43),
                  const Color(0x99EBEBF5),
                ),
              ),
            )
          else ...[
            for (final subject in subjects.take(5))
              SubjectResultTile(subject: subject),
          ],
        ],
      ),
    );
  }
}

class SubjectResultTile extends StatelessWidget {
  const SubjectResultTile({super.key, required this.subject});

  final DetectedSubject subject;

  @override
  Widget build(BuildContext context) {
    final prediction = subject.predictions.isEmpty
        ? null
        : subject.predictions.first;
    final confidence = (prediction?.score ?? subject.score ?? 0)
        .clamp(0, 1)
        .toDouble();
    final isDark = isAppDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.displayTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (confidence > 0)
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (subject.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subject.subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: adaptiveColor(
                  context,
                  const Color(0x993C3C43),
                  const Color(0x99EBEBF5),
                ),
              ),
            ),
          ],
          if (confidence > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 7,
                backgroundColor: isDark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFE5E5EA),
                color: wakareeruBlue,
              ),
            ),
          ],
        ],
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
  const GatewayInferenceResult({required this.subjects, required this.raw});

  final List<DetectedSubject> subjects;
  final Map<String, dynamic> raw;

  factory GatewayInferenceResult.fromJson(Map<String, dynamic> json) {
    final subjectEntries = _extractSubjects(json).toList();
    final subjects = subjectEntries.isEmpty
        ? _extractPredictions(json)
              .map((entry) => DetectedSubject.fromPrediction(entry))
              .where((entry) => entry.displayTitle.isNotEmpty)
              .toList()
        : subjectEntries
              .map((entry) => DetectedSubject.fromJson(entry))
              .where((entry) => entry.displayTitle.isNotEmpty)
              .toList();
    return GatewayInferenceResult(subjects: subjects, raw: json);
  }

  static Iterable<dynamic> _extractSubjects(Map<String, dynamic> json) {
    for (final key in ['subjects', 'detections', 'crops', 'objects']) {
      final value = json[key];
      if (value is Iterable) {
        return value;
      }
    }
    return const [];
  }

  static Iterable<dynamic> _extractPredictions(Map<String, dynamic> json) {
    for (final key in [
      'predictions',
      'top_predictions',
      'results',
      'classes',
    ]) {
      final value = json[key];
      if (value is Iterable) {
        return value;
      }
    }
    return const [];
  }
}

class DetectedSubject {
  const DetectedSubject({
    required this.predictions,
    this.box,
    this.score,
    this.subtitle,
  });

  final List<PredictionEntry> predictions;
  final SubjectBox? box;
  final double? score;
  final String? subtitle;

  String get displayTitle {
    if (predictions.isNotEmpty) {
      return predictions.first.label;
    }
    return 'Unknown';
  }

  factory DetectedSubject.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return DetectedSubject.fromPrediction(value);
    }
    final predictions = GatewayInferenceResult._extractPredictions(value)
        .map((entry) => PredictionEntry.fromJson(entry))
        .where((entry) => entry.label.isNotEmpty)
        .toList();
    final directPrediction = PredictionEntry.fromJson(value);
    if (predictions.isEmpty && directPrediction.label != 'Unknown') {
      predictions.add(directPrediction);
    }
    return DetectedSubject(
      predictions: predictions,
      box: SubjectBox.fromAny(
        value['bbox'] ?? value['box'] ?? value['crop_box'],
      ),
      score: PredictionEntry.parseDouble(value['score'] ?? value['confidence']),
      subtitle:
          value['wiki_title']?.toString() ?? value['description']?.toString(),
    );
  }

  factory DetectedSubject.fromPrediction(dynamic value) {
    return DetectedSubject(predictions: [PredictionEntry.fromJson(value)]);
  }
}

class SubjectBox {
  const SubjectBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Rect toRect(Size size) {
    final normalized = x <= 1 && y <= 1 && width <= 1 && height <= 1;
    final left = normalized ? x * size.width : x;
    final top = normalized ? y * size.height : y;
    final rectWidth = normalized ? width * size.width : width;
    final rectHeight = normalized ? height * size.height : height;
    return Rect.fromLTWH(
      left.clamp(0, size.width).toDouble(),
      top.clamp(0, size.height).toDouble(),
      rectWidth.clamp(0, size.width).toDouble(),
      rectHeight.clamp(0, size.height).toDouble(),
    );
  }

  static SubjectBox? fromAny(dynamic value) {
    if (value is List && value.length >= 4) {
      final numbers = value.map(PredictionEntry.parseDouble).toList();
      if (numbers.take(4).any((item) => item.isNaN)) {
        return null;
      }
      return SubjectBox(
        x: numbers[0],
        y: numbers[1],
        width: numbers[2],
        height: numbers[3],
      );
    }
    if (value is Map<String, dynamic>) {
      final x = PredictionEntry.parseDouble(value['x'] ?? value['left']);
      final y = PredictionEntry.parseDouble(value['y'] ?? value['top']);
      final width = PredictionEntry.parseDouble(value['width'] ?? value['w']);
      final height = PredictionEntry.parseDouble(value['height'] ?? value['h']);
      if ([x, y, width, height].any((item) => item.isNaN)) {
        return null;
      }
      return SubjectBox(x: x, y: y, width: width, height: height);
    }
    return null;
  }
}

class PredictionEntry {
  const PredictionEntry({
    required this.label,
    required this.score,
    this.rawLabel,
  });

  final String label;
  final double score;
  final String? rawLabel;

  factory PredictionEntry.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final labelValue =
          json['label'] ??
          json['name'] ??
          json['class_name'] ??
          json['series'] ??
          json['top_label'];
      final rawLabelValue =
          json['raw_label'] ?? json['label_raw'] ?? json['id'];
      final scoreValue =
          json['score'] ??
          json['probability'] ??
          json['confidence'] ??
          json['prob'];
      return PredictionEntry(
        label: (labelValue ?? 'Unknown').toString(),
        score: parseDouble(scoreValue),
        rawLabel: rawLabelValue?.toString(),
      );
    }
    if (json is List && json.length >= 2) {
      return PredictionEntry(
        label: json[0].toString(),
        score: parseDouble(json[1]),
      );
    }
    return PredictionEntry(label: json.toString(), score: 0);
  }

  static double parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? double.nan;
  }
}
