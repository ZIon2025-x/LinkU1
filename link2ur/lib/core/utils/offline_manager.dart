import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'logger.dart';
import 'network_monitor.dart';

/// 离线操作类型
enum OfflineOperationType { create, update, delete, custom }

/// 离线操作状态
enum OfflineOperationStatus {
  pending,
  syncing,
  completed,
  failed,
  cancelled,
}

/// 离线操作
class OfflineOperation {
  OfflineOperation({
    String? id,
    required this.type,
    required this.endpoint,
    required this.method,
    this.body,
    this.headers,
    DateTime? createdAt,
    this.status = OfflineOperationStatus.pending,
    this.retryCount = 0,
    this.lastError,
    this.syncedAt,
    this.resourceType,
    this.resourceId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final OfflineOperationType type;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final Map<String, String>? headers;
  final DateTime createdAt;
  OfflineOperationStatus status;
  int retryCount;
  String? lastError;
  DateTime? syncedAt;
  String? resourceType;
  String? resourceId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'headers': headers,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'retryCount': retryCount,
        'lastError': lastError,
        'syncedAt': syncedAt?.toIso8601String(),
        'resourceType': resourceType,
        'resourceId': resourceId,
      };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      type: OfflineOperationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => OfflineOperationType.custom),
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      body: json['body'] as Map<String, dynamic>?,
      headers: (json['headers'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: OfflineOperationStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OfflineOperationStatus.pending),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      resourceType: json['resourceType'] as String?,
      resourceId: json['resourceId'] as String?,
    );
  }
}

/// 冲突解决策略
enum ConflictResolutionStrategy {
  useLocal,
  useServer,
  merge,
  askUser,
}

/// 同步冲突
class SyncConflict {
  SyncConflict({
    required this.operation,
    required this.serverData,
    this.strategy = ConflictResolutionStrategy.useServer,
  });

  final OfflineOperation operation;
  final Map<String, dynamic>? serverData;
  final ConflictResolutionStrategy strategy;
}

/// 离线管理器
/// 对齐 iOS OfflineManager.swift
/// 管理离线操作队列、自动同步、冲突处理
class OfflineManager {
  OfflineManager._();
  static final OfflineManager instance = OfflineManager._();

  static const int _maxPendingOperations = 100;
  static const int _maxRetryCount = 3;
  static const String _operationsFileName = 'offline_operations.json';

  final List<OfflineOperation> _operations = [];
  StreamSubscription? _networkSubscription;
  bool _isSyncing = false;
  bool _initialized = false;

  /// 是否处于离线模式
  bool get isOfflineMode => !NetworkMonitor.instance.isConnected;

  /// 待同步操作数
  int get pendingCount => _operations
      .where((op) =>
          op.status == OfflineOperationStatus.pending ||
          op.status == OfflineOperationStatus.failed)
      .length;

  /// 冲突回调
  void Function(SyncConflict)? onConflict;

  /// 同步完成回调
  void Function(int successCount, int failCount)? onSyncComplete;

  /// 初始化
  Future<void> initialize() async {
    // 防止重复初始化导致旧订阅泄漏
    if (_initialized) {
      AppLogger.debug('OfflineManager - Already initialized, skipping');
      return;
    }

    // 加载持久化的操作
    await _loadOperations();

    // 监听网络状态
    _networkSubscription =
        NetworkMonitor.instance.statusStream.listen((status) {
      if (NetworkMonitor.instance.isConnected && !_isSyncing) {
        // 网络恢复，延迟 1 秒后同步
        Future.delayed(const Duration(seconds: 1), () => syncNow());
      }
    });

    _initialized = true;
    AppLogger.info('OfflineManager initialized with ${_operations.length} operations');
  }

  /// 添加离线操作
  Future<void> addOperation({
    required OfflineOperationType type,
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? resourceType,
    String? resourceId,
  }) async {
    if (_operations.length >= _maxPendingOperations) {
      AppLogger.warning('OfflineManager: Max pending operations reached');
      // 清除已完成的操作
      _operations.removeWhere(
          (op) => op.status == OfflineOperationStatus.completed);
    }

    final operation = OfflineOperation(
      type: type,
      endpoint: endpoint,
      method: method,
      body: body,
      headers: headers,
      resourceType: resourceType,
      resourceId: resourceId,
    );

    _operations.add(operation);
    await _saveOperations();

    AppLogger.info('OfflineManager: Operation added - ${operation.id}');

    // 如果在线，立即尝试同步
    if (!isOfflineMode) {
      syncNow();
    }
  }

