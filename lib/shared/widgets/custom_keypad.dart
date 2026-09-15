import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback? onDone;
  final bool showDecimal;
  final List<int>? quickAddAmounts; // e.g. [10, 50, 100, 500]
  final ValueChanged<int>? onQuickAdd;

  const CustomKeypad({
    super.key,
    required this.onKeyPress,
    required this.onBackspace,
    required this.onClear,
    this.onDone,
    this.showDecimal = true,
    this.quickAddAmounts,
    this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional Quick Add pills (e.g. +₹10, +₹50, +₹100, +₹500)
          if (quickAddAmounts != null && onQuickAdd != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: quickAddAmounts!.map((amount) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size(0, 42),
                        ),
                        onPressed: () => onQuickAdd!(amount),
                        child: Text(
                          '+₹$amount',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Grid of Numbers 1 to 9
          Row(
            children: [
              _keyButton('1'),
              _keyButton('2'),
              _keyButton('3'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _keyButton('4'),
              _keyButton('5'),
              _keyButton('6'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _keyButton('7'),
              _keyButton('8'),
              _keyButton('9'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Decimal or Clear
              showDecimal
                  ? _keyButton('.', isSpecial: true)
                  : _actionButton(
                      label: 'C',
                      onTap: onClear,
                      color: AppColors.alertLight,
                      textColor: AppColors.alert,
                    ),
              _keyButton('0'),
              _actionButton(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
                color: AppColors.surface,
                textColor: AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyButton(String val, {bool isSpecial = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: InkWell(
          onTap: () => onKeyPress(val),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 54, // Large touch target
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                )
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              val,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 24,
                fontWeight: isSpecial ? FontWeight.w800 : FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: textColor, size: 22)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
