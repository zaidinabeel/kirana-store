import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_strings.dart';

/// Shows a standardized "Discard changes?" confirmation dialog.
Future<bool> showDiscardConfirmationDialog(
  BuildContext context, {
  String? title,
  String? content,
  String? confirmText,
  String? cancelText,
  AppLanguage? lang,
}) async {
  final isHi = lang == AppLanguage.hi;
  final effectiveTitle = title ?? (isHi ? 'बदलाव छोड़ें?' : 'Discard Unsaved Changes?');
  final effectiveContent = content ?? (isHi ? 'आपके द्वारा किए गए बदलाव सुरक्षित नहीं किए जाएंगे।' : 'You have unsaved changes that will be lost if you leave.');
  final effectiveConfirm = confirmText ?? (isHi ? 'हटाएं' : 'Discard');
  final effectiveCancel = cancelText ?? (isHi ? 'जारी रखें' : 'Keep Editing');
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        effectiveTitle,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          color: AppColors.alert,
          fontSize: 17,
        ),
      ),
      content: Text(
        effectiveContent,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            effectiveCancel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.alert,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            effectiveConfirm,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}
