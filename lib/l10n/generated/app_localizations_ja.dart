// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Wakareeru';

  @override
  String get tabRecognize => '識別';

  @override
  String get tabHistory => '記録';

  @override
  String get tabSettings => '設定';

  @override
  String get camera => '撮影';

  @override
  String get gallery => '写真';

  @override
  String get startRecognition => '識別を開始';

  @override
  String get recognizing => '識別中…';

  @override
  String get selectImageFirst => '先に車両画像を選択してください。';

  @override
  String get invalidApiUrl => 'API アドレスが無効です。';

  @override
  String get unsupportedImageConversion =>
      'この画像を変換できません。JPEG、PNG、または WebP を選択してください。';

  @override
  String get noVehicleDetected => '車両を検出できませんでした。より鮮明で車体が写った写真を試してください。';

  @override
  String get recognitionResults => '識別結果';

  @override
  String carsCount(int count) {
    return '$count 両';
  }

  @override
  String get savedAutomatically => '自動保存済み';

  @override
  String get saveToHistory => '記録に保存';

  @override
  String get otherCandidates => 'ほかの候補';

  @override
  String get details => '詳細';

  @override
  String get openWikipedia => 'Wikipedia でひらく';

  @override
  String get copiedLink => 'リンクをコピーしました';

  @override
  String get historyTitle => '識別記録';

  @override
  String get clear => '消去';

  @override
  String get clearHistoryTitle => '記録を消去';

  @override
  String get clearHistoryMessage => 'ローカルに保存された識別記録はすべて削除され、元に戻せません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get emptyHistoryTitle => 'まだ記録がありません';

  @override
  String get emptyHistoryMessage => '識別した車両がここに集まります。保存すると系列ごとに集められます。';

  @override
  String get startRecognizingHistory => '識別をはじめる';

  @override
  String get deleteFromHistory => '記録から削除';

  @override
  String get seriesCountLabel => '系列';

  @override
  String get operatorCountLabel => '事業者';

  @override
  String get recordCountLabel => '記録';

  @override
  String get settingsTitle => '設定';

  @override
  String get theme => 'テーマ';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システム';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get gateway => 'Gateway';

  @override
  String get about => '情報';

  @override
  String get appLabel => 'アプリ';

  @override
  String get dataSource => 'データソース';

  @override
  String get account => 'アカウント';

  @override
  String get anonymousUser => '匿名ユーザー';

  @override
  String get anonymousUserSubtitle => '現在は匿名で利用中。ログインすると識別記録をクラウド同期できます。';

  @override
  String get signInWithApple => 'Apple でログイン';

  @override
  String get comingSoonMessage => 'この機能は近日提供予定です。';

  @override
  String get ok => 'OK';

  @override
  String get collectionOperator => '事業者';

  @override
  String get vehicleType => '車種';

  @override
  String get powerType => '動力';

  @override
  String get series => '系列';

  @override
  String get formation => '編成';

  @override
  String get livery => '塗装';

  @override
  String get submodel => '形式';

  @override
  String get bandai => '番台';

  @override
  String get recordedAt => '記録';

  @override
  String get candidateSeries => '候補系列';

  @override
  String get confusionCandidates => '混同しやすい候補';

  @override
  String get detectionInfo => '検出情報';

  @override
  String get detectionTarget => '検出対象';

  @override
  String get detectionConfidence => '検出信頼度';

  @override
  String get cropBox => '切り抜き枠';

  @override
  String get labelId => 'ラベル ID';

  @override
  String get moreInfo => '詳細情報';

  @override
  String get confidenceLabel => '信頼度';

  @override
  String confidence(String percent) {
    return '信頼度 $percent%';
  }

  @override
  String get metadataUnavailable =>
      '事業者、番台、塗装、Wikipedia などの情報はメタデータが利用可能になると表示されます。';

  @override
  String get unknown => 'Unknown';

  @override
  String get statusConfused => '混同注意';

  @override
  String get statusLowConfidence => '低信頼度';

  @override
  String get statusNoDetection => '未検出';
}
