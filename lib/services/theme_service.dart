import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart' as user_models;
import 'firebase_service.dart';
import 'profile_sync_service.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Initialize theme from user preferences
  Future<void> initializeTheme() async {
    try {
      // Check if user is logged in first
      final isLoggedIn = await FirebaseService.isLoggedIn();
      if (!isLoggedIn) {
        // Force light theme for unauthenticated users
        _isDarkMode = false;
        notifyListeners();
        return;
      }

      // First try SharedPreferences for instant loading
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getBool('isDarkMode');

      if (savedTheme != null) {
        _isDarkMode = savedTheme;
        notifyListeners();
      }

      // Then try to sync with Firebase in background
      try {
        final user = await FirebaseService.getUser();
        if (user != null) {
          final firebaseTheme = user.theme == user_models.Theme.dark;
          if (firebaseTheme != _isDarkMode) {
            _isDarkMode = firebaseTheme;
            await prefs.setBool('isDarkMode', _isDarkMode);
            notifyListeners();
          }
        }
        
        // Also sync profile preferences when initializing theme
        await ProfileSyncService.syncProfilePreferences();
      } catch (e) {
        // Firebase sync failed, but we already have local theme
        debugPrint('ThemeService: Firebase sync failed: $e');
      }
    } catch (e) {
      // Default to light theme if everything fails
      _isDarkMode = false;
      notifyListeners();
      debugPrint('ThemeService: Initialization failed: $e');
    }
  }

  // Toggle theme and save to user preferences
  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      notifyListeners();

      // Save to SharedPreferences first (faster)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);

      // Save theme preference to user profile
      final success = await FirebaseService.updateUserTheme(_isDarkMode ? 'dark' : 'light');
      if (!success) {
        throw Exception('Failed to update theme in Firebase');
      }
    } catch (e) {
      // Revert if save fails
      _isDarkMode = !_isDarkMode;
      notifyListeners();
      debugPrint('ThemeService: Failed to toggle theme: $e');
      rethrow;
    }
  }

  // Set theme directly
  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode == isDark) return;

    try {
      _isDarkMode = isDark;
      notifyListeners();

      // Save to SharedPreferences first (faster)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);

      // Save theme preference to user profile
      final success = await FirebaseService.updateUserTheme(isDark ? 'dark' : 'light');
      if (!success) {
        throw Exception('Failed to update theme in Firebase');
      }
    } catch (e) {
      // Revert if save fails
      _isDarkMode = !isDark;
      notifyListeners();
      debugPrint('ThemeService: Failed to set theme: $e');
      rethrow;
    }
  }

  // Get light theme
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Colors.teal,
      primaryContainer: Color(0xFFB2DFDB),
      secondary: Colors.teal,
      secondaryContainer: Color(0xFFE0F2F1),
      surface: Colors.white,
      error: Color(0xFFB00020),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF212121),
      onError: Colors.white,
      brightness: Brightness.light,
    ),
    primarySwatch: Colors.teal,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF212121), fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(color: Color(0xFF212121), fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: TextStyle(color: Color(0xFF212121), fontSize: 24, fontWeight: FontWeight.w400),
      bodyLarge: TextStyle(color: Color(0xFF212121), fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(color: Color(0xFF424242), fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: Color(0xFF757575), fontSize: 12, fontWeight: FontWeight.w400),
      titleLarge: TextStyle(color: Color(0xFF212121), fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(color: Color(0xFF212121), fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: Color(0xFF424242), fontSize: 14, fontWeight: FontWeight.w500),
    ),
    shadowColor: Colors.grey.withValues(alpha: 0.2),
    dividerColor: const Color(0xFFE0E0E0),
    iconTheme: const IconThemeData(color: Color(0xFF424242)),
    primaryIconTheme: const IconThemeData(color: Colors.teal),
  );

  // Get dark theme
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4DB6AC),
      primaryContainer: Color(0xFF00695C),
      secondary: Color(0xFF4DB6AC),
      secondaryContainer: Color(0xFF004D40),
      surface: Color(0xFF1E1E1E),
      error: Color(0xFFCF6679),
      onPrimary: Color(0xFF000000),
      onSecondary: Color(0xFF000000),
      onSurface: Color(0xFFE1E1E1),
      onError: Color(0xFF000000),
      brightness: Brightness.dark,
    ),
    primarySwatch: Colors.teal,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      foregroundColor: Color(0xFFE1E1E1),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFFE1E1E1),
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4DB6AC),
        foregroundColor: const Color(0xFF000000),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFFE1E1E1), fontSize: 32, fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(color: Color(0xFFE1E1E1), fontSize: 28, fontWeight: FontWeight.w400),
      headlineSmall: TextStyle(color: Color(0xFFE1E1E1), fontSize: 24, fontWeight: FontWeight.w400),
      bodyLarge: TextStyle(color: Color(0xFFE1E1E1), fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: Color(0xFF8A8A8A), fontSize: 12, fontWeight: FontWeight.w400),
      titleLarge: TextStyle(color: Color(0xFFE1E1E1), fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(color: Color(0xFFE1E1E1), fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14, fontWeight: FontWeight.w500),
    ),
    shadowColor: Colors.black.withValues(alpha: 0.4),
    dividerColor: const Color(0xFF2C2C2C),
    iconTheme: const IconThemeData(color: Color(0xFFB3B3B3)),
    primaryIconTheme: const IconThemeData(color: Color(0xFF4DB6AC)),
  );

  // Get current theme
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  // Reset theme to light (used when logging out)
  Future<void> resetToLightTheme() async {
    try {
      _isDarkMode = false;
      notifyListeners();

      // Clear saved theme preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isDarkMode');

      // Note: Profile images are preserved across logout for user convenience
      // They will be loaded again when the user logs back in
    } catch (e) {
      // If clearing fails, still set to light theme
      _isDarkMode = false;
      notifyListeners();
    }
  }

  /// Force sync theme across all devices
  Future<void> syncThemeAcrossDevices() async {
    try {
      // Get latest theme from Firebase
      final user = await FirebaseService.getUser();
      if (user != null) {
        final firebaseTheme = user.theme == user_models.Theme.dark;
        if (firebaseTheme != _isDarkMode) {
          _isDarkMode = firebaseTheme;
          
          // Update local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isDarkMode', _isDarkMode);
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('ThemeService: Theme sync failed: $e');
    }
  }
}
