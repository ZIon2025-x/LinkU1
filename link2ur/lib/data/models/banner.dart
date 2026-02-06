import 'package:equatable/equatable.dart';

/// 横幅/轮播图模型
/// 参考后端 Banner response
class Banner extends Equatable {
  const Banner({
    required this.id,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.linkUrl,
    this.linkType = 'internal',
    this.order = 0,
  });

  final int id;
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? linkUrl;
  final String linkType; // internal, external
  final int order;

  /// 是否有链接
  bool get hasLink => linkUrl != null && linkUrl!.isNotEmpty;

  /// 是否为外部链接
  bool get isExternalLink => linkType == 'external';

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      linkUrl: json['link_url'] as String?,
      linkType: json['link_type'] as String? ?? 'internal',
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'link_url': linkUrl,
      'link_type': linkType,
      'order': order,
    };
  }

  @override
  List<Object?> get props => [id, imageUrl, title];
}
