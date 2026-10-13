import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

void showProductQuantitySelector(
  BuildContext context,
  AppState appState,
  Product product,
  int currentQty,
) {
  final int maxLimit = appState.getMaxLimitForProduct(product);
  final String activeUnit = appState.getProductSelectedUnit(product);
  final prices = appState.getProductPriceForUnit(product, activeUnit);
  final double unitPrice = prices['price']!;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select Quantity for ${product.name}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Active Weight: $activeUnit  •  ₹${unitPrice.toStringAsFixed(0)}/pack (Max: $maxLimit)",
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: maxLimit,
                itemBuilder: (context, index) {
                  final int qty = index + 1;
                  final bool isSelected = qty == currentQty;
                  final double qtyPrice = unitPrice * qty;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$qty',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textDark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      "$qty pack${qty > 1 ? 's' : ''} ($activeUnit each)",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "₹${qtyPrice.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected ? AppColors.primary : AppColors.textDark,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                        ],
                      ],
                    ),
                    onTap: () {
                      appState.setProductQuantity(product, qty, selectedUnit: activeUnit);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                appState.removeFromCart(product, selectedUnit: activeUnit);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text(
                "Remove from Cart",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    },
  );
}
