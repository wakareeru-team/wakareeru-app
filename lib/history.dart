import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rolling_stock.dart';

/// 一条本地识别记录。只存元数据（不存原图），保证 shared_preferences 轻量。
/// 颜色/类别在渲染时由 rolling_stock 重新推导，避免存储里有过时的色值。
class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.label,
    required this.confidence,
    this.operatorJp,
    this.operatorEn,
    this.powerType,
    this.wikiTitle,
    this.bandai,
    this.submodel,
    this.specialFormation,
    this.specialLivery,
    this.thumbnailPath,
  });

  /// 同时作为唯一键与排序键（microsecondsSinceEpoch）。
  final int id;
  final String label;
  final double confidence;
  final String? operatorJp;
  final String? operatorEn;
  final String? powerType;
  final String? wikiTitle;
  final String? bandai;
  final String? submodel;
  final String? specialFormation;
  final String? specialLivery;
  final String? thumbnailPath;

  StockMeta? get _meta => catalogLookup(label);

  String? get operatorJpEffective => operatorJp ?? _meta?.operatorJp;
  String? get operatorEnEffective => operatorEn ?? _meta?.operatorEn;
  String? get operator => operatorJpEffective ?? operatorEnEffective;
  String? get powerTypeEffective => powerType ?? _meta?.power;
  String? get stockType => _meta?.type;
  String? get wikiTitleEffective => wikiTitle ?? _meta?.wiki;

  DateTime get time => DateTime.fromMicrosecondsSinceEpoch(id);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'confidence': confidence,
    if (operatorJp != null) 'operator_jp': operatorJp,
    if (operatorEn != null) 'operator_en': operatorEn,
    if (powerType != null) 'power_type': powerType,
    if (wikiTitle != null) 'wiki_title': wikiTitle,
    if (bandai != null) 'bandai': bandai,
    if (submodel != null) 'submodel': submodel,
    if (specialFormation != null) 'special_formation': specialFormation,
    if (specialLivery != null) 'special_livery': specialLivery,
    if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
  };

  static HistoryRecord? fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString();
    if (label == null || label.isEmpty) {
      return null;
    }
    final id = json['id'];
    return HistoryRecord(
      id: id is int
          ? id
          : int.tryParse(id?.toString() ?? '') ??
                DateTime.now().microsecondsSinceEpoch,
      label: label,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      operatorJp: json['operator_jp']?.toString(),
      operatorEn: json['operator_en']?.toString(),
      powerType: json['power_type']?.toString(),
      wikiTitle: json['wiki_title']?.toString(),
      bandai: json['bandai']?.toString(),
      submodel: json['submodel']?.toString(),
      specialFormation: json['special_formation']?.toString(),
      specialLivery: json['special_livery']?.toString(),
      thumbnailPath: json['thumbnail_path']?.toString(),
    );
  }
}

/// 本地识别记录存储，基于 shared_preferences。作为 ChangeNotifier 驱动 UI 刷新。
class HistoryStore extends ChangeNotifier {
  static const String _key = 'wakareeru_history_v1';
  static const int _maxRecords = 200;

  final List<HistoryRecord> _records = [];
  bool _loaded = false;

  List<HistoryRecord> get records => List.unmodifiable(_records);
  bool get isLoaded => _loaded;
  bool get isEmpty => _records.isEmpty;

  int get seriesCount => _records.map((r) => r.label).toSet().length;
  int get operatorCount =>
      _records.map((r) => r.operator).whereType<String>().toSet().length;
  int get recordCount => _records.length;

  Future<void> load() async {
    _records.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final record = HistoryRecord.fromJson(item);
              if (record != null) {
                _records.add(record);
              }
            }
          }
        }
      }
    } catch (_) {
      // 存储不可用或数据损坏时，从空记录开始（不影响 app 运行）。
    }
    _records.sort((a, b) => b.id.compareTo(a.id));
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(HistoryRecord record) async {
    _records.insert(0, record);
    final removed = <HistoryRecord>[];
    if (_records.length > _maxRecords) {
      removed.addAll(_records.skip(_maxRecords));
      _records.removeRange(_maxRecords, _records.length);
    }
    notifyListeners();
    await _persist();
    for (final record in removed) {
      await _deleteThumbnail(record.thumbnailPath);
    }
  }

  Future<void> removeById(int id) async {
    final removed = _records.where((record) => record.id == id).toList();
    _records.removeWhere((record) => record.id == id);
    notifyListeners();
    await _persist();
    for (final record in removed) {
      await _deleteThumbnail(record.thumbnailPath);
    }
  }

  Future<void> clear() async {
    final removed = List<HistoryRecord>.from(_records);
    _records.clear();
    notifyListeners();
    await _persist();
    for (final record in removed) {
      await _deleteThumbnail(record.thumbnailPath);
    }
  }

  Future<void> _deleteThumbnail(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 缩略图清理失败不影响记录操作。
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_records.map((record) => record.toJson()).toList()),
      );
    } catch (_) {
      // 存储失败时静默忽略，内存中的记录仍然可用。
    }
  }
}
