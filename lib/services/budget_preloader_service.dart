import 'dart:async';
import '../models/budget_prescription.dart';
import '../services/budget_prescription_service.dart';
import '../services/data_cache_service.dart';

/// Service for preloading budget data during app startup
class BudgetPreloaderService {
  static final BudgetPreloaderService _instance = BudgetPreloaderService._internal();
  factory BudgetPreloaderService() => _instance;
  BudgetPreloaderService._internal();

  static final DataCacheService _cacheService = DataCacheService();
  static BudgetPrescription? _preloadedPrescription;
  static DateTime? _preloadTimestamp;
  static bool _isPreloading = false;
  static bool _preloadCompleted = false;

  /// Get preloaded prescription if available and fresh
  static BudgetPrescription? getPreloadedPrescription() {
    if (_preloadedPrescription == null || _preloadTimestamp == null) {
      return null;
    }
    
    // Check if preloaded data is still fresh (within 1 hour)
    final age = DateTime.now().difference(_preloadTimestamp!);
    if (age.inHours > 1) {
      // Debug: Preloaded prescription expired, clearing cache
      _clearPreloadedData();
      return null;
    }
    
    return _preloadedPrescription;
  }

  /// Check if preloading is completed
  static bool isPreloadCompleted() {
    return _preloadCompleted;
  }

  /// Clear preloaded data
  static void _clearPreloadedData() {
    _preloadedPrescription = null;
    _preloadTimestamp = null;
    _preloadCompleted = false;
  }

  /// Preload budget data during app startup
  static Future<void> preloadBudgetData() async {
    if (_isPreloading) {
      // Debug: Budget preloading already in progress
      return;
    }

    _isPreloading = true;
    // Debug: Starting budget data preloading...

    try {
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1, 1);

      // Step 1: Check if we have any cached prescription first
      // Debug: Checking for existing prescription cache...
      BudgetPrescription? existingPrescription;
      
      try {
        existingPrescription = await BudgetPrescriptionService.getBudgetPrescription(now).timeout(
          const Duration(seconds: 3),
        );
        
        if (existingPrescription != null) {
          // Debug: Found existing prescription from ${existingPrescription.lastUpdated}
          final age = now.difference(existingPrescription.lastUpdated);
          
          // If prescription is less than 6 hours old, use it
          if (age.inHours < 6) {
            // Debug: Using fresh existing prescription
            _preloadedPrescription = existingPrescription;
            _preloadTimestamp = DateTime.now();
            _preloadCompleted = true;
            _isPreloading = false;
            return;
          }
        }
      } catch (e) {
        // Debug: Error checking existing prescription: $e
      }

      // Step 2: Check for August 2025 data specifically
      // Debug: Checking for August 2025 transaction data...
      final august2025 = DateTime(2025, 8, 1);
      final august2025Transactions = await _cacheService.getMonthlyTransactions(august2025).timeout(
        const Duration(seconds: 5),
      );
      
      // Debug: Found ${august2025Transactions.length} transactions in August 2025
      
      // Step 3: Check current previous month (should be August 2025 in September 2025)
      final previousMonthTransactions = await _cacheService.getMonthlyTransactions(previousMonth).timeout(
        const Duration(seconds: 5),
      );
      
      // Debug: Found ${previousMonthTransactions.length} transactions in previous month ($previousMonth)

      // If we have sufficient data, generate new prescription
      final hasAugustData = august2025Transactions.isNotEmpty;
      final hasPreviousData = previousMonthTransactions.isNotEmpty;
      
      if (hasAugustData || hasPreviousData) {
        // Debug: Sufficient data found, generating budget prescription...
        
        try {
          final prescription = await BudgetPrescriptionService.generateBudgetPrescription().timeout(
            const Duration(seconds: 10),
          );
          
          if (prescription != null) {
            // Debug: Successfully generated budget prescription
            _preloadedPrescription = prescription;
            _preloadTimestamp = DateTime.now();
            _preloadCompleted = true;
          } else {
            // Debug: Failed to generate budget prescription
            // Still mark as completed to avoid infinite retries
            _preloadCompleted = true;
          }
        } catch (e) {
          // Debug: Error generating budget prescription: $e
          // Use existing prescription if available
          if (existingPrescription != null) {
            // Debug: Falling back to existing prescription
            _preloadedPrescription = existingPrescription;
            _preloadTimestamp = DateTime.now();
          }
          _preloadCompleted = true;
        }
      } else {
        // Debug: No sufficient transaction data found for budget generation
        _preloadCompleted = true;
      }

    } catch (e) {
      // Debug: Critical error in budget preloading: $e
      _preloadCompleted = true;
    } finally {
      _isPreloading = false;
    }
  }

  /// Force refresh preloaded data
  static Future<void> refreshPreloadedData() async {
    _clearPreloadedData();
    await preloadBudgetData();
  }

  /// Invalidate preloaded data (call when new transactions are added)
  static void invalidatePreloadedData() {
    // Debug: Invalidating preloaded budget data
    _clearPreloadedData();
  }
}