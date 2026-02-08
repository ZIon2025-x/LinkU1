---
name: flutter-feature-scaffold
description: Generate a complete Flutter feature scaffold following the project's BLoC + Clean Architecture pattern. Use when the user asks to create a new feature, add a new module, scaffold a feature, or generate boilerplate for a new feature in the Link2Ur Flutter app.
---

# Flutter Feature Scaffold

Generate a complete feature module for the Link2Ur Flutter app, matching existing architecture patterns exactly.

## Prerequisites

Before scaffolding, gather from the user:
1. **Feature name** (e.g., `reward`, `review`) — used for directory/class naming
2. **Chinese name** (e.g., `奖励`, `评价`) — used in comments and error messages
3. **API prefix** (e.g., `/api/rewards`) — the backend route prefix
4. **Core entities** — the main model(s) and their key fields
5. **Key operations** — list/detail/create/update/delete or custom actions

If the user only gives a feature name, ask for the rest before proceeding.

## Naming Conventions

All naming derives from the feature name (example: `reward`):

| Item | Pattern | Example |
|------|---------|---------|
| Directory | `lib/features/{name}/` | `lib/features/reward/` |
| Bloc class | `{Name}Bloc` | `RewardBloc` |
| Events base | `{Name}Event` | `RewardEvent` |
| State class | `{Name}State` | `RewardState` |
| Status enum | `{Name}Status` | `RewardStatus` |
| Repository | `{Name}Repository` | `RewardRepository` |
| Exception | `{Name}Exception` | `RewardException` |
| View | `{Name}View` | `RewardView` |
| Route path | `/{kebab-name}` | `/reward` |
| Route name | `'{camelName}'` | `'reward'` |
| Detail route | `/{kebab-name}/:id` | `/reward/:id` |

## File Structure to Generate

```
lib/features/{name}/
├── bloc/
│   └── {name}_bloc.dart        # Events + State + Bloc in one file
└── views/
    ├── {name}_view.dart         # List view
    └── {name}_detail_view.dart  # Detail view (if needed)

lib/data/repositories/{name}_repository.dart
```

Also modify:
- `lib/core/constants/api_endpoints.dart` — add endpoint constants
- `lib/app.dart` — register repository + (optional) root-level bloc
- `lib/core/router/app_router.dart` — add routes + extension methods

## Templates

### 1. BLoC File (`lib/features/{name}/bloc/{name}_bloc.dart`)

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/{name}.dart';
import '../../../data/repositories/{name}_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class {Name}Event extends Equatable {
  const {Name}Event();

  @override
  List<Object?> get props => [];
}

class {Name}LoadRequested extends {Name}Event {
  const {Name}LoadRequested();
}

class {Name}LoadMore extends {Name}Event {
  const {Name}LoadMore();
}

class {Name}RefreshRequested extends {Name}Event {
  const {Name}RefreshRequested();
}

class {Name}LoadDetail extends {Name}Event {
  const {Name}LoadDetail(this.{name}Id);

  final int {name}Id;

  @override
  List<Object?> get props => [{name}Id];
}

// ==================== State ====================

enum {Name}Status { initial, loading, loaded, error }

class {Name}State extends Equatable {
  const {Name}State({
    this.status = {Name}Status.initial,
    this.{name}s = const [],
    this.selected{Name},
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
  });

  final {Name}Status status;
  final List<{Model}> {name}s;
  final {Model}? selected{Name};
  final int total;
  final int page;
  final bool hasMore;
  final String? errorMessage;

  bool get isLoading => status == {Name}Status.loading;

