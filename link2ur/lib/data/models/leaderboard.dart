import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';
import 'user.dart';

/// 排行榜模型
/// 参考后端 CustomLeaderboardOut
class Leaderboard extends Equatable {
  const Leaderboard({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    required this.location,
    this.description,
    this.descriptionEn,
    this.descriptionZh,
    this.rules,
    this.coverImage,
    required this.applicantId,
    this.applicant,
    this.status = 'active',
    this.itemCount = 0,
    this.voteCount = 0,
    this.viewCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String location;
  final String? description;
  final String? descriptionEn;
  final String? descriptionZh;
  final String? rules;
  final String? coverImage;
  final String applicantId;
  final UserBrief? applicant;
  final String status; // active, pending, rejected
  final int itemCount;
  final int voteCount;
  final int viewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 显示名称（根据 locale 选择 zh/en）
  String displayName(Locale locale) =>
      localizedString(nameZh, nameEn, name, locale);

  /// 显示描述（根据 locale 选择 zh/en）
  String? displayDescription(Locale locale) =>
      localizedStringOrNull(descriptionZh, descriptionEn, description, locale);

  /// 是否活跃
  bool get isActive => status == 'active';

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      location: json['location'] as String? ?? '',
      description: json['description'] as String?,
      descriptionEn: json['description_en'] as String?,
      descriptionZh: json['description_zh'] as String?,
      rules: json['rules'] as String?,
      coverImage: json['cover_image'] as String?,
      applicantId: json['applicant_id']?.toString() ?? '',
      applicant: json['applicant'] != null
          ? UserBrief.fromJson(json['applicant'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String? ?? 'active',
      itemCount: json['item_count'] as int? ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_en': nameEn,
      'name_zh': nameZh,
      'location': location,
      'description': description,
      'description_en': descriptionEn,
      'description_zh': descriptionZh,
      'rules': rules,
      'cover_image': coverImage,
      'applicant_id': applicantId,
      'status': status,
      'item_count': itemCount,
      'vote_count': voteCount,
      'view_count': viewCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, status, itemCount, updatedAt];
}

/// 排行榜项目模型
/// 参考后端 LeaderboardItemOut
class LeaderboardItem extends Equatable {
  const LeaderboardItem({
    required this.id,
    required this.leaderboardId,
    required this.name,
    this.description,
    this.address,
    this.phone,
    this.website,
    this.images,
    required this.submittedBy,
    this.submitterName,
    this.submitterAvatar,
    this.submitterId,
    this.status = 'approved',
    this.upvotes = 0,
    this.downvotes = 0,
    this.netVotes = 0,
    this.voteScore = 0.0,
    this.userVote,
    this.userVoteComment,
    this.userVoteIsAnonymous,
    this.displayComment,
    this.displayCommentType,
    this.displayCommentInfo,
    this.rank,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int leaderboardId;
  final String name;
  final String? description;
  final String? address;
  final String? phone;
  final String? website;
  final List<String>? images;
  final String submittedBy;
  final String? submitterName;
  final String? submitterAvatar;
  final String? submitterId;
  final String status;
  final int upvotes;
  final int downvotes;
  final int netVotes;
  final double voteScore;
  final String? userVote; // upvote, downvote, null
  final String? userVoteComment;
  final bool? userVoteIsAnonymous;
  final String? displayComment;
  final String? displayCommentType; // user, top
  final Map<String, dynamic>? displayCommentInfo;
  final int? rank;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 第一张图片
  String? get firstImage =>
      images != null && images!.isNotEmpty ? images!.first : null;

  /// 用户是否已投赞成票
  bool get hasUpvoted => userVote == 'upvote';

  /// 用户是否已投反对票
  bool get hasDownvoted => userVote == 'downvote';

  /// 是否已投票
  bool get hasVoted => userVote != null;

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      id: json['id'] as int,
      leaderboardId: json['leaderboard_id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      submittedBy: json['submitted_by']?.toString() ?? '',
      submitterName: json['submitter_name'] as String?,
      submitterAvatar: json['submitter_avatar'] as String?,
      submitterId: json['submitter_id']?.toString(),
      status: json['status'] as String? ?? 'approved',
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      netVotes: json['net_votes'] as int? ?? 0,
      voteScore: (json['vote_score'] as num?)?.toDouble() ?? 0.0,
      userVote: json['user_vote'] as String?,
      userVoteComment: json['user_vote_comment'] as String?,
      userVoteIsAnonymous: json['user_vote_is_anonymous'] as bool?,
      displayComment: json['display_comment'] as String?,
      displayCommentType: json['display_comment_type'] as String?,
      displayCommentInfo:
          json['display_comment_info'] as Map<String, dynamic>?,
      rank: json['rank'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leaderboard_id': leaderboardId,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'website': website,
      'images': images,
      'submitted_by': submittedBy,
      'submitter_name': submitterName,
      'submitter_avatar': submitterAvatar,
      'submitter_id': submitterId,
      'status': status,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'net_votes': netVotes,
      'vote_score': voteScore,
      'user_vote': userVote,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  LeaderboardItem copyWith({
    int? upvotes,
    int? downvotes,
    int? netVotes,
    double? voteScore,
    String? userVote,
    String? userVoteComment,
    bool? userVoteIsAnonymous,
  }) {
    return LeaderboardItem(
      id: id,
      leaderboardId: leaderboardId,
      name: name,
      description: description,
      address: address,
      phone: phone,
      website: website,
      images: images,
      submittedBy: submittedBy,
      submitterName: submitterName,
      submitterAvatar: submitterAvatar,
      submitterId: submitterId,
      status: status,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      netVotes: netVotes ?? this.netVotes,
      voteScore: voteScore ?? this.voteScore,
      userVote: userVote ?? this.userVote,
      userVoteComment: userVoteComment ?? this.userVoteComment,
      userVoteIsAnonymous: userVoteIsAnonymous ?? this.userVoteIsAnonymous,
      displayComment: displayComment,
      displayCommentType: displayCommentType,
      displayCommentInfo: displayCommentInfo,
      rank: rank,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, leaderboardId, name, netVotes, userVote, updatedAt];
}

/// 排行榜列表响应
class LeaderboardListResponse {
  const LeaderboardListResponse({
    required this.leaderboards,
    required this.total,
    required this.page,
    required this.pageSize,
    this.hasMoreFromServer,
  });

  final List<Leaderboard> leaderboards;
  final int total;
  final int page;
  final int pageSize;
  final bool? hasMoreFromServer;

  /// 后端返回 has_more 字段时优先使用，否则通过长度判断
  bool get hasMore => hasMoreFromServer ?? leaderboards.length >= pageSize;

  factory LeaderboardListResponse.fromJson(Map<String, dynamic> json) {
    // 后端公开接口返回 "items" key，收藏列表返回 "leaderboards" key
    final rawList = (json['items'] as List<dynamic>?) ??
        (json['leaderboards'] as List<dynamic>?) ??
        [];
    return LeaderboardListResponse(
      leaderboards: rawList
          .map((e) => Leaderboard.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? json['limit'] as int? ?? 20,
      hasMoreFromServer: json['has_more'] as bool?,
    );
  }
}
