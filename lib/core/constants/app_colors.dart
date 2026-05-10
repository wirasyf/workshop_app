import 'package:flutter/material.dart';

/// Palet warna aplikasi SpareArt
class AppColors {
  AppColors._();

  // ── Primary ──
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color onPrimary = Colors.white;

  // ── Secondary (Accent) ──
  static const Color secondary = Color(0xFFFF8F00);
  static const Color secondaryLight = Color(0xFFFFB300);
  static const Color secondaryDark = Color(0xFFE65100);
  static const Color onSecondary = Colors.white;

  // ── Surface ──
  static const Color surface = Color(0xFFF8F9FD);
  static const Color surfaceCard = Colors.white;
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceCardDark = Color(0xFF1E1E2C);

  // ── Background ──
  static const Color background = Color(0xFFF0F2F8);
  static const Color backgroundDark = Color(0xFF0A0A14);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textPrimaryDark = Color(0xFFF1F1F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // ── Status / Semantic ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Stock Badge ──
  static const Color stockNormal = success;
  static const Color stockLow = warning;
  static const Color stockCritical = error;
  static const Color stockEmpty = Color(0xFF6B7280);

  // ── Divider / Border ──
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF2D2D3F);
  static const Color divider = Color(0xFFF3F4F6);

  // ── Chart Colors ──
  static const List<Color> chartColors = [
    Color(0xFF1565C0),
    Color(0xFF42A5F5),
    Color(0xFFFF8F00),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];
}