  {Name}State copyWith({
    {Name}Status? status,
    List<{Model}>? {name}s,
    {Model}? selected{Name},
    int? total,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return {Name}State(
      status: status ?? this.status,
      {name}s: {name}s ?? this.{name}s,
      selected{Name}: selected{Name} ?? this.selected{Name},
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status, {name}s, selected{Name}, total, page, hasMore, errorMessage,
      ];
}

// ==================== Bloc ====================

class {Name}Bloc extends Bloc<{Name}Event, {Name}State> {
  {Name}Bloc({required {Name}Repository {name}Repository})
      : _{name}Repository = {name}Repository,
        super(const {Name}State()) {
    on<{Name}LoadRequested>(_onLoadRequested);
    on<{Name}LoadMore>(_onLoadMore);
    on<{Name}RefreshRequested>(_onRefresh);
    on<{Name}LoadDetail>(_onLoadDetail);
  }

  final {Name}Repository _{name}Repository;

  Future<void> _onLoadRequested(
    {Name}LoadRequested event,
    Emitter<{Name}State> emit,
  ) async {
    emit(state.copyWith(status: {Name}Status.loading));

    try {
      final response = await _{name}Repository.get{Name}s(page: 1);

      emit(state.copyWith(
        status: {Name}Status.loaded,
        {name}s: response.items,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load {name}s', e);
      emit(state.copyWith(
        status: {Name}Status.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMore(
    {Name}LoadMore event,
    Emitter<{Name}State> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final response = await _{name}Repository.get{Name}s(page: nextPage);

      emit(state.copyWith(
        {name}s: [...state.{name}s, ...response.items],
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more {name}s', e);
      emit(state.copyWith(hasMore: false));
    }
  }

  Future<void> _onRefresh(
    {Name}RefreshRequested event,
    Emitter<{Name}State> emit,
  ) async {
    try {
      final response = await _{name}Repository.get{Name}s(page: 1);

      emit(state.copyWith(
        status: {Name}Status.loaded,
        {name}s: response.items,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh {name}s', e);
    }
  }

  Future<void> _onLoadDetail(
    {Name}LoadDetail event,
    Emitter<{Name}State> emit,
  ) async {
    emit(state.copyWith(status: {Name}Status.loading));

    try {
      final item = await _{name}Repository.get{Name}ById(event.{name}Id);

      emit(state.copyWith(
        status: {Name}Status.loaded,
        selected{Name}: item,
      ));
    } catch (e) {
      AppLogger.error('Failed to load {name} detail', e);
      emit(state.copyWith(
        status: {Name}Status.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
```

### 2. Repository (`lib/data/repositories/{name}_repository.dart`)

```dart
import '../models/{name}.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// {ChineseName}仓库
class {Name}Repository {
  {Name}Repository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取{ChineseName}列表
  Future<{Name}ListResponse> get{Name}s({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.{name}s,
      queryParameters: {'page': page, 'page_size': pageSize},
    );

    if (!response.isSuccess || response.data == null) {
      throw {Name}Exception(response.message ?? '获取{ChineseName}列表失败');
    }

    return {Name}ListResponse.fromJson(response.data!);
  }

  /// 获取{ChineseName}详情
  Future<{Model}> get{Name}ById(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.{name}ById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw {Name}Exception(response.message ?? '获取{ChineseName}详情失败');
    }

    return {Model}.fromJson(response.data!);
  }
}

/// {ChineseName}异常
class {Name}Exception extends AppException {
  const {Name}Exception(super.message);
}
```

### 3. List View (`lib/features/{name}/views/{name}_view.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/{name}_repository.dart';
import '../bloc/{name}_bloc.dart';

/// {ChineseName}页
class {Name}View extends StatelessWidget {
  const {Name}View({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => {Name}Bloc(
        {name}Repository: context.read<{Name}Repository>(),
      )..add(const {Name}LoadRequested()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('{ChineseName}'),
        ),
        body: BlocBuilder<{Name}Bloc, {Name}State>(
          builder: (context, state) {
            if (state.status == {Name}Status.loading &&
                state.{name}s.isEmpty) {
              return const SkeletonList();
            }

            if (state.status == {Name}Status.error &&
                state.{name}s.isEmpty) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '加载失败',
                onRetry: () {
                  context.read<{Name}Bloc>().add(
                        const {Name}LoadRequested(),
                      );
                },
              );
            }

            if (state.{name}s.isEmpty) {
              return EmptyStateView.noData(
                title: '暂无{ChineseName}',
                description: '还没有{ChineseName}数据',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<{Name}Bloc>().add(
                      const {Name}RefreshRequested(),
                    );
              },
              child: ListView.separated(
                clipBehavior: Clip.none,
                padding: AppSpacing.allMd,
                itemCount: state.{name}s.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => AppSpacing.vMd,
                itemBuilder: (context, index) {
                  if (index == state.{name}s.length) {
                    context.read<{Name}Bloc>().add(const {Name}LoadMore());
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: LoadingIndicator(),
                      ),
                    );
                  }
                  final item = state.{name}s[index];
                  return _{Name}Card({name}: item);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// {ChineseName}卡片
class _{Name}Card extends StatelessWidget {
  const _{Name}Card({required this.{name}});

  final {Model} {name};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.push('/{kebab-name}/${{{name}.id}}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO: Implement card content based on model fields
            Text(
              '{name}.displayName',
              style: AppTypography.bodyBold.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4. Detail View (`lib/features/{name}/views/{name}_detail_view.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/{name}_repository.dart';
import '../bloc/{name}_bloc.dart';

/// {ChineseName}详情页
class {Name}DetailView extends StatelessWidget {
  const {Name}DetailView({super.key, required this.{name}Id});

  final int {name}Id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => {Name}Bloc(
        {name}Repository: context.read<{Name}Repository>(),
      )..add({Name}LoadDetail({name}Id)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('{ChineseName}详情'),
        ),
        body: BlocBuilder<{Name}Bloc, {Name}State>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: LoadingIndicator());
            }

            if (state.status == {Name}Status.error) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '加载失败',
                onRetry: () {
                  context.read<{Name}Bloc>().add(
                        {Name}LoadDetail({name}Id),
                      );
                },
              );
            }

            final item = state.selected{Name};
            if (item == null) {
              return const Center(child: LoadingIndicator());
            }

            return SingleChildScrollView(
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TODO: Implement detail content based on model fields
                  Text(
                    'Detail content here',
                    style: AppTypography.bodyBold,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
```

## Modifications to Existing Files

### 5. API Endpoints (`lib/core/constants/api_endpoints.dart`)

Add a new section following the existing pattern:

```dart
  // ==================== {ChineseName} ====================
  // 后端: {backend_file}.py (prefix: {api_prefix})
  static const String {name}s = '{api_prefix}';
  static String {name}ById(int id) => '{api_prefix}/$id';
  // Add more endpoints as needed
```

### 6. app.dart Registration

Add to imports:
```dart
import 'data/repositories/{name}_repository.dart';
```

Add to `_Link2UrAppState` fields:
```dart
late final {Name}Repository _{name}Repository;
```

Add to `initState()`:
```dart
_{name}Repository = {Name}Repository(apiService: _apiService);
```

Add to `MultiRepositoryProvider.providers`:
```dart
RepositoryProvider<{Name}Repository>.value(value: _{name}Repository),
```

### 7. Router (`lib/core/router/app_router.dart`)

Add to imports:
```dart
import '../../features/{name}/views/{name}_view.dart';
import '../../features/{name}/views/{name}_detail_view.dart';
```

Add to `AppRoutes`:
```dart
  static const String {name} = '/{kebab-name}';
  static const String {name}Detail = '/{kebab-name}/:id';
```

Add to `GoRouter.routes`:
```dart
  GoRoute(
    path: AppRoutes.{name},
    name: '{name}',
    builder: (context, state) => const {Name}View(),
  ),
  GoRoute(
    path: AppRoutes.{name}Detail,
    name: '{name}Detail',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return {Name}DetailView({name}Id: id);
    },
  ),
```

Add to `GoRouterExtension`:
```dart
  /// 跳转到{ChineseName}详情
  void goTo{Name}Detail(int {name}Id) {
    push('/{kebab-name}/${name}Id');
  }
```

## Execution Checklist

When scaffolding, work through this checklist in order:

```
- [ ] 1. Create directory: lib/features/{name}/bloc/
- [ ] 2. Create directory: lib/features/{name}/views/
- [ ] 3. Create BLoC file: lib/features/{name}/bloc/{name}_bloc.dart
- [ ] 4. Create repository: lib/data/repositories/{name}_repository.dart
- [ ] 5. Create list view: lib/features/{name}/views/{name}_view.dart
- [ ] 6. Create detail view: lib/features/{name}/views/{name}_detail_view.dart
- [ ] 7. Add endpoints to: lib/core/constants/api_endpoints.dart
- [ ] 8. Register repository in: lib/app.dart
- [ ] 9. Add routes to: lib/core/router/app_router.dart
- [ ] 10. Verify: flutter analyze (no errors)
```

## Important Notes

- **Model file**: This skill does NOT generate model files (`lib/data/models/`). Models depend heavily on backend schema and should be created separately.
- **Single-file BLoC**: Events, State, and Bloc go in ONE file (not split with `part`), matching the project convention for most features.
- **Error handling**: Repositories throw custom `{Name}Exception extends AppException`. Blocs catch and store `errorMessage`.
- **Caching**: Only add `CacheManager` usage in repository if the data changes infrequently. Ask the user.
- **Localization**: Use hardcoded Chinese strings initially. The user will add ARB keys separately. Use `context.l10n.xxx` when keys exist.
- **Imports**: Always use relative imports (`../../../`) not package imports.
- **Flutter environment**: When running `flutter analyze`, set environment per [flutter-environment rule](../../rules/flutter-environment.mdc).
