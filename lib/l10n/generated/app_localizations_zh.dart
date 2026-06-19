// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Wakareeru';

  @override
  String get tabRecognize => '识别';

  @override
  String get tabHistory => '记录';

  @override
  String get tabSettings => '设置';

  @override
  String get camera => '拍照';

  @override
  String get gallery => '从相册选择';

  @override
  String get startRecognition => '开始识别';

  @override
  String get recognizing => '识别中…';

  @override
  String get selectImageFirst => '先选择一张车辆图片。';

  @override
  String get invalidApiUrl => 'API 地址无效。';

  @override
  String get unsupportedImageConversion => '无法转换这张图片，请换用 JPEG、PNG 或 WebP。';

  @override
  String get noVehicleDetected => '未检测到车辆，换一张更清晰、车体更完整的照片试试。';

  @override
  String get recognitionResults => '识别结果';

  @override
  String carsCount(int count) {
    return '$count 辆';
  }

  @override
  String get savedAutomatically => '已自动保存';

  @override
  String get saveToHistory => '保存到记录';

  @override
  String get otherCandidates => '其他候选';

  @override
  String get details => '详情';

  @override
  String get openWikipedia => '在 Wikipedia 上查看';

  @override
  String get copiedLink => '已复制链接';

  @override
  String get historyTitle => '识别记录';

  @override
  String get clear => '清空';

  @override
  String get clearHistoryTitle => '清空记录';

  @override
  String get clearHistoryMessage => '本地保存的识别记录将被全部删除，无法恢复。';

  @override
  String get cancel => '取消';

  @override
  String get emptyHistoryTitle => '还没有记录';

  @override
  String get emptyHistoryMessage => '识别过的车辆会收集在这里。保存后可以按系列慢慢集齐。';

  @override
  String get startRecognizingHistory => '开始识别';

  @override
  String get deleteFromHistory => '从记录中删除';

  @override
  String get seriesCountLabel => '系列';

  @override
  String get operatorCountLabel => '运营公司';

  @override
  String get recordCountLabel => '记录';

  @override
  String get settingsTitle => '设置';

  @override
  String get theme => '主题';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeSystem => '系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get gateway => 'Gateway';

  @override
  String get about => '关于';

  @override
  String get appLabel => '应用';

  @override
  String get dataSource => '数据来源';

  @override
  String get account => '账户';

  @override
  String get anonymousUser => '匿名用户';

  @override
  String get anonymousUserSubtitle => '当前匿名使用，登录后可云端同步识别记录';

  @override
  String get signInWithApple => '通过 Apple 登录';

  @override
  String get comingSoonMessage => '该功能即将推出，敬请期待。';

  @override
  String get ok => '确定';

  @override
  String get collectionOperator => '运营公司';

  @override
  String get vehicleType => '车辆类型';

  @override
  String get powerType => '动力方式';

  @override
  String get series => '车系';

  @override
  String get formation => '特殊编组';

  @override
  String get livery => '涂装';

  @override
  String get submodel => '子型号';

  @override
  String get bandai => '番台';

  @override
  String get recordedAt => '记录时间';

  @override
  String get candidateSeries => '候选系列';

  @override
  String get confusionCandidates => '易混淆候选';

  @override
  String get detectionInfo => '检测信息';

  @override
  String get detectionTarget => '检测目标';

  @override
  String get detectionConfidence => '检测置信度';

  @override
  String get cropBox => '裁切框';

  @override
  String get labelId => '标签 ID';

  @override
  String get moreInfo => '更多信息';

  @override
  String get confidenceLabel => '置信度';

  @override
  String confidence(String percent) {
    return '置信度 $percent%';
  }

  @override
  String get metadataUnavailable => '运营公司、番台、涂装、维基百科等信息会在元数据可用时显示。';

  @override
  String get unknown => '未知';

  @override
  String get statusConfused => '易混淆';

  @override
  String get statusLowConfidence => '低置信度';

  @override
  String get statusNoDetection => '未检测到';
}
