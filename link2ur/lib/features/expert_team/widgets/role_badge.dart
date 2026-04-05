import 'package:flutter/material.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';

class ExpertRoleBadge extends StatelessWidget {
  final String role;
  final double fontSize;

  const ExpertRoleBadge({super.key, required this.role, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (role) {
      case 'owner':
        bgColor = Colors.blue;
        textColor = Colors.white;
        label = context.l10n.expertTeamOwner;
      case 'admin':
        bgColor = Colors.orange;
        textColor = Colors.white;
        label = context.l10n.expertTeamAdmin;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.black87;
        label = context.l10n.expertTeamMember;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
    );
  }
}
