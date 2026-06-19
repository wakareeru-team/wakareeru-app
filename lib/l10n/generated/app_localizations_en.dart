// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wakareeru';

  @override
  String get tabRecognize => 'Recognize';

  @override
  String get tabHistory => 'History';

  @override
  String get tabSettings => 'Settings';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get startRecognition => 'Start Recognition';

  @override
  String get recognizing => 'Recognizing…';

  @override
  String get selectImageFirst => 'Choose a vehicle photo first.';

  @override
  String get invalidApiUrl => 'Invalid API URL.';

  @override
  String get unsupportedImageConversion =>
      'Could not convert this image. Please use JPEG, PNG, or WebP.';

  @override
  String get noVehicleDetected =>
      'No vehicle was detected. Try a clearer photo with more of the body visible.';

  @override
  String get recognitionResults => 'Recognition Results';

  @override
  String carsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vehicles',
      one: '1 vehicle',
    );
    return '$_temp0';
  }

  @override
  String get savedAutomatically => 'Auto-saved';

  @override
  String get saveToHistory => 'Save to History';

  @override
  String get otherCandidates => 'Other Candidates';

  @override
  String get details => 'Details';

  @override
  String get openWikipedia => 'Open Wikipedia';

  @override
  String get copiedLink => 'Link copied';

  @override
  String get historyTitle => 'Recognition History';

  @override
  String get clear => 'Clear';

  @override
  String get clearHistoryTitle => 'Clear History';

  @override
  String get clearHistoryMessage =>
      'All locally saved recognition records will be deleted. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get emptyHistoryTitle => 'No Records Yet';

  @override
  String get emptyHistoryMessage =>
      'Recognized vehicles will appear here. Save results to build your collection by series.';

  @override
  String get startRecognizingHistory => 'Recognize a Vehicle';

  @override
  String get deleteFromHistory => 'Delete from History';

  @override
  String get seriesCountLabel => 'Series';

  @override
  String get operatorCountLabel => 'Operators';

  @override
  String get recordCountLabel => 'Records';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get gateway => 'Gateway';

  @override
  String get about => 'About';

  @override
  String get appLabel => 'App';

  @override
  String get dataSource => 'Data Source';

  @override
  String get account => 'Account';

  @override
  String get anonymousUser => 'Anonymous User';

  @override
  String get anonymousUserSubtitle =>
      'Using anonymously. Sign in to sync recognition history to the cloud.';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get comingSoonMessage => 'This feature is coming soon.';

  @override
  String get ok => 'OK';

  @override
  String get collectionOperator => 'Operator';

  @override
  String get vehicleType => 'Vehicle Type';

  @override
  String get powerType => 'Power System';

  @override
  String get series => 'Series';

  @override
  String get formation => 'Formation';

  @override
  String get livery => 'Livery';

  @override
  String get submodel => 'Type';

  @override
  String get bandai => 'Number Series';

  @override
  String get recordedAt => 'Recorded At';

  @override
  String get candidateSeries => 'Candidate Series';

  @override
  String get confusionCandidates => 'Similar Candidates';

  @override
  String get detectionInfo => 'Detection Info';

  @override
  String get detectionTarget => 'Detection Target';

  @override
  String get detectionConfidence => 'Detection Confidence';

  @override
  String get cropBox => 'Crop Box';

  @override
  String get labelId => 'Label ID';

  @override
  String get moreInfo => 'More Info';

  @override
  String get confidenceLabel => 'Confidence';

  @override
  String confidence(String percent) {
    return 'Confidence $percent%';
  }

  @override
  String get metadataUnavailable =>
      'Operator, number series, livery, Wikipedia, and other metadata will appear when available.';

  @override
  String get unknown => 'Unknown';

  @override
  String get statusConfused => 'Ambiguous';

  @override
  String get statusLowConfidence => 'Low Confidence';

  @override
  String get statusNoDetection => 'Not Detected';
}
