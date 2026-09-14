import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mi Notes থিম — B4 স্টাইল: ডার্ক নেভি ব্যাকগ্রাউন্ড + বেগুনি অ্যাকসেন্ট,
/// নোট কার্ডে রঙিন সাইড-অ্যাকসেন্ট বার (পুরো কার্ড রঙিন নয়)।
/// [seedColor] settings থেকে dynamically পরিবর্তনযোগ্য।
class AppTheme {
  static const Color defaultSeed = Color(0xFF7F77DD); // B4 বেগুনি অ্যাকসেন্ট

  /// B4 ডার্ক থিমের নেভি ব্যাকগ্রাউন্ড শেড
  static const Color _darkBg = Color(0xFF1A1A2E);
  static const Color _darkCard = Color(0xFF232338);
  static const Color _darkNav = Color(0xFF12121F);

  /// নোট/টাস্কের সাইড-অ্যাকসেন্ট বারের জন্য প্রিসেট রঙ (B4 প্যালেট)
  static const List<Color> noteColors = [
    Color(0xFF9AA0A6), // ধূসর (ডিফল্ট/নিরপেক্ষ)
    Color(0xFF7F77DD), // বেগুনি
    Color(0xFFD85A30), // কমলা-লাল
    Color(0xFF1D9E75), // সবুজ-টিল
    Color(0xFFD4537E), // গোলাপি
    Color(0xFFEF9F27), // অ্যাম্বার
    Color(0xFF378ADD), // নীল
    Color(0xFFF0997B), // পিচ
    Color(0xFF5DCAA5), // মিন্ট
    Color(0xFFED93B1), // হালকা গোলাপি
    Color(0xFF795548), // ব্রাউন
    Color(0xFFE8EAED), // হালকা ধূসর
  ];

  static ThemeData light({Color seedColor = defaultSeed}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.notoSansBengaliTextTheme(),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 1,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        selectedColor: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 12),
      ),
    );
  }

  static ThemeData dark({Color seedColor = defaultSeed}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: _darkBg,
      surfaceContainerHigh: _darkCard,
      surfaceContainerHighest: _darkCard,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.notoSansBengaliTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkNav,
        indicatorColor: colorScheme.primary.withOpacity(0.25),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        selectedColor: colorScheme.primary,
        backgroundColor: _darkCard,
        labelStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 12),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 12),
      ),
    );
  }
}
