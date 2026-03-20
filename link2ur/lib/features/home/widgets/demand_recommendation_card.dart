import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_profile_repository.dart';

class DemandRecommendationCard extends StatefulWidget {
  const DemandRecommendationCard({super.key});

  @override
  State<DemandRecommendationCard> createState() => _DemandRecommendationCardState();
}

class _DemandRecommendationCardState extends State<DemandRecommendationCard> {
  UserDemand? _demand;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDemand();
  }

  Future<void> _loadDemand() async {
    try {
      final repo = context.read<UserProfileRepository>();
      final demand = await repo.getDemand();
      if (mounted) setState(() { _demand = demand; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _demand == null) return const SizedBox.shrink();

    final needs = _demand!.predictedNeeds
        .where((n) => n.confidence >= 0.5)
        .take(3)
        .toList();
    if (needs.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('你可能需要', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: needs.expand((need) => need.items.map((item) =>
                ActionChip(
                  label: Text(item),
                  onPressed: () {
                    // TODO: Navigate to task publish or search with this item pre-filled
                  },
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
