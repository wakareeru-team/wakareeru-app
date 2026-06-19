import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Wakareeru'**
  String get appTitle;

  /// No description provided for @tabRecognize.
  ///
  /// In zh, this message translates to:
  /// **'识别'**
  String get tabRecognize;

  /// No description provided for @tabHistory.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get tabHistory;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @camera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get gallery;

  /// No description provided for @startRecognition.
  ///
  /// In zh, this message translates to:
  /// **'开始识别'**
  String get startRecognition;

  /// No description provided for @recognizing.
  ///
  /// In zh, this message translates to:
  /// **'识别中…'**
  String get recognizing;

  /// No description provided for @selectImageFirst.
  ///
  /// In zh, this message translates to:
  /// **'先选择一张车辆图片。'**
  String get selectImageFirst;

  /// No description provided for @invalidApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 地址无效。'**
  String get invalidApiUrl;

  /// No description provided for @unsupportedImageConversion.
  ///
  /// In zh, this message translates to:
  /// **'无法转换这张图片，请换用 JPEG、PNG 或 WebP。'**
  String get unsupportedImageConversion;

  /// No description provided for @noVehicleDetected.
  ///
  /// In zh, this message translates to:
  /// **'未检测到车辆，换一张更清晰、车体更完整的照片试试。'**
  String get noVehicleDetected;

  /// No description provided for @recognitionResults.
  ///
  /// In zh, this message translates to:
  /// **'识别结果'**
  String get recognitionResults;

  /// No description provided for @carsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 辆'**
  String carsCount(int count);

  /// No description provided for @savedAutomatically.
  ///
  /// In zh, this message translates to:
  /// **'已自动保存'**
  String get savedAutomatically;

  /// No description provided for @saveToHistory.
  ///
  /// In zh, this message translates to:
  /// **'保存到记录'**
  String get saveToHistory;

  /// No description provided for @otherCandidates.
  ///
  /// In zh, this message translates to:
  /// **'其他候选'**
  String get otherCandidates;

  /// No description provided for @details.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get details;

  /// No description provided for @openWikipedia.
  ///
  /// In zh, this message translates to:
  /// **'在 Wikipedia 上查看'**
  String get openWikipedia;

  /// No description provided for @copiedLink.
  ///
  /// In zh, this message translates to:
  /// **'已复制链接'**
  String get copiedLink;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'识别记录'**
  String get historyTitle;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空记录'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In zh, this message translates to:
  /// **'本地保存的识别记录将被全部删除，无法恢复。'**
  String get clearHistoryMessage;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @emptyHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有记录'**
  String get emptyHistoryTitle;

  /// No description provided for @emptyHistoryMessage.
  ///
  /// In zh, this message translates to:
  /// **'识别过的车辆会收集在这里。保存后可以按系列慢慢集齐。'**
  String get emptyHistoryMessage;

  /// No description provided for @startRecognizingHistory.
  ///
  /// In zh, this message translates to:
  /// **'开始识别'**
  String get startRecognizingHistory;

  /// No description provided for @deleteFromHistory.
  ///
  /// In zh, this message translates to:
  /// **'从记录中删除'**
  String get deleteFromHistory;

  /// No description provided for @seriesCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'系列'**
  String get seriesCountLabel;

  /// No description provided for @operatorCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'运营公司'**
  String get operatorCountLabel;

  /// No description provided for @recordCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get recordCountLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageJapanese.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @gateway.
  ///
  /// In zh, this message translates to:
  /// **'Gateway'**
  String get gateway;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @appLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get appLabel;

  /// No description provided for @dataSource.
  ///
  /// In zh, this message translates to:
  /// **'数据来源'**
  String get dataSource;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get account;

  /// No description provided for @anonymousUser.
  ///
  /// In zh, this message translates to:
  /// **'匿名用户'**
  String get anonymousUser;

  /// No description provided for @anonymousUserSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前匿名使用，登录后可云端同步识别记录'**
  String get anonymousUserSubtitle;

  /// No description provided for @signInWithApple.
  ///
  /// In zh, this message translates to:
  /// **'通过 Apple 登录'**
  String get signInWithApple;

  /// No description provided for @comingSoonMessage.
  ///
  /// In zh, this message translates to:
  /// **'该功能即将推出，敬请期待。'**
  String get comingSoonMessage;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @collectionOperator.
  ///
  /// In zh, this message translates to:
  /// **'运营公司'**
  String get collectionOperator;

  /// No description provided for @vehicleType.
  ///
  /// In zh, this message translates to:
  /// **'车辆类型'**
  String get vehicleType;

  /// No description provided for @powerType.
  ///
  /// In zh, this message translates to:
  /// **'动力方式'**
  String get powerType;

  /// No description provided for @series.
  ///
  /// In zh, this message translates to:
  /// **'车系'**
  String get series;

  /// No description provided for @formation.
  ///
  /// In zh, this message translates to:
  /// **'特殊编组'**
  String get formation;

  /// No description provided for @livery.
  ///
  /// In zh, this message translates to:
  /// **'涂装'**
  String get livery;

  /// No description provided for @submodel.
  ///
  /// In zh, this message translates to:
  /// **'子型号'**
  String get submodel;

  /// No description provided for @bandai.
  ///
  /// In zh, this message translates to:
  /// **'番台'**
  String get bandai;

  /// No description provided for @recordedAt.
  ///
  /// In zh, this message translates to:
  /// **'记录时间'**
  String get recordedAt;

  /// No description provided for @candidateSeries.
  ///
  /// In zh, this message translates to:
  /// **'候选系列'**
  String get candidateSeries;

  /// No description provided for @confusionCandidates.
  ///
  /// In zh, this message translates to:
  /// **'易混淆候选'**
  String get confusionCandidates;

  /// No description provided for @detectionInfo.
  ///
  /// In zh, this message translates to:
  /// **'检测信息'**
  String get detectionInfo;

  /// No description provided for @detectionTarget.
  ///
  /// In zh, this message translates to:
  /// **'检测目标'**
  String get detectionTarget;

  /// No description provided for @detectionConfidence.
  ///
  /// In zh, this message translates to:
  /// **'检测置信度'**
  String get detectionConfidence;

  /// No description provided for @cropBox.
  ///
  /// In zh, this message translates to:
  /// **'裁切框'**
  String get cropBox;

  /// No description provided for @labelId.
  ///
  /// In zh, this message translates to:
  /// **'标签 ID'**
  String get labelId;

  /// No description provided for @moreInfo.
  ///
  /// In zh, this message translates to:
  /// **'更多信息'**
  String get moreInfo;

  /// No description provided for @confidenceLabel.
  ///
  /// In zh, this message translates to:
  /// **'置信度'**
  String get confidenceLabel;

  /// No description provided for @confidence.
  ///
  /// In zh, this message translates to:
  /// **'置信度 {percent}%'**
  String confidence(String percent);

  /// No description provided for @metadataUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'运营公司、番台、涂装、维基百科等信息会在元数据可用时显示。'**
  String get metadataUnavailable;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @statusConfused.
  ///
  /// In zh, this message translates to:
  /// **'易混淆'**
  String get statusConfused;

  /// No description provided for @statusLowConfidence.
  ///
  /// In zh, this message translates to:
  /// **'低置信度'**
  String get statusLowConfidence;

  /// No description provided for @statusNoDetection.
  ///
  /// In zh, this message translates to:
  /// **'未检测到'**
  String get statusNoDetection;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