  /// 取消操作
  Future<void> cancelOperation(String operationId) async {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index].status = OfflineOperationStatus.cancelled;
      await _saveOperations();
    }
  }

  /// 获取待同步操作
  List<OfflineOperation> getPendingOperations({
    String? resourceType,
    String? resourceId,
  }) {
    return _operations.where((op) {
      if (op.status != OfflineOperationStatus.pending &&
          op.status != OfflineOperationStatus.failed) {
        return false;
      }
      if (resourceType != null && op.resourceType != resourceType) return false;
      if (resourceId != null && op.resourceId != resourceId) return false;
      return true;
    }).toList();
  }

  /// 立即同步
  Future<void> syncNow() async {
    if (_isSyncing) return;
    if (isOfflineMode) return;

    _isSyncing = true;
    int successCount = 0;
    int failCount = 0;

    final pendingOps = _operations
        .where((op) =>
            (op.status == OfflineOperationStatus.pending ||
                op.status == OfflineOperationStatus.failed) &&
            op.retryCount < _maxRetryCount)
        .toList();

    for (final op in pendingOps) {
      op.status = OfflineOperationStatus.syncing;

      try {
        // 这里需要实际的网络请求
        // 由于不直接依赖 ApiService，使用 HttpClient
        final uri = Uri.parse(op.endpoint);
        final request = await HttpClient().openUrl(op.method, uri);

        // 添加 headers
        op.headers?.forEach((key, value) {
          request.headers.set(key, value);
        });

        if (op.body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(op.body));
        }

        final response = await request.close();
        final statusCode = response.statusCode;

        if (statusCode >= 200 && statusCode < 300) {
          op.status = OfflineOperationStatus.completed;
          op.syncedAt = DateTime.now();
          successCount++;
        } else if (statusCode == 409) {
          // 冲突
          final body = await response.transform(utf8.decoder).join();
          final serverData =
              jsonDecode(body) as Map<String, dynamic>?;
          onConflict?.call(SyncConflict(
            operation: op,
            serverData: serverData,
          ));
          op.status = OfflineOperationStatus.failed;
          op.lastError = 'Conflict (409)';
          failCount++;
        } else {
          op.status = OfflineOperationStatus.failed;
          op.retryCount++;
          op.lastError = 'HTTP $statusCode';
          failCount++;
        }
      } catch (e) {
        op.status = OfflineOperationStatus.failed;
        op.retryCount++;
        op.lastError = e.toString();
        failCount++;
        AppLogger.error('OfflineManager: Sync failed for ${op.id}', e);
      }
    }

    await _saveOperations();
    _isSyncing = false;

    if (pendingOps.isNotEmpty) {
      onSyncComplete?.call(successCount, failCount);
      AppLogger.info(
          'OfflineManager: Sync complete - $successCount success, $failCount failed');
    }
  }

  /// 清除已完成的操作
  Future<void> clearCompletedOperations() async {
    _operations.removeWhere(
        (op) => op.status == OfflineOperationStatus.completed);
    await _saveOperations();
  }

  /// 清除所有操作
  Future<void> clearAllOperations() async {
    _operations.clear();
    await _saveOperations();
  }

  /// 获取同步状态摘要
  Map<String, int> getSyncStatus() {
    final status = <String, int>{};
    for (final op in _operations) {
      final key = op.status.name;
      status[key] = (status[key] ?? 0) + 1;
    }
    return status;
  }

  // ==================== 持久化 ====================

  Future<void> _saveOperations() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_operationsFileName');
      final json = _operations.map((op) => op.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      AppLogger.error('OfflineManager: Save operations failed', e);
    }
  }

  Future<void> _loadOperations() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_operationsFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        _operations.clear();
        _operations.addAll(
            list.map((e) => OfflineOperation.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      AppLogger.error('OfflineManager: Load operations failed', e);
    }
  }

  /// 释放资源
  void dispose() {
    _networkSubscription?.cancel();
    _networkSubscription = null;
    _initialized = false;
  }
}

/// 离线数据存储
/// 简单的 JSON 文件存储，用于缓存离线数据
class OfflineDataStore {
  OfflineDataStore._();
  static final OfflineDataStore instance = OfflineDataStore._();

  String? _basePath;

  Future<String> get _dataPath async {
    if (_basePath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _basePath = '${dir.path}/OfflineData';
      await Directory(_basePath!).create(recursive: true);
    }
    return _basePath!;
  }

  /// 保存数据
  Future<void> save<T>(T data, {required String key}) async {
    try {
      final path = await _dataPath;
      final file = File('$path/$key.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      AppLogger.error('OfflineDataStore: Save failed for $key', e);
    }
  }

  /// 加载数据
  Future<T?> load<T>(String key, {T Function(dynamic)? fromJson}) async {
    try {
      final path = await _dataPath;
      final file = File('$path/$key.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        return fromJson != null ? fromJson(data) : data as T;
      }
    } catch (e) {
      AppLogger.error('OfflineDataStore: Load failed for $key', e);
    }
    return null;
  }

  /// 删除数据
  Future<void> remove({required String key}) async {
    try {
      final path = await _dataPath;
      final file = File('$path/$key.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.error('OfflineDataStore: Remove failed for $key', e);
    }
  }

  /// 检查数据是否存在
  Future<bool> exists({required String key}) async {
    final path = await _dataPath;
    return File('$path/$key.json').exists();
  }

  /// 清除所有离线数据
  Future<void> clearAll() async {
    try {
      final path = await _dataPath;
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      AppLogger.error('OfflineDataStore: Clear all failed', e);
    }
  }
}
