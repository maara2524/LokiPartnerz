import 'package:flutter/material.dart';

class BbmAdminTheme {
  // Brand purples
  static const Color purple700 = Color(0xFF5B21B6);
  static const Color purple600 = Color(0xFF7C3AED);
  static const Color purple500 = Color(0xFF8B5CF6);
  static const Color purple400 = Color(0xFFA78BFA);
  static const Color purple200 = Color(0xFFDDD6FE);
  static const Color purple100 = Color(0xFFEDE9FE);
  static const Color purple50  = Color(0xFFF5F3FF);

  // Accent
  static const Color accentPink   = Color(0xFFEC4899);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentTeal   = Color(0xFF14B8A6);
  static const Color accentAmber  = Color(0xFFF59E0B);

  // Status
  static const Color statusActive   = Color(0xFF10B981);
  static const Color statusInactive = Color(0xFFEF4444);
  static const Color statusPending  = Color(0xFFF59E0B);
  static const Color statusTrial    = Color(0xFF6366F1);

  // Backgrounds
  static const Color bgPrimary   = Color(0xFFF8F7FF);
  static const Color bgCard      = Colors.white;
  static const Color bgMuted     = Color(0xFFF1F0F9);

  // Text
  static const Color textPrimary   = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF9CA3AF);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [purple700, purple500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [purple600, accentIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: purple700.withValues(alpha: 0.07),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get sectionDecoration => BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: purple700.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static Color levelColor(int level) {
    switch (level) {
      case 1: return const Color(0xFF7C3AED);
      case 2: return const Color(0xFF059669);
      case 3: return const Color(0xFF2563EB);
      case 4: return const Color(0xFFF59E0B);
      default: return const Color(0xFF9CA3AF);
    }
  }

  static String levelLabel(int level) {
    switch (level) {
      case 1: return 'Admin';
      case 2: return 'Extended';
      case 3: return 'Basic';
      case 4: return 'Trial';
      default: return 'Inactive';
    }
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return statusActive;
      case 'inactive': return statusInactive;
      case 'pending': return statusPending;
      default: return textMuted;
    }
  }
}
