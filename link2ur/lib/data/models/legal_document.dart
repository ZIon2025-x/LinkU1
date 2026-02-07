import 'package:equatable/equatable.dart';

/// 法律文档模型
/// 参考iOS LegalDocument.swift
class LegalDocument extends Equatable {
  const LegalDocument({
    required this.type,
    required this.lang,
    this.version,
    this.effectiveAt,
    this.contentJson,
  });

  final String type; // "terms", "privacy", "cookie"
  final String lang;
  final String? version;
  final String? effectiveAt;
  final Map<String, dynamic>? contentJson;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      type: json['type'] as String? ?? '',
      lang: json['lang'] as String? ?? '',
      version: json['version'] as String?,
      effectiveAt: json['effective_at'] as String?,
      contentJson: json['content_json'] as Map<String, dynamic>?,
    );
  }

  /// 将 content_json 转为可遍历的「标题 + 段落」列表
  List<LegalSection> get sections {
    if (contentJson == null) return [];
    final order = _orderKeys(type);
    if (order.isEmpty) return _sectionsFallback(contentJson!);

    final result = <LegalSection>[];
    for (final key in order) {
      final value = contentJson![key];
      if (value == null) continue;

      if (value is String) {
        if (key == 'title') continue;
        result.add(LegalSection(title: key, paragraphs: [value]));
      } else if (value is Map<String, dynamic>) {
        var title = '';
        final paragraphs = <String>[];
        final innerOrder = _objectParagraphOrder(value);
        for (final k in innerOrder) {
          final v = value[k];
          if (v is! String) continue;
          if (k == 'title') {
            title = v;
          } else {
            paragraphs.add(v);
          }
        }
        if (title.isNotEmpty || paragraphs.isNotEmpty) {
          result.add(LegalSection(title: title, paragraphs: paragraphs));
        }
      }
    }
    return result;
  }

  /// 获取标题
  String? get title {
    if (contentJson == null) return null;
    final value = contentJson!['title'];
    return value is String ? value : null;
  }

  /// 按文档类型固定的 key 顺序
  static List<String> _orderKeys(String documentType) {
    switch (documentType) {
      case 'terms':
        return [
          'title', 'lastUpdated', 'version', 'effectiveDate', 'jurisdiction',
          'operatorInfo', 'operator', 'contact', 'serviceNature', 'userTypes',
          'platformPosition', 'feesAndRules', 'pointsRules', 'couponRules',
          'paymentAndRefund', 'prohibitedTasks', 'userBehavior',
          'userResponsibilities', 'intellectualProperty', 'privacyData',
          'disclaimer', 'termination', 'disputes', 'forumTerms',
          'fleaMarketTerms', 'consumerAppendix', 'importantNotice',
        ];
      case 'privacy':
        return [
          'title', 'lastUpdated', 'version', 'effectiveDate', 'controller',
          'operator', 'contactEmail', 'address', 'dpoNote', 'dataCollection',
          'dataSharing', 'internationalTransfer', 'retentionPeriod',
          'yourRights', 'cookies', 'contactUs', 'importantNotice',
        ];
      case 'cookie':
        return [
          'title', 'version', 'effectiveDate', 'jurisdiction', 'intro',
          'whatAreCookies', 'typesWeUse', 'thirdParty', 'retention',
          'howToManage', 'mobileTech', 'yourRights', 'contactUs',
          'importantNotice', 'necessary', 'optional', 'contact',
        ];
      default:
        return [];
    }
  }

  /// 子对象内段落顺序
  static List<String> _objectParagraphOrder(Map<String, dynamic> obj) {
    final priorityOrder = ['title', 'introduction'];
    final keys = obj.keys.toList();
    keys.sort((a, b) {
      final ia = priorityOrder.indexOf(a);
      final ib = priorityOrder.indexOf(b);
      if (ia != -1 || ib != -1) {
        return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
      }
      // 处理 p1, p2... 数字序
      final pa = a.startsWith('p') ? int.tryParse(a.substring(1)) : null;
      final pb = b.startsWith('p') ? int.tryParse(b.substring(1)) : null;
      if (pa != null && pb != null) return pa.compareTo(pb);
      if (pa != null) return -1;
      if (pb != null) return 1;
      return a.compareTo(b);
    });
    return keys;
  }

  /// 未知类型回退
  static List<LegalSection> _sectionsFallback(Map<String, dynamic> dict) {
    final result = <LegalSection>[];
    final sortedKeys = dict.keys.toList()..sort();
    for (final key in sortedKeys) {
      final value = dict[key];
      if (value is String) {
        if (key == 'title') continue;
        result.add(LegalSection(title: key, paragraphs: [value]));
      } else if (value is Map<String, dynamic>) {
        var title = '';
        final paragraphs = <String>[];
        for (final k in _objectParagraphOrder(value)) {
          final v = value[k];
          if (v is! String) continue;
          if (k == 'title') {
            title = v;
          } else {
            paragraphs.add(v);
          }
        }
        if (title.isNotEmpty || paragraphs.isNotEmpty) {
          result.add(LegalSection(title: title, paragraphs: paragraphs));
        }
      }
    }
    return result;
  }

  @override
  List<Object?> get props => [type, lang, version];
}

/// 法律文档章节
class LegalSection extends Equatable {
  const LegalSection({
    this.title = '',
    this.paragraphs = const [],
  });

  final String title;
  final List<String> paragraphs;

  @override
  List<Object?> get props => [title, paragraphs];
}
