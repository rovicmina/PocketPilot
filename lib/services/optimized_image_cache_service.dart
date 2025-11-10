import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optimized image caching service that reduces memory usage
class OptimizedImageCacheService {
  static final OptimizedImageCacheService _instance = OptimizedImageCacheService._internal();
  factory OptimizedImageCacheService() => _instance;
  OptimizedImageCacheService._internal();

  // In-memory cache with size limit
  static const int _maxCacheSize = 5 * 1024 * 1024; // 5MB limit
  final Map<String, CachedImage> _memoryCache = <String, CachedImage>{};
  int _currentCacheSize = 0;

  // Disk cache directory
  static const String _cacheDirName = 'optimized_image_cache';

  /// Get optimized image with caching
  Future<ImageProvider?> getCachedImage(String imagePath) async {
    try {
      // Check memory cache first
      final cached = _memoryCache[imagePath];
      if (cached != null && !cached.isExpired) {
        return MemoryImage(cached.bytes);
      }

      // Check disk cache
      final diskCached = await _getFromDiskCache(imagePath);
      if (diskCached != null) {
        // Add to memory cache
        _addToMemoryCache(imagePath, diskCached);
        return MemoryImage(diskCached);
      }

      // Load from file system
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        // Optimize image size if it's too large
        final optimizedBytes = await _optimizeImage(bytes, imagePath);
        
        // Cache the optimized image
        await _saveToDiskCache(imagePath, optimizedBytes);
        _addToMemoryCache(imagePath, optimizedBytes);
        
        return MemoryImage(optimizedBytes);
      }

      return null;
    } catch (e) {
      debugPrint('Error loading cached image: $e');
      return null;
    }
  }

  /// Optimize image by resizing if it's too large
  Future<Uint8List> _optimizeImage(Uint8List bytes, String imagePath) async {
    try {
      // If image is small enough, return as is
      if (bytes.lengthInBytes <= 500 * 1024) { // 500KB limit
        return bytes;
      }

      // Decode image to get dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      
      // Calculate new dimensions (max 512px on longest side)
      final originalWidth = image.width;
      final originalHeight = image.height;
      final maxDimension = 512;
      
      double newWidth, newHeight;
      if (originalWidth > originalHeight) {
        newWidth = maxDimension.toDouble();
        newHeight = (originalHeight * maxDimension / originalWidth).toDouble();
      } else {
        newHeight = maxDimension.toDouble();
        newWidth = (originalWidth * maxDimension / originalHeight).toDouble();
      }
      
      // Resize image
      final resized = await _resizeImage(image, newWidth.toInt(), newHeight.toInt());
      
      // Encode as PNG
      final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final optimizedBytes = byteData.buffer.asUint8List();
        image.dispose();
        resized.dispose();
        return optimizedBytes;
      }
      
      image.dispose();
      resized.dispose();
      return bytes; // Return original if optimization fails
    } catch (e) {
      debugPrint('Error optimizing image: $e');
      return bytes; // Return original if optimization fails
    }
  }

  /// Resize image to specified dimensions
  Future<ui.Image> _resizeImage(ui.Image image, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;
    
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(width, height);
    picture.dispose();
    
    return resizedImage;
  }

  /// Add image to memory cache
  void _addToMemoryCache(String key, Uint8List bytes) {
    // Remove oldest entries if cache is full
    while (_currentCacheSize + bytes.lengthInBytes > _maxCacheSize && _memoryCache.isNotEmpty) {
      final oldestKey = _memoryCache.keys.first;
      final oldestEntry = _memoryCache.remove(oldestKey);
      if (oldestEntry != null) {
        _currentCacheSize -= oldestEntry.bytes.lengthInBytes;
      }
    }
    
    // Add new entry
    _memoryCache[key] = CachedImage(bytes, DateTime.now().add(const Duration(hours: 1)));
    _currentCacheSize += bytes.lengthInBytes;
  }

  /// Get image from disk cache
  Future<Uint8List?> _getFromDiskCache(String key) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/${_getCacheFileName(key)}');
      
      if (await cacheFile.exists()) {
        // Check if cache is expired
        final lastModified = await cacheFile.lastModified();
        if (DateTime.now().difference(lastModified).inHours < 1) {
          return await cacheFile.readAsBytes();
        } else {
          // Delete expired cache
          await cacheFile.delete();
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error reading from disk cache: $e');
      return null;
    }
  }

  /// Save image to disk cache
  Future<void> _saveToDiskCache(String key, Uint8List bytes) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/${_getCacheFileName(key)}');
      await cacheFile.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Error saving to disk cache: $e');
    }
  }

  /// Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final cacheDir = Directory('${(await getTemporaryDirectory()).path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate cache file name from key
  String _getCacheFileName(String key) {
    return key.hashCode.toString();
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _memoryCache.clear();
    _currentCacheSize = 0;
  }

  /// Clear disk cache
  Future<void> clearDiskCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing disk cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    clearMemoryCache();
    await clearDiskCache();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final cacheDir = await _getCacheDirectory();
    int diskCacheSize = 0;
    
    if (await cacheDir.exists()) {
      final files = cacheDir.listSync();
      for (final file in files) {
        if (file is File) {
          diskCacheSize += await file.length();
        }
      }
    }
    
    return {
      'memoryCacheSize': _currentCacheSize,
      'memoryCacheEntries': _memoryCache.length,
      'diskCacheSize': diskCacheSize,
      'maxMemoryCacheSize': _maxCacheSize,
    };
  }
}

/// Cached image with expiration
class CachedImage {
  final Uint8List bytes;
  final DateTime expiryTime;

  CachedImage(this.bytes, this.expiryTime);

  bool get isExpired => DateTime.now().isAfter(expiryTime);
}