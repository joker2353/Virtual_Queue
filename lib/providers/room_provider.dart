import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/room.dart';
import '../models/membership.dart';
import '../models/user_room.dart';
import '../models/form_field.dart';
import 'fcm_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QueueCompletionException implements Exception {
  final String message;
  const QueueCompletionException(this.message);

  @override
  String toString() => message;
}

class RoomProvider with ChangeNotifier {
  String _userId;
  List<UserRoom> _userRooms = [];
  bool _isLoading = false;
  String? _error;
  FCMProvider? _fcmProvider;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _userRoomsSubscription;
  StreamSubscription? _authSubscription;

  RoomProvider({required String userId}) : _userId = userId {
    _setupAuthListener();
    if (userId.isNotEmpty) {
      _setupUserRoomsListener();
    }
  }

  // Getters
  List<UserRoom> get userRooms {
    print('DEBUG: All userRooms count: ${_userRooms.length}');
    print(
      'DEBUG: userRooms categories: ${_userRooms.map((r) => r.category).toList()}',
    );
    return _userRooms;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserRoom> get createdRooms {
    final rooms = _userRooms.where((room) => room.isCreated).toList();
    print('DEBUG: createdRooms count: ${rooms.length}');
    return rooms;
  }

  List<UserRoom> get joinedRooms {
    final rooms =
        _userRooms
            .where(
              (room) =>
                  room.isJoined &&
                  room.status == 'active' &&
                  !pendingRooms.any((pending) => pending.roomId == room.roomId),
            )
            .toList();
    print('DEBUG: joinedRooms count: ${rooms.length}');
    print(
      'DEBUG: joinedRooms categories: ${rooms.map((r) => r.category).toList()}',
    );
    return rooms;
  }

  List<UserRoom> get pendingRooms {
    final rooms =
        _userRooms
            .where((room) => room.isJoined && room.status == 'pending')
            .toList();
    print('DEBUG: pendingRooms count: ${rooms.length}');
    return rooms;
  }

  List<UserRoom> get shopRooms {
    final rooms =
        _userRooms
            .where(
              (room) =>
                  room.isJoined &&
                  room.status == 'active' &&
                  (room.category == 'shop' || room.category == 'medical'),
            )
            .toList();
    print('DEBUG: shopRooms count: ${rooms.length}');
    print(
      'DEBUG: shopRooms details: ${rooms.map((r) => '${r.name}(${r.category})').toList()}',
    );
    return rooms;
  }

  List<UserRoom> get queueRooms {
    final rooms =
        _userRooms
            .where(
              (room) =>
                  room.isJoined &&
                  room.status == 'active' &&
                  room.category == 'queue',
            )
            .toList();
    print('DEBUG: queueRooms count: ${rooms.length}');
    print(
      'DEBUG: queueRooms details: ${rooms.map((r) => '${r.name}(${r.category})').toList()}',
    );
    return rooms;
  }

  List<UserRoom> get activeRooms {
    final rooms =
        _userRooms
            .where((room) => room.isJoined && room.status == 'active')
            .toList();
    print('DEBUG: activeRooms count: ${rooms.length}');
    print(
      'DEBUG: activeRooms categories: ${rooms.map((r) => r.category).toList()}',
    );
    return rooms;
  }

  void _setupAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      print('Auth state changed: ${user?.uid}');
      if (user != null && user.uid != _userId) {
        userId = user.uid;
      }
    });
  }

  // Update userId when user changes
  set userId(String newUserId) {
    if (_userId != newUserId) {
      print('Updating user ID from $_userId to $newUserId');
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
    _authSubscription?.cancel();
    _userRooms = [];
  }

  // Check if user is authenticated
  bool _isAuthenticated() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      _setError('User not authenticated. Please sign in again.');
      return false;
    }
    if (_userId != currentUser.uid) {
      _userId = currentUser.uid;
    }
    return true;
  }

  // Listen to user's rooms
  Future<void> _setupUserRoomsListener() async {
    _setLoading(true);

    try {
      // Create a Completer to handle the initial data fetch
      final completer = Completer<void>();

      _userRoomsSubscription = _firestore
          .collection('user_rooms')
          .doc(_userId)
          .snapshots()
          .listen(
            (snapshot) {
              _handleUserRoomsSnapshot(snapshot);
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
            onError: (e) {
              _handleError(e);
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            },
          );

      // Wait for the first data fetch
      await completer.future;
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleUserRoomsSnapshot(DocumentSnapshot snapshot) {
    try {
      if (!snapshot.exists) {
        print('DEBUG: No user_rooms document exists');
        _userRooms = [];
        _setLoading(false);
        notifyListeners();
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      print('DEBUG: Raw user_rooms data: $data');

      List<UserRoom> created = [];
      if (data.containsKey('created')) {
        created =
            (data['created'] as List).map((item) {
              final map = item as Map<String, dynamic>;
              print('DEBUG: Processing created room: $map');
              if (!map.containsKey('category')) {
                map['category'] = 'queue';
              }
              return UserRoom.fromMap(map);
            }).toList();
      }
      print('DEBUG: Created rooms count: ${created.length}');

      List<UserRoom> joined = [];
      if (data.containsKey('joined')) {
        joined =
            (data['joined'] as List)
                .map((item) {
                  final map = item as Map<String, dynamic>;
                  print('DEBUG: Processing joined room: $map');
                  if (!map.containsKey('category')) {
                    map['category'] = 'queue';
                  }
                  return UserRoom.fromMap(map);
                })
                .where((room) => room.roomId.isNotEmpty)
                .toList();
      }
      print('DEBUG: Joined rooms count: ${joined.length}');

      final List<UserRoom> newUserRooms = [...created, ...joined];

      // Check for notifications
      if (_fcmProvider != null &&
          _fcmProvider!.isInitialized &&
          _userRooms.isNotEmpty) {
        for (final newRoom in newUserRooms) {
          // Find matching old room
          final oldRoom = _userRooms.firstWhere(
            (room) => room.roomId == newRoom.roomId,
            orElse:
                () => UserRoom(
                  roomId: '',
                  name: '',
                  type: '',
                  status: '',
                  category: 'queue',
                  position: -1,
                  currentPosition: -1,
                  memberCount: 0,
                  joinedAt: DateTime.now(),
                ),
          );

          // If room is valid and current position advanced
          if (oldRoom.roomId.isNotEmpty &&
              newRoom.currentPosition > oldRoom.currentPosition) {
            // Check if it's this user's turn now
            if (newRoom.position == newRoom.currentPosition &&
                newRoom.position > 0 &&
                newRoom.isJoined) {
              // It's this user's turn - send notification
              _fcmProvider!.sendYourTurnNotification(
                userId: _userId,
                roomId: newRoom.roomId,
                roomName: newRoom.name,
                position: newRoom.position,
              );
            }
          }
        }
      }

      _userRooms = newUserRooms;
      _setError(null);
    } catch (e) {
      _handleError(e);
    } finally {
      _setLoading(false);
    }
  }

  void _handleError(dynamic error) {
    print('RoomProvider error: $error');
    _setError(error.toString());
    _setLoading(false);
  }

  // Room management methods
  Future<String> createRoom({
    required String name,
    required int capacity,
    required String notice,
    required List<FormFieldModel> formFields,
    required String category,
  }) async {
    try {
      print('Debug - Attempting to create room. Current user ID: $_userId');

      if (_userId.isEmpty) {
        print('Debug - User ID is empty, waiting briefly for auth...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (_userId.isEmpty) {
          print('Debug - User ID is still empty after waiting');
          throw Exception('Please sign in again to create a room');
        }
      }

      print('Debug - Creating room with creator ID: $_userId');
      final code = _generateRoomCode();
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;

      final List<Map<String, dynamic>> serializedFormFields =
          formFields
              .map(
                (field) => {
                  'id': field.id,
                  'name': field.name,
                  'type': field.type,
                  'required': field.required,
                },
              )
              .toList();

      final Map<String, dynamic> roomData = {
        'id': roomId,
        'name': name,
        'code': code,
        'qrCodeUrl': '',
        'creatorId': _userId,
        'capacity': capacity,
        'currentPosition': 0,
        'memberCount': 0, // Start with 0 members (creator not counted)
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'notice': notice,
        'formFields': serializedFormFields,
        'category': category,
        'settings': {
          'autoAdvanceQueue': false,
          'allowRejoin': true,
          'notifyNextInLine': true,
        },
      };

      if (category == 'shop') {
        roomData['shopSettings'] = {
          'acceptOrders': true,
          'allowCashPayment': true,
          'notifyOnNewOrder': true,
        };
      } else if (category == 'medical') {
        roomData['shopSettings'] = {
          'acceptPrescriptions': true,
          'allowCashPayment': true,
          'notifyOnNewOrder': true,
        };
      }

      print('Debug - Room data to be saved: $roomData');

      // Create room document first
      await roomRef.set(roomData);
      print('Debug - Room document created');

      // Create membership document for creator (without position)
      final membershipId = '${roomId}_$_userId';
      final membershipRef = _firestore
          .collection('memberships')
          .doc(membershipId);

      final membershipData = {
        'id': membershipId,
        'userId': _userId,
        'roomId': roomId,
        'role': 'creator',
        'status': 'active',
        'position': -1, // Creator has no position in queue
        'formData': {},
        'timestamps': {
          'requested': FieldValue.serverTimestamp(),
          'approved': FieldValue.serverTimestamp(),
        },
        'metadata': {},
      };

      await membershipRef.set(membershipData);
      print('Debug - Membership document created');

      // Update user_rooms document
      final userRoomRef = _firestore.collection('user_rooms').doc(_userId);

      final userRoomData = {
        'roomId': roomId,
        'name': name,
        'type': 'created',
        'status': 'active',
        'position': -1, // Creator has no position
        'currentPosition': 0,
        'memberCount': 0,
        'joinedAt': DateTime.now().toIso8601String(),
      };

      await userRoomRef.set({
        'created': FieldValue.arrayUnion([userRoomData]),
      }, SetOptions(merge: true));

      print('Debug - Room created successfully with ID: $roomId');
      return roomId;
    } catch (e) {
      print('Debug - Error creating room: $e');
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
      // Get current user's display name from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      final userName = currentUser?.displayName ?? 'Unknown';

      // Add user's name to form data if not already present
      if (!formData.containsKey('name') ||
          formData['name']?.toString().isEmpty == true) {
        formData = {...formData, 'name': userName};
      }

      // 1. Find room by code
      final roomQuery =
          await _firestore
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
      print('DEBUG: joinRoom - Room category: ${room.category}');

      // Check if user already has a membership
      final membershipId = '${roomId}_$_userId';
      final existingMembership =
          await _firestore.collection('memberships').doc(membershipId).get();

      if (existingMembership.exists) {
        final membership = Membership.fromMap(
          membershipId,
          existingMembership.data()!,
        );
        print(
          'DEBUG: joinRoom - Existing membership status: ${membership.status}',
        );

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

      // Position starts from 1 for first member
      final nextPosition = autoApprove ? room.memberCount + 1 : 0;
      final memberStatus = autoApprove ? 'active' : 'pending';
      print('DEBUG: joinRoom - Creating membership with status: $memberStatus');

      // Create membership in a transaction
      await _firestore.runTransaction((transaction) async {
        // Create membership document
        final membershipRef = _firestore
            .collection('memberships')
            .doc(membershipId);

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
          category: room.category,
          position: nextPosition,
          currentPosition: room.currentPosition,
          memberCount: room.memberCount,
          joinedAt: DateTime.now(),
        );
        print(
          'DEBUG: joinRoom - Created UserRoom with category: ${userRoom.category}',
        );

        transaction.set(userRoomRef, {
          'joined': FieldValue.arrayUnion([userRoom.toMap()]),
        }, SetOptions(merge: true));

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
    if (!_isAuthenticated()) {
      throw Exception('Please sign in to add customers');
    }

    try {
      print('Debug - Starting customer registration with code: $roomCode');
      print('Debug - Current user ID: $_userId');

      // Try to get customer's name from their Firebase account
      String customerName = 'Unknown';
      try {
        final customerDoc =
            await _firestore.collection('users').doc(customerId).get();
        if (customerDoc.exists) {
          customerName = customerDoc.data()?['displayName'] ?? 'Unknown';
        }
      } catch (e) {
        print('Error fetching customer name: $e');
      }

      // Add customer's name to form data if not already present
      if (!formData.containsKey('name') ||
          formData['name']?.toString().isEmpty == true) {
        formData = {...formData, 'name': customerName};
      }

      // 1. Find room by code
      final roomQuery =
          await _firestore
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

      // Generate a membership ID using the custom ID
      final membershipId = '${roomId}_$customerId';

      // Check if this membership ID already exists
      final existingMembership =
          await _firestore.collection('memberships').doc(membershipId).get();

      if (existingMembership.exists) {
        throw Exception('A customer with this ID already exists in the queue');
      }

      // Get the highest current position from active members
      final activeMembers =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('role', isEqualTo: 'member')
              .get();

      // Calculate next position by finding the highest position manually
      int highestPosition = 0;
      for (var doc in activeMembers.docs) {
        final membership = Membership.fromMap(doc.id, doc.data());
        if (membership.position > highestPosition) {
          highestPosition = membership.position;
        }
      }

      // Calculate next position (highest current position + 1)
      final nextPosition = activeMembers.docs.isEmpty ? 1 : highestPosition + 1;

      print('Debug - Assigning position $nextPosition to new member');

      // Create membership in a transaction
      await _firestore.runTransaction((transaction) async {
        // Get fresh copies of the documents we'll modify
        final freshRoomDoc = await transaction.get(roomDoc.reference);
        if (!freshRoomDoc.exists) {
          throw Exception('Room no longer exists');
        }

        // Verify creator is still authenticated
        if (!_isAuthenticated()) {
          throw Exception('Lost authentication during transaction');
        }

        // Create membership document
        final membershipRef = _firestore
            .collection('memberships')
            .doc(membershipId);
        final freshMembershipDoc = await transaction.get(membershipRef);
        if (freshMembershipDoc.exists) {
          throw Exception('Membership was created by another process');
        }

        // Get user_rooms reference
        final userRoomRef = _firestore.collection('user_rooms').doc(customerId);
        final freshUserRoomDoc = await transaction.get(userRoomRef);

        // Create the membership
        final membership = Membership(
          id: membershipId,
          userId: customerId,
          roomId: roomId,
          role: 'member',
          status: 'active',
          position: nextPosition,
          formData: formData,
          timestamps: MembershipTimestamps(
            requested: DateTime.now(),
            approved: DateTime.now(),
          ),
          metadata: {'addedByCreator': true},
        );

        // Create the user room entry
        final userRoom = UserRoom(
          roomId: roomId,
          name: room.name,
          type: 'joined',
          status: 'active',
          category: room.category,
          position: nextPosition,
          currentPosition: room.currentPosition,
          memberCount: room.memberCount + 1,
          joinedAt: DateTime.now(),
        );

        // Perform all writes
        transaction.set(membershipRef, membership.toMap());

        if (freshUserRoomDoc.exists) {
          final currentData = freshUserRoomDoc.data() as Map<String, dynamic>;
          final List<Map<String, dynamic>> joined =
              currentData.containsKey('joined')
                  ? List<Map<String, dynamic>>.from(currentData['joined'])
                  : [];
          joined.add(userRoom.toMap());
          transaction.update(userRoomRef, {'joined': joined});
        } else {
          transaction.set(userRoomRef, {
            'joined': [userRoom.toMap()],
          });
        }

        transaction.update(roomDoc.reference, {
          'memberCount': FieldValue.increment(1),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });

        print('Debug - Transaction prepared successfully');
      });

      print('Debug - Successfully added customer with position: $nextPosition');
    } catch (e, stackTrace) {
      print('Error adding customer: $e');
      print('Stack trace: $stackTrace');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      _handleError(e);
      throw Exception('Failed to add customer: ${e.toString()}');
    }
  }

  Future<void> acceptJoinRequest(String roomId, String userId) async {
    try {
      final membershipId = '${roomId}_$userId';
      print('Debug - Current user ID (_userId): $_userId');

      // Get the room and membership docs OUTSIDE the transaction
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final membershipDoc =
          await _firestore.collection('memberships').doc(membershipId).get();

      if (!roomDoc.exists || !membershipDoc.exists) {
        throw Exception('Room or membership not found');
      }

      final room = Room.fromMap(roomId, roomDoc.data()!);
      print('Debug - Room creator ID: ${room.creatorId}');
      print('Debug - Room data: ${roomDoc.data()}');

      final membership = Membership.fromMap(
        membershipId,
        membershipDoc.data()!,
      );

      if (room.creatorId != _userId) {
        print(
          'Debug - ID mismatch: Creator ID (${room.creatorId}) != Current user ID ($_userId)',
        );
        throw Exception('Only the room creator can accept join requests');
      }

      if (membership.status != 'pending') {
        throw Exception('This join request is no longer pending');
      }

      // Get the highest current position from active members
      final activeMembers =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('role', isEqualTo: 'member')
              .get();

      // Calculate next position by finding the highest position manually
      int highestPosition = 0;
      for (var doc in activeMembers.docs) {
        final membership = Membership.fromMap(doc.id, doc.data());
        if (membership.position > highestPosition) {
          highestPosition = membership.position;
        }
      }

      // Calculate next position (highest current position + 1)
      final nextPosition = activeMembers.docs.isEmpty ? 1 : highestPosition + 1;

      print('Debug - Assigning position $nextPosition to new member');

      // Run in a transaction
      await _firestore.runTransaction((transaction) async {
        // First do all READS
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        final userRoomDoc = await transaction.get(userRoomRef);

        // Get customer contact from membership form data
        final customerContact =
            membership.formData['contact'] ??
            membership.formData['phone'] ??
            membership.formData['phoneNumber'];
        if (customerContact == null || customerContact.isEmpty) {
          throw Exception(
            'Customer contact information not found in form data',
          );
        }

        // Get customer name from membership form data
        final customerName = membership.formData['name'] ?? 'Unknown';

        // Create or update customer record
        final customerRef = _firestore
            .collection('customers')
            .doc(customerContact);
        transaction.set(customerRef, {
          'roomId': roomId,
          'name': customerName,
          'pendingAmount': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Then do all WRITES
        // 1. Update membership status and position
        transaction.update(membershipDoc.reference, {
          'status': 'active',
          'position': nextPosition,
          'timestamps.approved': FieldValue.serverTimestamp(),
        });

        // 2. Update room's member count
        transaction.update(roomDoc.reference, {
          'memberCount': FieldValue.increment(1),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Update user_rooms for the joining user
        final userRoom =
            UserRoom(
              roomId: roomId,
              name: room.name,
              type: 'joined',
              status: 'active',
              category: room.category,
              position: nextPosition,
              currentPosition: room.currentPosition,
              memberCount: room.memberCount + 1,
              joinedAt: DateTime.now(),
            ).toMap();

        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;
          final List<Map<String, dynamic>> joinedRooms =
              data.containsKey('joined')
                  ? List<Map<String, dynamic>>.from(data['joined'])
                  : [];

          // Remove any existing entries for this room (pending or otherwise)
          joinedRooms.removeWhere((room) => room['roomId'] == roomId);

          // Add the new active room entry
          joinedRooms.add(userRoom);

          transaction.update(userRoomRef, {'joined': joinedRooms});
        } else {
          transaction.set(userRoomRef, {
            'joined': [userRoom],
          });
        }
      });

      print(
        'Debug - Successfully accepted join request and assigned position $nextPosition',
      );
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
      final membershipDoc =
          await _firestore.collection('memberships').doc(membershipId).get();

      if (!roomDoc.exists || !membershipDoc.exists) {
        throw Exception('Room or membership not found');
      }

      final room = Room.fromMap(roomId, roomDoc.data()!);
      final membership = Membership.fromMap(
        membershipId,
        membershipDoc.data()!,
      );

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
        transaction.update(membershipDoc.reference, {'status': 'rejected'});

        // 2. Update user_rooms for the joining user
        if (userRoomDoc.exists) {
          final data = userRoomDoc.data() as Map<String, dynamic>;

          if (data.containsKey('joined')) {
            // Filter out the rejected room request
            final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);
            final updatedJoinedRooms =
                joinedRooms.where((room) => room['roomId'] != roomId).toList();

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

      // Get current active members
      final membersQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('role', isEqualTo: 'member')
              .get();

      // Create a map of active positions
      final activePositions =
          membersQuery.docs
              .map((doc) => Membership.fromMap(doc.id, doc.data()).position)
              .toList()
            ..sort();

      if (activePositions.isEmpty) {
        // No active members, reset to 0
        await _firestore.collection('rooms').doc(roomId).update({
          'currentPosition': 0,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        await _updateAllUserRoomsWithNewQueuePosition(roomId, 0);
        return;
      }

      // Find and mark current member as served if there is one
      if (room.currentPosition > 0) {
        final currentMemberQuery =
            await _firestore
                .collection('memberships')
                .where('roomId', isEqualTo: roomId)
                .where('position', isEqualTo: room.currentPosition)
                .where('status', isEqualTo: 'active')
                .limit(1)
                .get();

        if (currentMemberQuery.docs.isNotEmpty) {
          final currentMemberDoc = currentMemberQuery.docs.first;
          final currentMember = Membership.fromMap(
            currentMemberDoc.id,
            currentMemberDoc.data(),
          );

          // Update the member's status to served and set served timestamp
          await _firestore
              .collection('memberships')
              .doc(currentMemberDoc.id)
              .update({
                'status': 'served',
                'timestamps.served': FieldValue.serverTimestamp(),
              });
        }
      }

      // Find next valid position
      int nextPosition = room.currentPosition;
      bool foundValid = false;

      // Keep incrementing until we find the next valid position or exceed the highest position
      while (!foundValid && nextPosition < activePositions.last) {
        nextPosition++;
        if (activePositions.contains(nextPosition)) {
          foundValid = true;
        }
      }

      // If we're already at or past the last position, or no valid position found
      if (!foundValid || room.currentPosition >= activePositions.last) {
        // Reset the queue position to 0
        await _firestore.collection('rooms').doc(roomId).update({
          'currentPosition': 0,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        await _updateAllUserRoomsWithNewQueuePosition(roomId, 0);
        throw const QueueCompletionException('All members have been served');
      }

      // Update the room document with the next position
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': nextPosition,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update all user_rooms records with the new position
      await _updateAllUserRoomsWithNewQueuePosition(roomId, nextPosition);

      // Send notifications to users at the current position if not 0
      if (nextPosition > 0) {
        await _notifyUsersAtPosition(roomId, room.name, nextPosition);
      }
    } catch (e) {
      if (e is QueueCompletionException) {
        // Re-throw completion message to show in UI
        rethrow;
      }
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

      // Get current active members
      final membersQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('role', isEqualTo: 'member')
              .get();

      // Create a map of active positions
      final activePositions =
          membersQuery.docs
              .map((doc) => Membership.fromMap(doc.id, doc.data()).position)
              .toList()
            ..sort();

      if (activePositions.isEmpty || room.currentPosition <= 1) {
        // No active members or already at start, reset to 0
        await _firestore.collection('rooms').doc(roomId).update({
          'currentPosition': 0,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        await _updateAllUserRoomsWithNewQueuePosition(roomId, 0);
        return;
      }

      // Find previous valid position
      int previousPosition = room.currentPosition;
      bool foundValid = false;

      // Keep decreasing until we find the previous valid position or reach 0
      while (!foundValid && previousPosition > 1) {
        previousPosition--;
        if (activePositions.contains(previousPosition)) {
          foundValid = true;
        }
      }

      // If no valid position found, reset to 0
      if (!foundValid) {
        previousPosition = 0;
      }

      // Update the room document
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': previousPosition,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update all user_rooms records with the new position
      await _updateAllUserRoomsWithNewQueuePosition(roomId, previousPosition);

      // Notify users at the new position if not 0
      if (previousPosition > 0) {
        await _notifyUsersAtPosition(roomId, room.name, previousPosition);
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

      // Reset the queue position to 0 and clear removed positions
      await _firestore.collection('rooms').doc(roomId).update({
        'currentPosition': 0,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'removedPositions': [], // Clear the removed positions on reset
      });

      // Update all user_rooms records
      await _updateAllUserRoomsWithNewQueuePosition(roomId, 0);
    } catch (e) {
      _handleError(e);
      throw Exception('Failed to reset queue: $e');
    }
  }

  // Helper method to update current position in all user_rooms
  Future<void> _updateAllUserRoomsWithNewQueuePosition(
    String roomId,
    int newPosition,
  ) async {
    try {
      // Instead of updating each user_room document individually in a loop
      // (which could cause many small writes), we'll batch the operations

      final batch = _firestore.batch();
      final updatedUserIds = <String>[];

      // Get all memberships for this room
      final membershipsSnapshot =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .get();

      // First collect all the user IDs that need updating
      for (final membershipDoc in membershipsSnapshot.docs) {
        final membership = Membership.fromMap(
          membershipDoc.id,
          membershipDoc.data(),
        );
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
                  rooms[i] = {...rooms[i], 'currentPosition': newPosition};
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
      print('🔄 Starting leave room process...');
      final batch = _firestore.batch();

      // 1. Get and validate membership
      final membershipId = '${roomId}_$_userId';
      final membershipRef = _firestore
          .collection('memberships')
          .doc(membershipId);
      final membershipDoc = await membershipRef.get();

      if (!membershipDoc.exists) {
        throw Exception('Membership not found');
      }
      final membership = Membership.fromMap(
        membershipId,
        membershipDoc.data()!,
      );

      if (membership.role == 'creator') {
        throw Exception('Room creators cannot leave their rooms');
      }

      // 2. Get and validate room
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final roomDoc = await roomRef.get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      final room = Room.fromMap(roomId, roomDoc.data()!);

      print('📊 Getting affected members...');
      // 3. Get all active members
      final allMembersQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .get();

      // Filter and sort affected members locally
      final affectedMembers =
          allMembersQuery.docs
              .map((doc) => Membership.fromMap(doc.id, doc.data()))
              .where(
                (m) => m.role == 'member' && m.position > membership.position,
              )
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));

      print('📝 Found ${affectedMembers.length} members to update');

      // Get current removed positions array or initialize if not exists
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final removedPositions = List<int>.from(
        roomData['removedPositions'] ?? [],
      );
      removedPositions.add(membership.position);
      removedPositions.sort();

      // 4. Update leaving member's status
      batch.update(membershipRef, {
        'status': 'left',
        'timestamps.left': FieldValue.serverTimestamp(),
      });

      // 5. Update room document
      final newCurrentPosition =
          room.currentPosition == membership.position
              ? 0
              : room.currentPosition;
      batch.update(roomRef, {
        'memberCount': FieldValue.increment(-1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'currentPosition': newCurrentPosition,
        'removedPositions': removedPositions,
      });

      // 6. Update positions for affected members
      for (var affectedMember in affectedMembers) {
        batch.update(
          _firestore.collection('memberships').doc(affectedMember.id),
          {'position': affectedMember.position - 1},
        );
      }

      // 7. Update user_rooms documents
      final affectedUserIds = [
        _userId,
        ...affectedMembers.map((m) => m.userId),
      ];

      for (final userId in affectedUserIds) {
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        final userRoomDoc = await userRoomRef.get();

        if (!userRoomDoc.exists) continue;

        final data = userRoomDoc.data() as Map<String, dynamic>;
        if (!data.containsKey('joined')) continue;

        final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);

        if (userId == _userId) {
          // Remove the room from leaving member's joined rooms
          final updatedRooms =
              joinedRooms.where((r) => r['roomId'] != roomId).toList();
          batch.update(userRoomRef, {'joined': updatedRooms});
        } else {
          // Update position for affected members
          bool updated = false;
          for (int i = 0; i < joinedRooms.length; i++) {
            if (joinedRooms[i]['roomId'] == roomId) {
              joinedRooms[i] = {
                ...joinedRooms[i],
                'position': joinedRooms[i]['position'] - 1,
                'currentPosition': newCurrentPosition,
              };
              updated = true;
              break;
            }
          }
          if (updated) {
            batch.update(userRoomRef, {'joined': joinedRooms});
          }
        }
      }

      // 8. Commit all changes
      print('📝 Committing batch updates...');
      await batch.commit();
      print('✅ Successfully left room and adjusted all positions');
    } catch (e, stackTrace) {
      print('❌ Error leaving room: $e');
      print('Stack trace: $stackTrace');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      _handleError(e);
      throw Exception('Failed to leave room: ${e.toString()}');
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

  // New method for admin to remove a member from the queue
  Future<void> removeMember(String roomId, String memberUserId) async {
    try {
      print('🔄 Starting member removal process...');
      final batch = _firestore.batch();

      // 1. Get and validate membership
      final membershipRef = _firestore
          .collection('memberships')
          .doc('${roomId}_$memberUserId');
      final membershipDoc = await membershipRef.get();

      if (!membershipDoc.exists) {
        throw Exception('Membership not found');
      }
      final membership = Membership.fromMap(
        membershipDoc.id,
        membershipDoc.data()!,
      );

      // 2. Get and validate room
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final roomDoc = await roomRef.get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }
      final room = Room.fromMap(roomId, roomDoc.data()!);

      // Validate permissions
      if (room.creatorId != _userId) {
        throw Exception('Only the room creator can remove members');
      }
      if (membership.role == 'creator') {
        throw Exception('Cannot remove the room creator');
      }

      print('📊 Getting affected members...');
      // 3. Get all active members and filter locally
      final allMembersQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .get();

      // Filter and sort affected members locally
      final affectedMembers =
          allMembersQuery.docs
              .map((doc) => Membership.fromMap(doc.id, doc.data()))
              .where(
                (m) => m.role == 'member' && m.position > membership.position,
              )
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));

      print('📝 Found ${affectedMembers.length} members to update');

      // Get current removed positions array or initialize if not exists
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final removedPositions = List<int>.from(
        roomData['removedPositions'] ?? [],
      );
      removedPositions.add(membership.position);
      removedPositions.sort(); // Keep sorted for easier lookup

      // 4. Update removed member's status
      batch.update(membershipRef, {
        'status': 'removed',
        'timestamps.left': FieldValue.serverTimestamp(),
        'metadata.removedBy': _userId,
        'metadata.removalReason': 'Admin removal',
      });

      // 5. Update room document with removed positions
      final newCurrentPosition =
          room.currentPosition == membership.position
              ? 0
              : room.currentPosition;
      batch.update(roomRef, {
        'memberCount': FieldValue.increment(-1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'currentPosition': newCurrentPosition,
        'removedPositions': removedPositions,
      });

      // 6. Update positions for affected members
      for (var affectedMember in affectedMembers) {
        batch.update(
          _firestore.collection('memberships').doc(affectedMember.id),
          {'position': affectedMember.position - 1},
        );
      }

      // 7. Update user_rooms documents
      final affectedUserIds = [
        memberUserId,
        ...affectedMembers.map((m) => m.userId),
      ];

      for (final userId in affectedUserIds) {
        final userRoomRef = _firestore.collection('user_rooms').doc(userId);
        final userRoomDoc = await userRoomRef.get();

        if (!userRoomDoc.exists) continue;

        final data = userRoomDoc.data() as Map<String, dynamic>;
        if (!data.containsKey('joined')) continue;

        final joinedRooms = List<Map<String, dynamic>>.from(data['joined']);

        if (userId == memberUserId) {
          // Remove the room from removed member's joined rooms
          final updatedRooms =
              joinedRooms.where((r) => r['roomId'] != roomId).toList();
          batch.update(userRoomRef, {'joined': updatedRooms});
        } else {
          // Update position for affected members
          bool updated = false;
          for (int i = 0; i < joinedRooms.length; i++) {
            if (joinedRooms[i]['roomId'] == roomId) {
              joinedRooms[i] = {
                ...joinedRooms[i],
                'position': joinedRooms[i]['position'] - 1,
                'currentPosition': newCurrentPosition,
              };
              updated = true;
              break;
            }
          }
          if (updated) {
            batch.update(userRoomRef, {'joined': joinedRooms});
          }
        }
      }

      // 8. Commit all changes
      print('📝 Committing batch updates...');
      await batch.commit();
      print('✅ Successfully removed member and adjusted all positions');
    } catch (e, stackTrace) {
      print('❌ Error removing member: $e');
      print('Stack trace: $stackTrace');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      _handleError(e);
      throw Exception('Failed to remove member: ${e.toString()}');
    }
  }

  Future<void> refreshRooms() async {
    _cleanup();
    await _setupUserRoomsListener();
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
      final roomQuery =
          await _firestore
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
      final existingMembership =
          await _firestore.collection('memberships').doc(membershipId).get();

      if (existingMembership.exists) {
        final membership = Membership.fromMap(
          membershipId,
          existingMembership.data()!,
        );

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

  // Set FCM provider reference
  void setFCMProvider(FCMProvider fcmProvider) {
    _fcmProvider = fcmProvider;
  }

  // Send notifications to users at specified position
  Future<void> _notifyUsersAtPosition(
    String roomId,
    String roomName,
    int position,
  ) async {
    if (_fcmProvider == null || !_fcmProvider!.isInitialized) {
      print('FCM provider not available, skipping notifications');
      return;
    }

    try {
      // Find all memberships at the current position
      final membershipsQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('position', isEqualTo: position)
              .where('status', isEqualTo: 'active')
              .get();

      // Get the room document to check the creator
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final room = Room.fromMap(roomId, roomDoc.data()!);

      for (final membershipDoc in membershipsQuery.docs) {
        final membership = Membership.fromMap(
          membershipDoc.id,
          membershipDoc.data(),
        );

        // Skip if this is the creator (position 0)
        if (membership.userId == room.creatorId) continue;

        // Send notification that it's their turn
        await _fcmProvider!.sendYourTurnNotification(
          userId: membership.userId,
          roomId: roomId,
          roomName: roomName,
          position: position,
        );

        // Record notification time
        await _firestore.collection('memberships').doc(membership.id).update({
          'lastNotified': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error sending notifications: $e');
    }
  }

  // Find member by room code and phone number
  Future<Map<String, dynamic>?> findMemberByPhoneAndCode({
    required String roomCode,
    required String phoneNumber,
  }) async {
    try {
      print(
        '🔍 Searching for member with room code: $roomCode, phone: $phoneNumber',
      );

      // First find the room by code
      final roomQuery =
          await _firestore
              .collection('rooms')
              .where('code', isEqualTo: roomCode.toUpperCase())
              .limit(1)
              .get();

      if (roomQuery.docs.isEmpty) {
        print('❌ Room not found with code: $roomCode');
        return null; // Room not found
      }

      final roomDoc = roomQuery.docs.first;
      final roomId = roomDoc.id;
      print('✅ Found room: $roomId');

      // Search in memberships collection (primary storage)
      final membershipsQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', whereIn: ['pending', 'active'])
              .get();

      print('📋 Found ${membershipsQuery.docs.length} memberships to check');

      for (final membershipDoc in membershipsQuery.docs) {
        final membershipData = membershipDoc.data();
        final formData =
            membershipData['formData'] as Map<String, dynamic>? ?? {};

        print('🔍 Checking membership: ${membershipDoc.id}');
        print('📝 Form data keys: ${formData.keys.toList()}');

        // Check if phone number matches in form data
        String? memberPhone;

        // Try different possible keys for phone number
        final phoneKeys = [
          'phone',
          'phoneNumber',
          'contact',
          'mobile',
          'contactNumber',
        ];
        for (final key in phoneKeys) {
          if (formData.containsKey(key)) {
            memberPhone = formData[key]?.toString();
            print('📞 Found phone field "$key": $memberPhone');
            break;
          }
        }

        if (memberPhone == null) {
          print('⚠️ No phone field found in form data');
          continue;
        }

        // Clean phone numbers for comparison (remove spaces, dashes, etc.)
        String cleanInputPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        String cleanMemberPhone = memberPhone.replaceAll(RegExp(r'[^\d+]'), '');

        print('🧹 Cleaned input phone: $cleanInputPhone');
        print('🧹 Cleaned member phone: $cleanMemberPhone');

        if (cleanMemberPhone.isNotEmpty &&
            cleanInputPhone == cleanMemberPhone) {
          print('✅ Phone number match found!');
          return {
            'roomId': roomId,
            'memberId': membershipDoc.id,
            'memberData': membershipData,
          };
        }
      }

      // If not found in memberships, try the subcollection as fallback
      print('🔄 Trying subcollection as fallback...');
      final subMembersQuery =
          await _firestore
              .collection('rooms')
              .doc(roomId)
              .collection('members')
              .get();

      print('📋 Found ${subMembersQuery.docs.length} members in subcollection');

      for (final memberDoc in subMembersQuery.docs) {
        final memberData = memberDoc.data();
        final formData = memberData['formData'] as Map<String, dynamic>? ?? {};

        print('🔍 Checking subcollection member: ${memberDoc.id}');

        // Check if phone number matches in form data
        String? memberPhone;

        final phoneKeys = [
          'phone',
          'phoneNumber',
          'contact',
          'mobile',
          'contactNumber',
        ];
        for (final key in phoneKeys) {
          if (formData.containsKey(key)) {
            memberPhone = formData[key]?.toString();
            break;
          }
        }

        if (memberPhone == null) continue;

        // Clean phone numbers for comparison
        String cleanInputPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        String cleanMemberPhone = memberPhone.replaceAll(RegExp(r'[^\d+]'), '');

        if (cleanMemberPhone.isNotEmpty &&
            cleanInputPhone == cleanMemberPhone) {
          print('✅ Phone number match found in subcollection!');
          return {
            'roomId': roomId,
            'memberId': memberDoc.id,
            'memberData': memberData,
          };
        }
      }

      print('❌ No member found with phone number: $phoneNumber');
      return null; // Member not found
    } catch (e) {
      print('❌ Error finding member by phone and code: $e');
      return null;
    }
  }

  // More efficient method to get the highest position in a room
  Future<int> _getHighestPosition(String roomId) async {
    try {
      // Query for active members only to get correct highest position
      final membershipsQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('role', isEqualTo: 'member')
              .orderBy('position', descending: true)
              .limit(1)
              .get();

      print('Debug - Getting highest position for room: $roomId');

      if (membershipsQuery.docs.isEmpty) {
        print('Debug - No active members found, returning 0');
        return 0; // No members, next position will be 1
      }

      final highestMembership = Membership.fromMap(
        membershipsQuery.docs.first.id,
        membershipsQuery.docs.first.data(),
      );

      print('Debug - Found highest position: ${highestMembership.position}');
      return highestMembership.position;
    } catch (e) {
      print('Error getting highest position: $e');
      // Try alternative query if index not available
      try {
        print('Debug - Trying alternative query for highest position');
        // Get all active memberships and find highest position manually
        final allMembershipsQuery =
            await _firestore
                .collection('memberships')
                .where('roomId', isEqualTo: roomId)
                .get();

        int highestPosition = 0;
        for (var doc in allMembershipsQuery.docs) {
          final membership = Membership.fromMap(doc.id, doc.data());
          if (membership.status == 'active' &&
              membership.role == 'member' &&
              membership.position > highestPosition) {
            highestPosition = membership.position;
          }
        }
        print('Debug - Found highest position (alternative): $highestPosition');
        return highestPosition;
      } catch (e2) {
        print('Error in alternative highest position query: $e2');
        return 0; // Fallback to 0 if all attempts fail
      }
    }
  }

  // Helper method to get next valid position in queue
  Future<int?> _getNextValidPosition(String roomId, int currentPosition) async {
    try {
      final nextMemberQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('position', isGreaterThan: currentPosition)
              .orderBy('position')
              .limit(1)
              .get();

      if (nextMemberQuery.docs.isEmpty) {
        return null;
      }

      return Membership.fromMap(
        nextMemberQuery.docs.first.id,
        nextMemberQuery.docs.first.data(),
      ).position;
    } catch (e) {
      print('Error getting next valid position: $e');
      return null;
    }
  }

  // Helper method to get previous valid position in queue
  Future<int?> _getPreviousValidPosition(
    String roomId,
    int currentPosition,
  ) async {
    try {
      final prevMemberQuery =
          await _firestore
              .collection('memberships')
              .where('roomId', isEqualTo: roomId)
              .where('status', isEqualTo: 'active')
              .where('position', isLessThan: currentPosition)
              .orderBy('position', descending: true)
              .limit(1)
              .get();

      if (prevMemberQuery.docs.isEmpty) {
        return null;
      }

      return Membership.fromMap(
        prevMemberQuery.docs.first.id,
        prevMemberQuery.docs.first.data(),
      ).position;
    } catch (e) {
      print('Error getting previous valid position: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
