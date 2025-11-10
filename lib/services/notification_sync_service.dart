import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Service to synchronize notification states across devices
class NotificationSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  static String? get _currentUserId => _auth.currentUser?.uid;

  /// Sync notification read states to Firebase
  static Future<void> syncNotificationReadState(String notificationId, bool isRead) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final notificationRef = _db
          .collection('users')
          .doc(userId)
          .collection('notification_states')
          .doc(notificationId);

      await notificationRef.set({
        'notificationId': notificationId,
        'isRead': isRead,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationSyncService: Failed to sync read state: $e');
    }
  }

  /// Sync deleted notifications to Firebase
  static Future<void> syncDeletedNotification(String notificationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final notificationRef = _db
          .collection('users')
          .doc(userId)
          .collection('notification_states')
          .doc(notificationId);

      await notificationRef.set({
        'notificationId': notificationId,
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationSyncService: Failed to sync deleted notification: $e');
    }
  }

  /// Get notification states from Firebase
  static Future<Map<String, dynamic>> getNotificationStates() async {
    final userId = _currentUserId;
    if (userId == null) return {};

    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('notification_states')
          .get();

      final Map<String, dynamic> states = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final notificationId = data['notificationId'] as String;
        states[notificationId] = {
          'isRead': data['isRead'] ?? false,
          'isDeleted': data['isDeleted'] ?? false,
        };
      }

      return states;
    } catch (e) {
      debugPrint('NotificationSyncService: Failed to get notification states: $e');
      return {};
    }
  }

  /// Sync local notification states to Firebase on app startup
  static Future<void> syncLocalStatesToFirebase() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sync read states
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('notification_read_')) {
          final notificationId = key.replaceFirst('notification_read_', '');
          final isRead = prefs.getBool(key) ?? false;
          await syncNotificationReadState(notificationId, isRead);
        }
      }

      // Sync deleted notifications
      final deletedList = prefs.getStringList('deleted_notifications') ?? [];
      for (final notificationId in deletedList) {
        await syncDeletedNotification(notificationId);
      }
    } catch (e) {
      debugPrint('NotificationSyncService: Failed to sync local states: $e');
    }
  }

  /// Apply Firebase notification states to local storage
  static Future<void> applyFirebaseStatesToLocal() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final states = await getNotificationStates();

      // Apply read states
      for (final entry in states.entries) {
        final notificationId = entry.key;
        final state = entry.value as Map<String, dynamic>;
        
        if (state['isRead'] == true) {
          await prefs.setBool('notification_read_$notificationId', true);
        }
        
        if (state['isDeleted'] == true) {
          final deletedList = prefs.getStringList('deleted_notifications') ?? [];
          if (!deletedList.contains(notificationId)) {
            deletedList.add(notificationId);
            await prefs.setStringList('deleted_notifications', deletedList);
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationSyncService: Failed to apply Firebase states: $e');
    }
  }

  /// Clear all notification states (used when logging out)
  static Future<void> clearAllNotificationStates() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('notification_read_') || 
            key.startsWith('deleted_notifications')) {
          await prefs.remove(key);
        }
      }

      // Note: We don't delete Firebase data as it should persist for other devices
    } catch (e) {
      debugPrint('NotificationSyncService: Failed to clear local states: $e');
    }
  }

  /// Initialize notification sync service
  static Future<void> initialize() async {
    if (!await FirebaseService.isLoggedIn()) return;

    try {
      // Sync local states to Firebase
      await syncLocalStatesToFirebase();
      
      // Apply Firebase states to local storage
      await applyFirebaseStatesToLocal();
    } catch (e) {
      debugPrint('NotificationSyncService: Initialization failed: $e');
    }
  }
}