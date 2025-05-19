import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/membership.dart';
import '../models/user_room.dart';
import '../models/form_field.dart';
import '../providers/notification_provider.dart';

class RoomProvider with ChangeNotifier {
  String _userId;
  List<UserRoom> _userRooms = [];
  bool _isLoading = false;
  String? _error;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _userRoomsSubscription;
  final NotificationProvider? notificationProvider;

  RoomProvider({required String userId, this.notificationProvider}) : _userId = userId {
    if (userId.isNotEmpty) {
      _setupUserRoomsListener();
    }
  }

  // Getters
  List<UserRoom> get userRooms => _userRooms;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserRoom> get createdRooms => _userRooms.where((room) => room.isCreated).toList();
  List<UserRoom> get joinedRooms => _userRooms.where((room) => room.isJoined).toList();
  List<UserRoom> get pendingRooms => joinedRooms.where((room) => room.isPending).toList();
  List<UserRoom> get activeRooms => joinedRooms.where((room) => room.isActive).toList();
  
  // Check for notification eligible rooms
  List<UserRoom> get roomsEligibleForNotification => 
    activeRooms.where((room) => room.isCurrentlyServed).toList();

  // Update userId when user changes
  set userId(String newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      _cleanup();
      if (newUserId.isNotEmpty) {
        _setupUserRoomsListener();
      }
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _cleanup() {
    _userRoomsSubscription?.cancel();
    _userRooms = [];
  }

  // Listen to user's rooms
  void _setupUserRoomsListener() {
    _setLoading(true);
    
    try {
      _userRoomsSubscription = _firestore
          .collection('user_rooms')
          .doc(_userId)
          .snapshots()
          .listen(_handleUserRoomsSnapshot, onError: _handleError);
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleUserRoomsSnapshot(DocumentSnapshot snapshot) {
    try {
      if (!snapshot.exists) {
        _userRooms = [];
        _setLoading(false);
        notifyListeners();
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      
      List<UserRoom> created = [];
      if (data.containsKey('created')) {
        created = (data['created'] as List).map((item) => 
          UserRoom.fromMap(item as Map<String, dynamic>)
        ).toList();
      }
      
      List<UserRoom> joined = [];
      if (data.containsKey('joined')) {
        joined = (data['joined'] as List).map((item) => 
          UserRoom.fromMap(item as Map<String, dynamic>)
        ).toList();
      }
      
      final List<UserRoom> newUserRooms = [...created, ...joined];
      
      // Check for position changes
      _checkPositionChangesAndNotify(_userRooms, newUserRooms);
      
      _userRooms = newUserRooms;
      _setError(null);
    } catch (e) {
      _handleError(e);
    } finally {
      _setLoading(false);
    }
  }
  
  // Check for position changes and send notifications
  void _checkPositionChangesAndNotify(List<UserRoom> oldRooms, List<UserRoom> newRooms) {
    if (oldRooms.isEmpty || notificationProvider == null || !notificationProvider!.isInitialized) {
      return;
    }
    
    for (final newRoom in newRooms) {
      // Find the matching old room
      final oldRoom = oldRooms.firstWhere(
        (room) => room.roomId == newRoom.roomId,
        orElse: () => UserRoom(
          roomId: '', 
          name: '', 
          type: '', 
          status: '',
          position: -1,
          currentPosition: -1,
          memberCount: 0,
          joinedAt: DateTime.now(),
        ),
      );
      
      // If this is a valid room and the user's position is now being served
      if (oldRoom.roomId.isNotEmpty && 
          !oldRoom.isCurrentlyServed && 
          newRoom.isCurrentlyServed) {
        
        // Get the membership to retrieve phone number from form data
        _getMembershipAndSendNotification(newRoom);
      }
    }
  }
  
  // Get membership data and send notification using the phone number from form data
  Future<void> _getMembershipAndSendNotification(UserRoom room) async {
    try {
      final membershipId = '${room.roomId}_$_userId';
      final membershipDoc = await _firestore.collection('memberships').doc(membershipId).get();
      
      if (membershipDoc.exists) {
        final membershipData = membershipDoc.data() as Map<String, dynamic>;
        final formData = Map<String, dynamic>.from(membershipData['formData'] ?? {});
        
        // Get phone number from the contact field in form data
        final contactNumber = formData['contact'] as String?;
        
        if (contactNumber != null && contactNumber.isNotEmpty) {
          // Format phone number for WhatsApp if needed (add country code if missing)
          final formattedNumber = _formatPhoneNumber(contactNumber);
          
          // Send WhatsApp notification with the phone number from form data
          notificationProvider?.sendQueuePositionNotification(
            phoneNumber: formattedNumber,
            queueName: room.name,
          );
          
          // Update membership to record notification
          _updateMembershipNotificationTimestamp(room.roomId);
        }
      }
    } catch (e) {
      print('Error getting membership data for notification: $e');
    }
  }
  
  // New method to find and notify customers based on position and room state
  Future<void> notifyCustomerOnQueueAdvance(String roomId, int newPosition) async {
    try {
      // Find memberships at the current position
      final membershipsQuery = await _firestore
        .collection('memberships')
        .where('roomId', isEqualTo: roomId)
        .where('position', isEqualTo: newPosition) // Match the new current position
        .where('status', isEqualTo: 'active')
        .get();

      for (final membershipDoc in membershipsQuery.docs) {
        final membership = Membership.fromMap(membershipDoc.id, membershipDoc.data());
        final formData = membership.formData;
        
        // Get phone number from form data
        final contactNumber = formData['contact'] as String?;
        
        if (contactNumber != null && contactNumber.isNotEmpty) {
          // Get room name for notification
          final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
          final room = Room.fromMap(roomId, roomDoc.data()!);
          
          // Format phone number for WhatsApp if needed
          final formattedNumber = _formatPhoneNumber(contactNumber);
          
          // Send notification
          notificationProvider?.sendQueuePositionNotification(
            phoneNumber: formattedNumber,
            queueName: room.name,
          );
          
          // Update membership to record notification
          await _firestore.collection('memberships').doc(membership.id).update({
            'lastNotified': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error notifying customers: $e');
    }
  }
  
  // Helper method to format phone number (add country code if missing)
  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.startsWith('+')) {
      return phoneNumber; // Already has country code
    }
    
    // Otherwise, add default country code (modify for your region)
    return '+1$phoneNumber'; // Change +1 to your country code if different
  }
  
  // Update membership to record when the notification was sent
  Future<void> _updateMembershipNotificationTimestamp(String roomId) async {
    try {
      final membershipId = '${roomId}_$_userId';
      final membershipRef = _firestore.collection('memberships').doc(membershipId);
      
      await membershipRef.update({
        'lastNotified': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating notification timestamp: $e');
    }
  }

  void _handleError(dynamic error) {
    print('Error in RoomProvider: $error');
    _setError('Failed to load rooms: $error');
    _setLoading(false);
  }

  // Room management methods
  Future<String> createRoom({
    required String name,
    required int capacity,
    required String notice,
    required List<FormFieldModel> formFields,
  }) async {
    try {
      final code = _generateRoomCode();
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;

      final room = Room(
        id: roomId,
        name: name,
        code: code,
        qrCodeUrl: null,
        creatorId: _userId,
        capacity: capacity,
        currentPosition: 0,
        memberCount: 1, // Creator counts as first member
        status: 'active',
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        notice: notice,
        formFields: formFields,
        settings: RoomSettings(),
      );

      // Create room in a transaction
      await _firestore.runTransaction((transaction) async {
        // 1. Create the room
        transaction.set(roomRef, room.toMap());

        // 2. Create membership for creator
        final membershipId = '${roomId}_$_userId';
        final membershipRef = _firestore.collection('memberships').doc(membershipId);
        
        final membership = Membership(
          id: membershipId,
          userId: _userId,
          roomId: roomId,
          role: 'creator',
          status: 'active',
          position: 0, // Creator doesn't have a position
          formData: {},
          timestamps: MembershipTimestamps(
            requested: DateTime.now(),
            approved: DateTime.now(),
          ),
          metadata: {},
        );
        
        transaction.set(membershipRef, membership.toMap());

        // 3. Update user_rooms for faster access
        final userRoomRef = _firestore.collection('user_rooms').doc(_userId);
        
        final userRoom = UserRoom(
          roomId: roomId,
          name: name,
          type: 'created',
          status: 'active',
          position: 0,
          currentPosition: 0,
          memberCount: 1,
          joinedAt: DateTime.now(),
        );
        
        transaction.set(
          userRoomRef, 
          {
            'created': FieldValue.arrayUnion([userRoom.toMap()]),
          },
          SetOptions(merge: true),
        );
      });

      return roomId;
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to create room: $e');
    }
  }

  Future<void> joinRoom({
    required String roomCode,
    required Map<String, dynamic> formData,
    bool autoApprove = false,
  }) async {
    try {
      // 1. Find room by code
      final roomQuery = await _firestore
        .collection('rooms')
        .where('code', isEqualTo: roomCode)
        .limit(1)
        .get();

      if (roomQuery.docs.isEmpty) {
        throw Exception('Room not found with code: $roomCode');
      }

      final roomDoc = roomQuery.docs.first;
      final roomId = roomDoc.id;
      final roomData = roomDoc.data();
      final room = Room.fromMap(roomId, roomData);

      // Check if user already has a membership
      final membershipId = '${roomId}_$_userId';
      final existingMembership = await _firestore
          .collection('memberships')
          .doc(membershipId)
          .get();

      if (existingMembership.exists) {
        final membership = Membership.fromMap(
            membershipId, existingMembership.data()!);
            
        if (membership.status == 'active') {
          throw Exception('You are already a member of this room');
        } else if (membership.status == 'pending') {
          throw Exception('Your join request is already pending');
        }
      }

      // For auto-approval (added by receptionist), check if current user is room creator
      if (autoApprove && room.creatorId != _userId) {
        throw Exception('Only room creators can auto-approve new members');
      }

      final nextPosition = autoApprove ? room.memberCount : 0;
      final memberStatus = autoApprove ? 'active' : 'pending';

      // Create membership in a transaction
      await _firestore.runTransaction((transaction) async {
        // Create membership document
        final membershipRef = _firestore.collection('memberships').doc(membershipId);
        
        final membership = Membership(
          id: membershipId,
          userId: _userId,
          roomId: roomId,
          role: 'member',
          status: memberStatus,
          position: nextPosition,
          formData: formData,
          timestamps: MembershipTimestamps(
            requested: DateTime.now(),
            approved: autoApprove ? DateTime.now() : null,
          ),
          metadata: {},
        );
        
        transaction.set(membershipRef, membership.toMap());

        // Update user_rooms for faster access
        final userRoomRef = _firestore.collection('user_rooms').doc(_userId);
        
        final userRoom = UserRoom(
          roomId: roomId,
          name: room.name,
          type: 'joined',
          status: memberStatus,
          position: nextPosition,
          currentPosition: room.currentPosition,
          memberCount: room.memberCount,
          joinedAt: DateTime.now(),
        );
        
        transaction.set(
          userRoomRef, 
          {
            'joined': FieldValue.arrayUnion([userRoom.toMap()]),
          },
          SetOptions(merge: true),
        );
        
        // If auto-approving, also update the room's member count
        if (autoApprove) {
          transaction.update(roomDoc.reference, {
            'memberCount': FieldValue.increment(1),
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to join room: $e');
    }
  }

  // New method for creator to add customers with a custom ID
  Future<void> addCustomerByCreator({
    required String roomCode,
    required Map<String, dynamic> formData,
    required String customerId,
  }) async {
    try {
      // 1. Find room by code
      final roomQuery = await _firestore
        .collection('rooms')
        .where('code', isEqualTo: roomCode)
        .limit(1)
        .get();

      if (roomQuery.docs.isEmpty) {
        throw Exception('Room not found with code: $roomCode');
      }

      final roomDoc = roomQuery.docs.first;
      final roomId = roomDoc.id;
      final roomData = roomDoc.data();
      final room = Room.fromMap(roomId, roomData);

      // Check if current user is room creator
      if (room.creatorId != _userId) {
        throw Exception('Only room creators can add customers');
      }

      // Generate a membership ID using the custom ID instead of the creator's ID
      final membershipId = '${roomId}_$customerId';
      
      // Check if this membership ID already exists
      final existingMembership = await _firestore
          .collection('memberships')
          .doc(membershipId)
          .get();

      if (existingMembership.exists) {
        throw Exception('A customer with this ID already exists in the queue');
      }

      final nextPosition = room.memberCount;

      // Create membership in a transaction
      await _firestore.runTransaction((transaction) async {
        // Create membership document
        final membershipRef = _firestore.collection('memberships').doc(membershipId);
        
        final membership = Membership(
          id: membershipId,
          userId: customerId, // Use the custom ID as userId
          roomId: roomId,
          role: 'member',
          status: 'active', // Auto-approve
          position: nextPosition,
          formData: formData,
          timestamps: MembershipTimestamps(
            requested: DateTime.now(),
            approved: DateTime.now(),
          ),
          metadata: {'addedByCreator': true},
        );
        
        transaction.set(membershipRef, membership.toMap());

        // Update user_rooms for easier lookup
        final userRoomRef = _firestore.collection('user_rooms').doc(customerId);
        
        final userRoom = UserRoom(
          roomId: roomId,
          name: room.name,
          type: 'joined',
          status: 'active',
          position: nextPosition,
          currentPosition: room.currentPosition,
          memberCount: room.memberCount,
          joinedAt: DateTime.now(),
        );
        
        transaction.set(
          userRoomRef, 
          {
            'joined': FieldValue.arrayUnion([userRoom.toMap()]),
          },
          SetOptions(merge: true),
        );
        
        // Update the room's member count
        transaction.update(roomDoc.reference, {
          'memberCount': FieldValue.increment(1),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to add customer: $e');
    }
  }

  Future<void> acceptJoinRequest(String roomId, String userId) async {
    try {
      final membershipId = '${roomId}_$userId';
      
      // Get the room and membership docs OUTSIDE the transaction
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final membershipDoc = await _firestore.collection('memberships').doc(membershipId).get();
      
      if (!roomDoc.exists || !membershipDoc.exists) {
        throw Exception('Room or membership not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      final membership = Membership.fromMap(membershipId, membershipDoc.data()!);
      
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can accept join requests');
      }
      
      if (membership.status != 'pending') {
        throw Exception('This join request is no longer pending');
      }
      
      final nextPosition = room.memberCount;
      
      // Run in a transaction with read operations first, then writes
      await _firestore.runTransaction((transaction) async {
        // Get user_rooms document reference
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        
        // First do all READS
        final userRoomDoc = await transaction.get(userRoomRef);
        
        // Then do all WRITES
        // 1. Update membership status
        transaction.update(membershipDoc.reference, {
          'status': 'active',
          'position': nextPosition,
          'timestamps.approved': FieldValue.serverTimestamp(),
        });
        
        // 2. Update room member count
        transaction.update(roomDoc.reference, {
          'memberCount': FieldValue.increment(1),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        
        // 3. Update user_rooms for the joining user
        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;
          
          if (data.containsKey('joined')) {
            // Find the pending room entry and replace it
            final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);
            bool foundAndUpdated = false;
            
            for (int i = 0; i < joinedRooms.length; i++) {
              if (joinedRooms[i]['roomId'] == roomId) {
                // Update the existing entry with active status and position
                joinedRooms[i] = {
                  ...joinedRooms[i],
                  'status': 'active',
                  'position': nextPosition,
                  'currentPosition': room.currentPosition,
                  'memberCount': room.memberCount + 1 // Include the newly added member
                };
                foundAndUpdated = true;
                break;
              }
            }
            
            // If we didn't find the room to update (unlikely but possible),
            // add it as a new entry
            if (!foundAndUpdated) {
              final userRoom = UserRoom(
                roomId: roomId,
                name: room.name,
                type: 'joined',
                status: 'active',
                position: nextPosition,
                currentPosition: room.currentPosition,
                memberCount: room.memberCount + 1,
                joinedAt: DateTime.now(),
              ).toMap();
              
              joinedRooms.add(userRoom);
            }
            
            transaction.update(userRoomRef, {'joined': joinedRooms});
          } else {
            // No joined rooms yet, create a new array with this room
            final userRoom = UserRoom(
              roomId: roomId,
              name: room.name,
              type: 'joined',
              status: 'active',
              position: nextPosition,
              currentPosition: room.currentPosition,
              memberCount: room.memberCount + 1,
              joinedAt: DateTime.now(),
            ).toMap();
            
            transaction.update(userRoomRef, {'joined': [userRoom]});
          }
        } else {
          // User document doesn't exist yet, create it
          final userRoom = UserRoom(
            roomId: roomId,
            name: room.name,
            type: 'joined',
            status: 'active',
            position: nextPosition,
            currentPosition: room.currentPosition,
            memberCount: room.memberCount + 1,
            joinedAt: DateTime.now(),
          ).toMap();
          
          transaction.set(userRoomRef, {'joined': [userRoom]});
        }
      });
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to accept join request: $e');
    }
  }

  Future<void> rejectJoinRequest(String roomId, String userId) async {
    try {
      final membershipId = '${roomId}_$userId';
      
      // Get the room and membership docs OUTSIDE the transaction
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final membershipDoc = await _firestore.collection('memberships').doc(membershipId).get();
      
      if (!roomDoc.exists || !membershipDoc.exists) {
        throw Exception('Room or membership not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      final membership = Membership.fromMap(membershipId, membershipDoc.data()!);
      
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can reject join requests');
      }
      
      if (membership.status != 'pending') {
        throw Exception('This join request is no longer pending');
      }
      
      // Run in a transaction with read operations first, then writes
      await _firestore.runTransaction((transaction) async {
        // First do all READS
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        final userRoomDoc = await transaction.get(userRoomRef);
        
        // Then do all WRITES
        // 1. Update membership status
        transaction.update(membershipDoc.reference, {
          'status': 'rejected',
        });
        
        // 2. Update user_rooms for the joining user
        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;
          
          if (data.containsKey('joined')) {
            // Filter out the rejected room request
            final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);
            final updatedJoinedRooms = joinedRooms.where(
              (room) => room['roomId'] != roomId
            ).toList();
            
            transaction.update(userRoomRef, {'joined': updatedJoinedRooms});
          }
        }
      });
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to reject join request: $e');
    }
  }

  Future<void> advanceQueue(String roomId) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can advance the queue');
      }
      
      // Get the next position to notify anyone who will be served
      final nextPosition = room.currentPosition + 1;
      
      // First update the room document
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Then update all user_rooms records separately
      await _updateAllUserRoomsWithNewQueuePosition(roomId, nextPosition);
      
      // Also notify customers who were added directly by the creator
      await notifyCustomerOnQueueAdvance(roomId, nextPosition);
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to advance queue: $e');
    }
  }

  Future<void> decreaseQueue(String roomId) async {
    try {
      // Get the room document first
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      
      // Verify permissions
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can decrease the queue');
      }
      
      // Can't decrease below 0
      if (room.currentPosition <= 0) {
        throw Exception('Queue position cannot be decreased below 0');
      }
      
      // Calculate the new position
      final newPosition = room.currentPosition - 1;
      
      // Update the room document with the new position
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': newPosition,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update all user_rooms records with the new position
      await _updateAllUserRoomsWithNewQueuePosition(roomId, newPosition);
      
      // Find and notify the member who is now being served, if applicable
      if (newPosition > 0) {
        await notifyCustomerOnQueueAdvance(roomId, newPosition);
      }
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to decrease queue: $e');
    }
  }

  Future<void> resetQueue(String roomId) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can reset the queue');
      }
      
      // Reset the queue position to 0 (no one being served)
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': 0,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Then update all user_rooms records separately
      await _updateAllUserRoomsWithNewQueuePosition(roomId, 0);
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to reset queue: $e');
    }
  }

  // Helper method to update current position in all user_rooms
  Future<void> _updateAllUserRoomsWithNewQueuePosition(String roomId, int newPosition) async {
    try {
      // Instead of updating each user_room document individually in a loop 
      // (which could cause many small writes), we'll batch the operations

      final batch = _firestore.batch();
      final updatedUserIds = <String>[];
      
      // Get all memberships for this room
      final membershipsSnapshot = await _firestore
          .collection('memberships')
          .where('roomId', isEqualTo: roomId)
          .get();
      
      // First collect all the user IDs that need updating
      for (final membershipDoc in membershipsSnapshot.docs) {
        final membership = Membership.fromMap(membershipDoc.id, membershipDoc.data());
        updatedUserIds.add(membership.userId);
      }
      
      // Now get all user_rooms documents in a single batch
      for (final userId in updatedUserIds) {
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        final userRoomDoc = await userRoomRef.get();
        
        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;
          bool madeChanges = false;
          
          // Update the relevant section (created or joined)
          for (final section in ['created', 'joined']) {
            if (data.containsKey(section)) {
              final rooms = List<Map<String, dynamic>>.from(data[section]);
              
              for (int i = 0; i < rooms.length; i++) {
                if (rooms[i]['roomId'] == roomId) {
                  rooms[i] = {
                    ...rooms[i],
                    'currentPosition': newPosition,
                  };
                  madeChanges = true;
                  break;
                }
              }
              
              if (madeChanges) {
                // Update the specific section only
                batch.update(userRoomRef, {section: rooms});
                break; // Break out of the loop once we've found and updated the section
              }
            }
          }
        }
      }
      
      // Commit all updates in a single batch operation
      await batch.commit();
    } catch (e) {
      print('Error updating user_rooms: $e');
    }
  }

  Future<void> leaveRoom(String roomId) async {
    try {
      final membershipId = '${roomId}_$_userId';
      
      // Get the membership doc outside the transaction
      final membershipDoc = await _firestore.collection('memberships').doc(membershipId).get();
      
      if (!membershipDoc.exists) {
        throw Exception('Membership not found');
      }
      
      final membership = Membership.fromMap(membershipId, membershipDoc.data()!);
      
      if (membership.role == 'creator') {
        throw Exception('Room creators cannot leave their rooms');
      }
      
      // Get room to check current position
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      final leavingPosition = membership.position;
      
      // Run in a transaction with read operations first, then writes
      await _firestore.runTransaction((transaction) async {
        // First do all READS
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final userRoomRef = _firestore.collection('user_rooms').doc(_userId);
        
        final userRoomDoc = await transaction.get(userRoomRef);
        
        // Then do all WRITES
        // 1. Update membership status
        transaction.update(membershipDoc.reference, {
          'status': 'left',
          'timestamps.left': FieldValue.serverTimestamp(),
        });
        
        // 2. Update room member count
        transaction.update(roomRef, {
          'memberCount': FieldValue.increment(-1),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        
        // 3. Update user_rooms
        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;
          
          if (data.containsKey('joined')) {
            final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);
            
            // Filter out the left room
            final updatedJoinedRooms = joinedRooms.where(
              (room) => room['roomId'] != roomId
            ).toList();
            
            transaction.update(userRoomRef, {'joined': updatedJoinedRooms});
          }
        }
      });
      
      // If the leaving member had a position and hasn't been served yet,
      // adjust positions of members behind them
      if (leavingPosition > 0 && leavingPosition > room.currentPosition) {
        await _adjustPositionsAfterLeaving(roomId, leavingPosition);
      }
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to leave room: $e');
    }
  }
  
  // New method to adjust positions when a member leaves
  Future<void> _adjustPositionsAfterLeaving(String roomId, int leavingPosition) async {
    try {
      // Find all memberships with position greater than the leaving position
      final affectedMembershipsQuery = await _firestore
          .collection('memberships')
          .where('roomId', isEqualTo: roomId)
          .where('position', isGreaterThan: leavingPosition)
          .where('status', isEqualTo: 'active')
          .get();
          
      if (affectedMembershipsQuery.docs.isEmpty) {
        return; // No members to adjust
      }
      
      // Update positions in batches
      final batch = _firestore.batch();
      final affectedUserIds = <String>[];
      
      // First adjust membership positions
      for (final membershipDoc in affectedMembershipsQuery.docs) {
        final membership = Membership.fromMap(membershipDoc.id, membershipDoc.data());
        affectedUserIds.add(membership.userId);
        
        // Decrease position by 1
        batch.update(membershipDoc.reference, {
          'position': membership.position - 1,
        });
      }
      
      await batch.commit();
      
      // Now update user_rooms documents
      await _updateUserRoomsAfterPositionAdjustment(roomId, affectedUserIds);
      
    } catch (e) {
      print('Error adjusting positions: $e');
    }
  }
  
  // Helper method to update user_rooms after position adjustment
  Future<void> _updateUserRoomsAfterPositionAdjustment(String roomId, List<String> userIds) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final room = Room.fromMap(roomId, roomDoc.data()!);
      
      for (final userId in userIds) {
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        final userRoomDoc = await userRoomRef.get();
        
        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;
          
          if (data.containsKey('joined')) {
            final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);
            bool updated = false;
            
            for (int i = 0; i < joinedRooms.length; i++) {
              if (joinedRooms[i]['roomId'] == roomId) {
                // Decrease position by 1
                final int currentPosition = joinedRooms[i]['position'];
                joinedRooms[i] = {
                  ...joinedRooms[i],
                  'position': currentPosition - 1,
                  'currentPosition': room.currentPosition,
                  'memberCount': room.memberCount - 1 // Account for the leaving member
                };
                updated = true;
                break;
              }
            }
            
            if (updated) {
              await userRoomRef.update({'joined': joinedRooms});
            }
          }
        }
      }
    } catch (e) {
      print('Error updating user_rooms after position adjustment: $e');
    }
  }

  Future<void> updateNotice(String roomId, String notice) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can update the notice');
      }
      
      await _firestore.collection('rooms').doc(roomId).update({
        'notice': notice,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to update notice: $e');
    }
  }

  void refreshRooms() {
    _cleanup();
    _setupUserRoomsListener();
  }

  // Generate a room code
  String _generateRoomCode() {
    // Generate a random 6-digit code
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }
  
  // Verify if room code exists and return room details
  Future<Room> verifyRoomCode(String roomCode) async {
    try {
      final roomQuery = await _firestore
        .collection('rooms')
        .where('code', isEqualTo: roomCode)
        .limit(1)
        .get();

      if (roomQuery.docs.isEmpty) {
        throw Exception('Room not found with code: $roomCode');
      }

      final roomDoc = roomQuery.docs.first;
      final roomData = roomDoc.data();
      final room = Room.fromMap(roomDoc.id, roomData);
      
      // Check if user already has a membership
      final membershipId = '${roomDoc.id}_$_userId';
      final existingMembership = await _firestore
          .collection('memberships')
          .doc(membershipId)
          .get();

      if (existingMembership.exists) {
        final membership = Membership.fromMap(
            membershipId, existingMembership.data()!);
            
        if (membership.status == 'active') {
          throw Exception('You are already a member of this room');
        } else if (membership.status == 'pending') {
          throw Exception('Your join request is already pending');
        }
      }
      
      return room;
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to verify room code: $e');
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
