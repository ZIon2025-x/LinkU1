import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../data/models/user.dart' show UserProfilePersonalService;
import '../../../data/repositories/user_repository.dart';
import 'widgets/personal_services_section.dart' show PersonalServiceCard;

/// 「TA 的个人服务」独立页 — 分页加载用户全部个人服务。
class UserPersonalServicesView extends StatefulWidget {
  const UserPersonalServicesView({
    super.key,
    required this.userId,
    this.totalServices,
  });

  final String userId;
  final int? totalServices;

  @override
  State<UserPersonalServicesView> createState() =>
      _UserPersonalServicesViewState();
}

class _UserPersonalServicesViewState extends State<UserPersonalServicesView> {
  static const _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<UserProfilePersonalService> _services = [];

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _services.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final repo = context.read<UserRepository>();
      final data = await repo.getUserPersonalServices(widget.userId);
      if (!mounted) return;
      setState(() {
        _services.addAll(data);
        _hasMore = data.length >= _pageSize;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<UserRepository>();
      final next = _page + 1;
      final data = await repo.getUserPersonalServices(
        widget.userId,
        page: next,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _services.addAll(data);
        _hasMore = data.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = (widget.totalServices ?? 0) > 0
        ? l10n.profilePersonalServicesCount(widget.totalServices!)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profilePersonalServices,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                ),
              ),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_initialLoading) {
      return const SkeletonList(imageSize: 90);
    }
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _loadInitial);
    }
    if (_services.isEmpty) {
      return EmptyStateView.noData(
        context,
        title: context.l10n.profileNoServicesYet,
      );
    }

    final locale = Localizations.localeOf(context);
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _services.length + 1,
        itemBuilder: (context, index) {
          if (index == _services.length) {
            if (_hasMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  context.l10n.profileNoMoreServices,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9FA5),
                  ),
                ),
              ),
            );
          }
          final s = _services[index];
          return Padding(
            key: ValueKey('service_${s.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: PersonalServiceCard(service: s, locale: locale),
          );
        },
      ),
    );
  }
}
