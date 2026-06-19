import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 车辆动力类别，对应数据集 schema 的 power_type 取值。
/// 设计上颜色与图标都由「类别 + 运营公司」驱动，而不是硬编码每一个系列标签，
/// 这样才能覆盖全部标签空间（E233系 / EF510形 / D51形 / キハ40系 …）。
enum StockCategory {
  shinkansen,
  emu,
  dmu,
  electricLoco,
  dieselLoco,
  steamLoco,
  electroDieselMu,
  unknown,
}

class StockCategoryInfo {
  const StockCategoryInfo(this.category, this.jp, this.color, this.icon);

  final StockCategory category;
  final String jp;
  final Color color;
  final IconData icon;
}

const Map<StockCategory, StockCategoryInfo> _categoryInfo = {
  StockCategory.shinkansen: StockCategoryInfo(
    StockCategory.shinkansen,
    '新幹線',
    Color(0xFF0B7A3B),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.emu: StockCategoryInfo(
    StockCategory.emu,
    '電車',
    Color(0xFF2D7DD2),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.dmu: StockCategoryInfo(
    StockCategory.dmu,
    '気動車',
    Color(0xFFCC6A28),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.electricLoco: StockCategoryInfo(
    StockCategory.electricLoco,
    '電気機関車',
    Color(0xFF3B4A8C),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.dieselLoco: StockCategoryInfo(
    StockCategory.dieselLoco,
    'ディーゼル機関車',
    Color(0xFFC1492E),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.steamLoco: StockCategoryInfo(
    StockCategory.steamLoco,
    '蒸気機関車',
    Color(0xFF3A3D44),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.electroDieselMu: StockCategoryInfo(
    StockCategory.electroDieselMu,
    '電気式気動車',
    Color(0xFF2BA6A0),
    CupertinoIcons.tram_fill,
  ),
  StockCategory.unknown: StockCategoryInfo(
    StockCategory.unknown,
    '車両',
    Color(0xFF646B78),
    CupertinoIcons.tram_fill,
  ),
};

StockCategoryInfo stockCategoryInfo(StockCategory category) =>
    _categoryInfo[category]!;

/// 运营公司代表色（JR / 国铁 / 私铁的真实企业色，铁道迷一眼能认）。
/// key 用子串匹配，可同时命中日文与英文写法。
const List<(List<String>, Color)> _operatorColors = [
  (['JR北海道', 'JR Hokkaido'], Color(0xFF8FC320)),
  (['JR東日本', 'JR East'], Color(0xFF00863C)),
  (['JR東海', 'JR Central', 'JR Tokai'], Color(0xFFF77F00)),
  (['JR西日本', 'JR West'], Color(0xFF0072BC)),
  (['JR四国', 'JR Shikoku'], Color(0xFF00ACD1)),
  (['JR九州', 'JR Kyushu'], Color(0xFFE60012)),
  (['JR貨物', 'JR Freight'], Color(0xFF003F98)),
  (['国鉄', 'JNR'], Color(0xFF6B3A2A)),
  (['東急', 'Tokyu'], Color(0xFFE2231A)),
  (['東京メトロ', 'Tokyo Metro'], Color(0xFF009BBF)),
  (['都営', 'Toei'], Color(0xFF009A44)),
];

Color? operatorColor(String? operator) {
  if (operator == null || operator.isEmpty) {
    return null;
  }
  for (final entry in _operatorColors) {
    for (final key in entry.$1) {
      if (operator.contains(key)) {
        return entry.$2;
      }
    }
  }
  return null;
}

/// 由 label 直接查到的车辆元数据（来自打包进 app 的标签表，源于数据集）。
/// 这让「只要有 label」就能拿到 wiki / 车种 / 运营公司 / 动力，零后端改动。
class StockMeta {
  const StockMeta({
    this.wiki,
    this.type,
    this.power,
    this.operatorJp,
    this.operatorEn,
    this.fullName,
  });

  final String? wiki; // wiki_title
  final String? type; // 新幹線電車 / 電車 / 電気機関車 / ...
  final String? power; // EMU / DMU / Electric Locomotive / ...
  final String? operatorJp;
  final String? operatorEn;
  final String? fullName;

  static StockMeta fromJson(Map<String, dynamic> json) => StockMeta(
    wiki: json['wiki']?.toString(),
    type: json['type']?.toString(),
    power: json['power']?.toString(),
    operatorJp: json['op_jp']?.toString(),
    operatorEn: json['op_en']?.toString(),
    fullName: json['full']?.toString(),
  );
}

Map<String, StockMeta> _catalog = const {};

/// 启动时加载标签表。失败（缺资源）时静默降级，不影响 app 运行。
Future<void> loadRollingStockCatalog() async {
  try {
    final raw = await rootBundle.loadString(
      'assets/rolling_stock_catalog.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _catalog = decoded.map(
        (key, value) => MapEntry(
          key,
          StockMeta.fromJson((value as Map).cast<String, dynamic>()),
        ),
      );
    }
  } catch (_) {
    _catalog = const {};
  }
}

/// 按 label 查标签表；精确不中时退回基础系列名再查一次。
StockMeta? catalogLookup(String label) {
  return _catalog[label] ?? _catalog[parseSeries(label).base];
}

/// 由维基页面的「車種(type)」解析类别——这是唯一能区分新幹線的来源。
StockCategory categoryFromType(String? type) {
  if (type == null || type.isEmpty) {
    return StockCategory.unknown;
  }
  if (type.contains('新幹線')) {
    return StockCategory.shinkansen;
  }
  if (type.contains('蒸気')) {
    return StockCategory.steamLoco;
  }
  if (type.contains('電気機関車')) {
    return StockCategory.electricLoco;
  }
  if (type.contains('ディーゼル機関車') || type.contains('ハイブリッド機関車')) {
    return StockCategory.dieselLoco;
  }
  if (type.contains('両用') || type.contains('EDC')) {
    return StockCategory.electroDieselMu;
  }
  if (type.contains('気動車')) {
    return StockCategory.dmu;
  }
  if (type.contains('電車')) {
    return StockCategory.emu;
  }
  return StockCategory.unknown;
}

/// 从 power_type 字符串解析类别（后端给出时为准）。
StockCategory categoryFromPowerType(String? powerType) {
  if (powerType == null) {
    return StockCategory.unknown;
  }
  switch (powerType.trim().toLowerCase()) {
    case 'emu':
      return StockCategory.emu;
    case 'dmu':
      return StockCategory.dmu;
    case 'electric locomotive':
      return StockCategory.electricLoco;
    case 'diesel locomotive':
      return StockCategory.dieselLoco;
    case 'steam locomotive':
      return StockCategory.steamLoco;
    case 'electro-diesel multiple unit':
      return StockCategory.electroDieselMu;
    default:
      return StockCategory.unknown;
  }
}

/// 后端暂未给 power_type 时，从标签命名规则保守推断类别。
/// EF/ED/EH 形→电力机车，DD/DE/DF 形→柴油机车，C/D 单字母+形→蒸汽机车，
/// キ…→气动车，…系→电车，其余未知。
StockCategory categoryFromLabel(String label) {
  final l = label.trim();
  if (RegExp(r'^[A-Z]{2}\d').hasMatch(l)) {
    return l.startsWith('D')
        ? StockCategory.dieselLoco
        : StockCategory.electricLoco;
  }
  if (RegExp(r'^[BCD]\d').hasMatch(l) && l.contains('形')) {
    return StockCategory.steamLoco;
  }
  if (l.startsWith('キ')) {
    return StockCategory.dmu;
  }
  if (l.contains('系')) {
    return StockCategory.emu;
  }
  return StockCategory.unknown;
}

/// 综合解析类别：车种(type，能识别新幹線)优先 → power_type → 标签推断。
StockCategory resolveCategory({
  String? type,
  String? powerType,
  required String label,
}) {
  final fromType = categoryFromType(type);
  if (fromType != StockCategory.unknown) {
    return fromType;
  }
  final fromPower = categoryFromPowerType(powerType);
  if (fromPower != StockCategory.unknown) {
    return fromPower;
  }
  return categoryFromLabel(label);
}

/// 卡片主色：运营公司色优先（最有「铁道」辨识度），否则类别色。
Color resolveStockColor({
  String? operator,
  String? type,
  String? powerType,
  required String label,
}) {
  return operatorColor(operator) ??
      stockCategoryInfo(
        resolveCategory(type: type, powerType: powerType, label: label),
      ).color;
}

/// 把标签拆成「基础系列 + 番台/特别编成」两部分，便于大字 + 副标题排版。
class SeriesParts {
  const SeriesParts(this.base, this.variant);

  final String base;
  final String? variant;
}

SeriesParts parseSeries(String label) {
  final l = label.trim();
  final paren = RegExp(r'^(.*?)[（(](.+?)[)）]\s*$').firstMatch(l);
  if (paren != null) {
    final base = paren.group(1)!.trim();
    final variant = paren.group(2)!.trim();
    if (base.isNotEmpty) {
      return SeriesParts(base, variant.isEmpty ? null : variant);
    }
  }
  final dash = RegExp(r'^(.+?[系形])-(.+)$').firstMatch(l);
  if (dash != null) {
    return SeriesParts(dash.group(1)!.trim(), dash.group(2)!.trim());
  }
  return SeriesParts(l, null);
}

/// 由 wiki_title 生成日文维基百科链接（保留 #章节锚点）。
String? wikipediaUrl(String? wikiTitle) {
  if (wikiTitle == null || wikiTitle.trim().isEmpty) {
    return null;
  }
  final title = wikiTitle.trim();
  const base = 'https://ja.wikipedia.org/wiki/';
  final hash = title.indexOf('#');
  if (hash >= 0) {
    final page = title.substring(0, hash);
    final fragment = title.substring(hash + 1);
    return '$base${Uri.encodeComponent(page)}#${Uri.encodeComponent(fragment)}';
  }
  return '$base${Uri.encodeComponent(title)}';
}
