import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsets padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    Color textColor;

    switch (status) {
      case 'Pending':
        color = Colors.amber.withValues(alpha: 0.12);
        textColor = Colors.amber.shade700;
        break;
      case 'Under Review':
        color = Colors.blue.withValues(alpha: 0.12);
        textColor = Colors.blue.shade700;
        break;
      case 'Scheduled':
        color = Colors.purple.withValues(alpha: 0.12);
        textColor = Colors.purple.shade700;
        break;
      case 'Escalated':
        color = Colors.red.withValues(alpha: 0.12);
        textColor = Colors.red.shade700;
        break;
      case 'Escalated to Ministrong':
        color = Colors.orange.withValues(alpha: 0.12);
        textColor = Colors.orange.shade700;
        break;
      case 'Escalated to Principal':
        color = Colors.teal.withValues(alpha: 0.12);
        textColor = Colors.teal.shade700;
        break;
      case 'Resolved':
        color = Colors.green.withValues(alpha: 0.12);
        textColor = Colors.green.shade700;
        break;
      case 'Re-Appealed':
        color = Colors.red.withValues(alpha: 0.12);
        textColor = Colors.red.shade700;
        break;
      default:
        color = Colors.grey.withValues(alpha: 0.12);
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
