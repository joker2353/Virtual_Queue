import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_debt.dart';
import '../models/order.dart' as app_models;

class DebtProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, CustomerDebt> _debts = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, CustomerDebt> get debts => _debts;

  // Helper method to get phone number from email
  Future<String?> _getPhoneNumberFromEmail(String email) async {
    try {
      final userQuery =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.data()['contactNumber'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting phone number from email: $e');
      return null;
    }
  }

  // Helper method to normalize phone number
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  // Get customer debt for a specific room
  Future<CustomerDebt?> getCustomerDebt(
    String roomId,
    String customerContact,
  ) async {
    try {
      String phoneNumber = customerContact;
      String? email;

      // If the customerContact looks like an email, try to get the phone number
      if (customerContact.contains('@')) {
        email = customerContact;
        final phone = await _getPhoneNumberFromEmail(email);
        if (phone != null) {
          phoneNumber = phone;
        } else {
          // If no phone number found for email, throw error
          throw Exception(
            'No contact number found for email: $email. Please update user profile with contact number.',
          );
        }
      }

      // Normalize the phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final debtId = '${roomId}_$normalizedPhone';

      final docRef = _firestore.collection('customer_debts').doc(debtId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Try to find debt by email if it exists
        if (email != null) {
          final oldDebtId = '${roomId}_$email';
          final oldDebtDoc =
              await _firestore
                  .collection('customer_debts')
                  .doc(oldDebtId)
                  .get();
          if (oldDebtDoc.exists) {
            // Migrate the old debt record to use phone number
            await _migrateDebtRecord(oldDebtDoc, normalizedPhone);
            // Retry getting the debt with the new ID
            return await getCustomerDebt(roomId, normalizedPhone);
          }
        }
        return null;
      }

      // Get debt history
      final debtHistoryQuery =
          await docRef
              .collection('debt_history')
              .orderBy('timestamp', descending: true)
              .get();
      final debtHistory =
          debtHistoryQuery.docs
              .map((doc) => DebtHistory.fromMap(doc.data()))
              .toList();

      // Get payment history
      final paymentHistoryQuery =
          await docRef
              .collection('payment_history')
              .orderBy('timestamp', descending: true)
              .get();
      final paymentHistory =
          paymentHistoryQuery.docs
              .map((doc) => PaymentHistory.fromMap(doc.id, doc.data()))
              .toList();

      final debt = CustomerDebt.fromMap(
        doc.id,
        doc.data()!,
      ).copyWith(debtHistory: debtHistory, paymentHistory: paymentHistory);

      _debts[debtId] = debt;
      notifyListeners();
      return debt;
    } catch (e) {
      print('Error getting customer debt: $e');
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Helper method to migrate old debt record to use phone number
  Future<void> _migrateDebtRecord(
    DocumentSnapshot oldDebt,
    String phoneNumber,
  ) async {
    final batch = _firestore.batch();
    final oldId = oldDebt.id;
    final data = oldDebt.data() as Map<String, dynamic>;

    // Create new debt document with phone number
    final newId = '${data['roomId']}_$phoneNumber';
    final newRef = _firestore.collection('customer_debts').doc(newId);

    // Set the new document
    batch.set(newRef, {...data, 'customerContact': phoneNumber});

    // Copy debt history
    final debtHistory =
        await oldDebt.reference.collection('debt_history').get();
    for (var doc in debtHistory.docs) {
      final newHistoryRef = newRef.collection('debt_history').doc(doc.id);
      batch.set(newHistoryRef, doc.data());
    }

    // Copy payment history
    final paymentHistory =
        await oldDebt.reference.collection('payment_history').get();
    for (var doc in paymentHistory.docs) {
      final newPaymentRef = newRef.collection('payment_history').doc(doc.id);
      batch.set(newPaymentRef, doc.data());
    }

    // Delete the old document and its subcollections
    batch.delete(oldDebt.reference);

    // Commit the batch
    await batch.commit();
  }

  // Add new debt from order
  Future<void> addDebtFromOrder(
    app_models.Order order,
    double debtAmount,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      String phoneNumber = order.customerContact;
      String? email;

      // If the customerContact is an email, try to get the phone number
      if (order.customerContact.contains('@')) {
        email = order.customerContact;
        final phone = await _getPhoneNumberFromEmail(email);
        if (phone != null) {
          phoneNumber = phone;
        } else {
          // If no phone number found for email, throw error
          throw Exception(
            'No phone number found for email: $email. Please update user profile with phone number.',
          );
        }
      }

      // Normalize the phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final debtId = '${order.roomId}_$normalizedPhone';

      final debtRef = _firestore.collection('customer_debts').doc(debtId);
      final debtDoc = await debtRef.get();

      // Start a batch write
      final batch = _firestore.batch();

      if (debtDoc.exists) {
        // Update existing debt
        final currentDebt = (debtDoc.data()?['currentDebt'] as num).toDouble();
        batch.update(debtRef, {
          'currentDebt': currentDebt + debtAmount,
          'lastUpdated': FieldValue.serverTimestamp(),
          'customerEmail': email, // Update email if available
        });
      } else {
        // Create new debt record
        batch.set(debtRef, {
          'roomId': order.roomId,
          'customerContact': normalizedPhone,
          'customerEmail': email,
          'currentDebt': debtAmount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Add debt history entry
      final historyRef = debtRef.collection('debt_history').doc();
      batch.set(historyRef, {
        'orderId': order.id,
        'amount': debtAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Order debt: ${order.items.map((i) => "${i.name} x${i.quantity}").join(", ")}',
      });

      await batch.commit();

      // Refresh the debt data
      await getCustomerDebt(order.roomId, normalizedPhone);
    } catch (e) {
      print('Error adding debt from order: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Record a payment
  Future<void> recordPayment(
    String roomId,
    String customerContact,
    double amount,
    String paymentMethod, {
    String? reference,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      String phoneNumber = customerContact;

      // If the customerContact is an email, try to get the phone number
      if (customerContact.contains('@')) {
        final phone = await _getPhoneNumberFromEmail(customerContact);
        if (phone != null) {
          phoneNumber = phone;
        }
      }

      // Normalize the phone number
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final debtId = '${roomId}_$normalizedPhone';

      final debtRef = _firestore.collection('customer_debts').doc(debtId);
      final debtDoc = await debtRef.get();

      if (!debtDoc.exists) {
        // Try to find debt by email if it exists
        if (customerContact.contains('@')) {
          final oldDebtId = '${roomId}_$customerContact';
          final oldDebtDoc =
              await _firestore
                  .collection('customer_debts')
                  .doc(oldDebtId)
                  .get();
          if (oldDebtDoc.exists) {
            // Migrate the old debt record to use phone number
            await _migrateDebtRecord(oldDebtDoc, normalizedPhone);
            // Retry recording payment
            return await recordPayment(
              roomId,
              normalizedPhone,
              amount,
              paymentMethod,
              reference: reference,
            );
          }
        }
        throw Exception('No debt record found');
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Update current debt
      final currentDebt = (debtDoc.data()?['currentDebt'] as num).toDouble();
      final newDebt = currentDebt - amount;

      if (newDebt < 0) {
        throw Exception('Payment amount exceeds current debt');
      }

      batch.update(debtRef, {
        'currentDebt': newDebt,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Add payment history entry
      final paymentRef = debtRef.collection('payment_history').doc();
      batch.set(paymentRef, {
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
        'reference': reference,
      });

      await batch.commit();

      // Refresh the debt data
      await getCustomerDebt(roomId, normalizedPhone);
    } catch (e) {
      print('Error recording payment: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get all debts for a room
  Future<List<CustomerDebt>> getRoomDebts(String roomId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot =
          await _firestore
              .collection('customer_debts')
              .where('roomId', isEqualTo: roomId)
              .get();

      final debts = await Future.wait(
        querySnapshot.docs.map((doc) async {
          final debtHistoryQuery =
              await doc.reference
                  .collection('debt_history')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .get();

          final paymentHistoryQuery =
              await doc.reference
                  .collection('payment_history')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .get();

          final debt = CustomerDebt.fromMap(doc.id, doc.data()).copyWith(
            debtHistory:
                debtHistoryQuery.docs
                    .map((doc) => DebtHistory.fromMap(doc.data()))
                    .toList(),
            paymentHistory:
                paymentHistoryQuery.docs
                    .map((doc) => PaymentHistory.fromMap(doc.id, doc.data()))
                    .toList(),
          );

          _debts[doc.id] = debt;
          return debt;
        }),
      );

      notifyListeners();
      return debts;
    } catch (e) {
      print('Error getting room debts: $e');
      _error = e.toString();
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
