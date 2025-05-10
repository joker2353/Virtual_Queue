import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/membership.dart';
import '../models/user_room.dart';
import '../models/form_field.dart';

class RoomProvider with ChangeNotifier {
  String _userId;
  List<UserRoom> _userRooms = [];
  bool _isLoading = false;
  String? _error;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _userRoomsSubscription;

  RoomProvider({required String userId}) : _userId = userId {
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
      
      _userRooms = [...created, ...joined];
      _setError(null);
    } catch (e) {
      _handleError(e);
    } finally {
      _setLoading(false);
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

      // 2. Create a pending membership in a transaction
      await _firestore.runTransaction((transaction) async {
        // Create membership document
        final membershipRef = _firestore.collection('memberships').doc(membershipId);
        
        final membership = Membership(
          id: membershipId,
          userId: _userId,
          roomId: roomId,
          role: 'member',
          status: 'pending',
          position: 0, // Will be assigned when approved
          formData: formData,
          timestamps: MembershipTimestamps(
            requested: DateTime.now(),
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
          status: 'pending',
          position: 0,
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
      });
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to join room: $e');
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
      
      final nextPosition = room.memberCount + 1;
      
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
      
      // First update the room document
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Then update all user_rooms records separately
      await _updateAllUserRoomsWithNewQueuePosition(roomId, room.currentPosition + 1);
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to advance queue: $e');
    }
  }

  Future<void> decreaseQueue(String roomId) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      
      final room = Room.fromMap(roomId, roomDoc.data()!);
      
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can decrease the queue');
      }
      
      if (room.currentPosition <= 0) {
        throw Exception('Queue position cannot be decreased below 0');
      }
      
      // First update the room document
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': FieldValue.increment(-1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Then update all user_rooms records separately
      await _updateAllUserRoomsWithNewQueuePosition(roomId, room.currentPosition - 1);
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
      
      // First update the room document
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': 1,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Then update all user_rooms records separately
      await _updateAllUserRoomsWithNewQueuePosition(roomId, 1);
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
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to leave room: $e');
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

  String _generateRoomCode() {
    // Generate a random 6-digit code
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
