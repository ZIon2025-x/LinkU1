import 'package:equatable/equatable.dart';

/// FAQ 列表响应
class FaqListResponse extends Equatable {
  const FaqListResponse({this.sections = const []});

  final List<FaqSection> sections;

  factory FaqListResponse.fromJson(Map<String, dynamic> json) {
    return FaqListResponse(
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => FaqSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [sections];
}

/// FAQ 分区
class FaqSection extends Equatable {
  const FaqSection({
    required this.id,
    required this.key,
    required this.title,
    this.items = const [],
    this.sortOrder = 0,
  });

  final int id;
  final String key;
  final String title;
  final List<FaqItem> items;
  final int sortOrder;

  factory FaqSection.fromJson(Map<String, dynamic> json) {
    return FaqSection(
      id: json['id'] as int,
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, key, title];
}

/// FAQ 条目
class FaqItem extends Equatable {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.sortOrder = 0,
  });

  final int id;
  final String question;
  final String answer;
  final int sortOrder;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as int,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, question];
}
