import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/master_sku.dart';

class MasterSKUProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'master_skus';

  // Cache for categories
  List<String> _categories = [];
  List<String> get categories => _categories;

  // Upload image and get URL
  Future<String?> _uploadImageInternal(File imageFile) async {
    try {
      // Validate file exists
      if (!await imageFile.exists()) {
        debugPrint(
          'Error: Image file does not exist at path: ${imageFile.path}',
        );
        return null;
      }

      // Check file size (max 5MB)
      final fileSize = await imageFile.length();
      debugPrint('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
      if (fileSize > 5 * 1024 * 1024) {
        debugPrint('Error: File size exceeds 5MB limit');
        return null;
      }

      // Generate a unique filename
      final ext = imageFile.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'gif'].contains(ext)) {
        debugPrint('Error: Invalid file extension: $ext');
        return null;
      }

      final fileName =
          'sku_images/${DateTime.now().millisecondsSinceEpoch}.$ext';
      debugPrint('Generated storage path: $fileName');

      final ref = _storage.ref().child(fileName);
      debugPrint('Created storage reference');

      // Upload with metadata and progress tracking
      final metadata = SettableMetadata(
        contentType: 'image/$ext',
        customMetadata: {'uploaded': DateTime.now().toIso8601String()},
      );
      debugPrint('Created metadata');

      debugPrint('Starting image upload to path: $fileName');
      final uploadTask = ref.putFile(imageFile, metadata);
      debugPrint('Created upload task');

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
        onError: (error) {
          debugPrint('Upload progress monitoring error: $error');
        },
      );

      debugPrint('Waiting for upload completion...');
      final snapshot = await uploadTask;
      debugPrint('Upload completed with state: ${snapshot.state}');

      if (snapshot.state == TaskState.success) {
        debugPrint('Upload successful, getting download URL...');
        final url = await ref.getDownloadURL();
        debugPrint('Image upload successful. URL: $url');
        return url;
      } else {
        debugPrint('Error: Upload failed with state: ${snapshot.state}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error uploading image: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String?> uploadImage(File? imageFile) async {
    if (imageFile == null) {
      debugPrint('Error: imageFile is null');
      return null;
    }
    return _uploadImageInternal(imageFile);
  }

  // Delete image from storage
  Future<void> deleteImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  // Create new SKU with image
  Future<MasterSKU> createSKU({
    required String name,
    required String description,
    double? price,
    required String category,
    File? imageFile,
  }) async {
    String? imageUrl;
    try {
      if (imageFile != null) {
        debugPrint('Attempting to upload image: ${imageFile.path}');
        imageUrl = await uploadImage(imageFile);
        if (imageUrl == null) {
          debugPrint(
            'Warning: Image upload failed, continuing with null imageUrl',
          );
        } else {
          debugPrint('Image uploaded successfully, URL: $imageUrl');
        }
      }

      final now = DateTime.now();
      final docRef = _firestore.collection(_collection).doc();

      final sku = MasterSKU(
        id: docRef.id,
        name: name,
        description: description,
        price: price,
        category: category,
        imageUrl: imageUrl,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(sku.toJson());
      await _updateCategories(category);
      notifyListeners();
      return sku;
    } catch (e, stackTrace) {
      debugPrint('Error creating SKU: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to create SKU: $e');
    }
  }

  // Update existing SKU with image
  Future<void> updateSKU(MasterSKU sku, {File? newImageFile}) async {
    String? imageUrl = sku.imageUrl;

    try {
      if (newImageFile != null) {
        debugPrint('Attempting to update image for SKU: ${sku.id}');
        // Delete old image if exists
        if (imageUrl != null) {
          debugPrint('Deleting old image: $imageUrl');
          await deleteImage(imageUrl);
        }
        // Upload new image
        imageUrl = await uploadImage(newImageFile);
        if (imageUrl == null) {
          debugPrint('Warning: New image upload failed');
        } else {
          debugPrint('New image uploaded successfully, URL: $imageUrl');
        }
      }

      final updatedSku = sku.copyWith(
        updatedAt: DateTime.now(),
        imageUrl: imageUrl,
      );

      await _firestore
          .collection(_collection)
          .doc(sku.id)
          .update(updatedSku.toJson());
      await _updateCategories(sku.category);
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error updating SKU: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to update SKU: $e');
    }
  }

  // Delete SKU and its image
  Future<void> deleteSKU(String skuId) async {
    // Get SKU data to access image URL
    final sku = await getSKU(skuId);
    if (sku?.imageUrl != null) {
      await deleteImage(sku!.imageUrl);
    }

    await _firestore.collection(_collection).doc(skuId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  // Get single SKU
  Future<MasterSKU?> getSKU(String skuId) async {
    final doc = await _firestore.collection(_collection).doc(skuId).get();
    if (!doc.exists) return null;
    return MasterSKU.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  // Stream of all active SKUs
  Stream<List<MasterSKU>> streamSKUs() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => MasterSKU.fromJson(
                      doc.data(),
                      id: doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Search SKUs
  Future<List<MasterSKU>> searchSKUs(String query, {String? category}) async {
    Query skuQuery = _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true);

    if (category != null && category.isNotEmpty) {
      skuQuery = skuQuery.where('category', isEqualTo: category);
    }

    final snapshot = await skuQuery.get();
    final skus =
        snapshot.docs
            .map(
              (doc) => MasterSKU.fromJson(
                doc.data() as Map<String, dynamic>,
                id: doc.id,
              ),
            )
            .where(
              (sku) =>
                  sku.name.toLowerCase().contains(query.toLowerCase()) ||
                  sku.description.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

    return skus;
  }

  // Update categories list
  Future<void> _updateCategories(String newCategory) async {
    if (!_categories.contains(newCategory)) {
      _categories.add(newCategory);
      notifyListeners();
    }
  }

  // Load all categories
  Future<void> loadCategories() async {
    final snapshot =
        await _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .get();

    final categories =
        snapshot.docs
            .map((doc) => doc.data()['category'] as String)
            .toSet()
            .toList();

    _categories = categories;
    notifyListeners();
  }
}
