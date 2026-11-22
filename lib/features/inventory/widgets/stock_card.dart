import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../utils/unit_translator.dart';

class StockCard extends StatelessWidget {
  final String productName;
  final String? productCode;
  final String warehouseName;
  final double quantity;
  final String unit;

  const StockCard({
    super.key,
    required this.productName,
    this.productCode,
    required this.warehouseName,
    required this.quantity,
    this.unit = 'قطعة',
  });

  @override
  Widget build(BuildContext context) {
    Color qtyColor;
    if (quantity <= 0) {
      qtyColor = AppColors.error;
    } else if (quantity < 10) {
      qtyColor = AppColors.warning;
    } else {
      qtyColor = AppColors.success;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: qtyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2_outlined, color: qtyColor),
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
                Text(
                  quantity.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: qtyColor,
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
          ],
        ),
      ),
    );
  }
}
