import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../utils/unit_translator.dart';

class TransactionCard extends StatelessWidget {
  final String productName;
  final String? productCode;
  final String warehouseName;
  final String transactionType;
  final double quantity;
  final String unit;
  final DateTime createdAt;

  const TransactionCard({
    super.key,
    required this.productName,
    this.productCode,
    required this.warehouseName,
    required this.transactionType,
    required this.quantity,
    this.unit = 'قطعة',
    required this.createdAt,
  });

  Color _typeColor() {
    switch (transactionType) {
      case 'in':
        return AppColors.success;
      case 'out':
        return AppColors.error;
      case 'adjustment':
        return AppColors.warning;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _typeLabel() {
    switch (transactionType) {
      case 'in':
        return 'in'.tr();
      case 'out':
        return 'out'.tr();
      case 'adjustment':
        return 'adjustment'.tr();
      default:
        return transactionType;
    }
  }

  IconData _typeIcon() {
    switch (transactionType) {
      case 'in':
        return Icons.arrow_downward;
      case 'out':
        return Icons.arrow_upward;
      case 'adjustment':
        return Icons.tune;
      default:
        return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(), color: _typeColor(), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (productCode != null)
                    Text(
                      productCode!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    warehouseName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${quantity.toStringAsFixed(2)} ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _typeColor(),
                      ),
                    ),
                    Text(
                      UnitTranslator.translate(unit), // ← الترجمة هنا
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _typeColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
