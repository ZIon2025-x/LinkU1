import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../features/forum/bloc/forum_bloc.dart';
import '../../../features/forum/views/forum_view.dart';
import '../../../data/models/forum.dart';
import '../../../features/forum/views/forum_post_detail_view.dart';
import '../../../features/forum/views/create_post_view.dart';
import '../../../features/forum/views/edit_post_view.dart';
import '../../../features/forum/views/pdf_preview_view.dart';
import '../../../features/forum/views/forum_category_request_view.dart';
import '../../../features/profile/views/my_forum_posts_view.dart';

/// 论坛相关路由（论坛页、发帖、分类申请、我的帖子、帖子详情）
List<RouteBase> get forumRoutes => [
      GoRoute(
        path: AppRoutes.forum,
        name: 'forum',
        builder: (context, state) => BlocProvider<ForumBloc>(
          create: (context) {
            final bloc = ForumBloc(
              forumRepository: context.read<ForumRepository>(),
            );
            bloc.add(const ForumLoadCategories());
            return bloc;
          },
          child: const ForumView(showLeaderboardTab: false),
        ),
      ),
      GoRoute(
        path: AppRoutes.createPost,
        name: 'createPost',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const CreatePostView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forumCategoryRequest,
        name: 'forumCategoryRequest',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const ForumCategoryRequestView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.myForumPosts,
        name: 'myForumPosts',
        builder: (context, state) => const MyForumPostsView(),
      ),
      GoRoute(
        path: AppRoutes.forumPdfPreview,
        name: 'forumPdfPreview',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final url = extra?['url'] as String?;
          final title = extra?['title'] as String?;
          if (url == null || url.isEmpty) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: Scaffold(
                body: Center(child: Text(AppLocalizations.of(context)?.forumPdfUrlMissing ?? 'Missing PDF URL')),
              ),
            );
          }
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: PdfPreviewView(url: url, title: title),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forumPostDetail,
        name: 'forumPostDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: Scaffold(
                  body: Center(child: Text(AppLocalizations.of(context)?.forumInvalidPostId ?? 'Invalid post ID'))),
            );
          }
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: ForumPostDetailView(postId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forumPostEdit,
        name: 'forumPostEdit',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          final extra = state.extra as Map<String, dynamic>?;
          final post = extra?['post'] as ForumPost?;
          final bloc = extra?['bloc'] as ForumBloc?;
          if (id == null || id <= 0 || post == null || bloc == null) {
            return SlideUpTransitionPage(
              key: state.pageKey,
              child: Scaffold(
                body: Center(child: Text(AppLocalizations.of(context)?.forumInvalidPostOrData ?? 'Invalid post or missing data')),
              ),
            );
          }
          return SlideUpTransitionPage(
            key: state.pageKey,
            child: BlocProvider<ForumBloc>.value(
              value: bloc,
              child: EditPostView(postId: id, post: post),
            ),
          );
        },
      ),
    ];
