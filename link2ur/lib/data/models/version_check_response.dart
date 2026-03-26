import 'package:equatable/equatable.dart';

/// 应用版本检查响应模型
/// 参考后端 /api/app/version-check 响应
class VersionCheckResponse extends Equatable {
  const VersionCheckResponse({
    required this.latestVersion,
    required this.minVersion,
    required this.forceUpdate,
    required this.updateUrl,
    this.releaseNotes = '',
  });

  final String latestVersion;
  final String minVersion;
  final bool forceUpdate;
  final String updateUrl;
  final String releaseNotes;

  factory VersionCheckResponse.fromJson(Map<String, dynamic> json) {
    return VersionCheckResponse(
      latestVersion: json['latest_version'] as String? ?? '0.0.0',
      minVersion: json['min_version'] as String? ?? '0.0.0',
      forceUpdate: json['force_update'] as bool? ?? false,
      updateUrl: json['update_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'min_version': minVersion,
      'force_update': forceUpdate,
      'update_url': updateUrl,
      'release_notes': releaseNotes,
    };
  }

  VersionCheckResponse copyWith({
    String? latestVersion,
    String? minVersion,
    bool? forceUpdate,
    String? updateUrl,
    String? releaseNotes,
  }) {
    return VersionCheckResponse(
      latestVersion: latestVersion ?? this.latestVersion,
      minVersion: minVersion ?? this.minVersion,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      updateUrl: updateUrl ?? this.updateUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
    );
  }

  @override
  List<Object?> get props =>
      [latestVersion, minVersion, forceUpdate, updateUrl, releaseNotes];
}
