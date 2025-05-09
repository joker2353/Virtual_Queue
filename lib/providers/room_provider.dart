import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import 'dart:async';

class RoomProvider with ChangeNotifier {
  final String userId;
  List<Room> joinedRooms = [];
  StreamSubscription? _roomsSubscription;
  final _firestore = FirebaseFirestore.instance;

  RoomProvider({required this.userId}) {
    _listenToUserRooms();
  }

  void _listenToUserRooms() {
    print('Setting up rooms listener for user: $userId');
    
    // Listen to user_rooms collection which contains all room associations
    _roomsSubscription = _firestore
        .collection('user_rooms')
        .doc(userId)
        .collection('rooms')
        .snapshots()
        .listen((snapshot) async {
          print('User rooms update triggered. Count: ${snapshot.docs.length}');
          
          List<Room> updatedRooms = [];
          
          for (var userRoomDoc in snapshot.docs) {
            final userRoomData = userRoomDoc.data();
            final roomId = userRoomData['roomId'] as String;
            final roomType = userRoomData['type'] as String; // 'creator', 'member', or 'pending'
            final position = userRoomData['position'] as int? ?? 0;
            
            try {
              // Get the actual room data
              final roomDoc = await _firestore
                  .collection('rooms')
                  .doc(roomId)
                  .get();
              
              if (roomDoc.exists) {
                final roomData = roomDoc.data()!;
                print('Processing room: $roomId, type: $roomType');
                
                updatedRooms.add(Room.fromFirestore(
                  roomId,
                  roomData,
                  isMember: roomType == 'member' || roomType == 'creator',
                  isPending: roomType == 'pending',
                  userPosition: position,
                ));
              }
            } catch (e) {
              print('Error fetching room $roomId: $e');
            }
          }
          
          print('Final rooms count: ${updatedRooms.length}');
          joinedRooms = updatedRooms;
          notifyListeners();
        });
  }

  Future<String> createRoom(
    String name,
    int capacity,
    String notice,
    List<Map<String, String>> formSchema,
  ) async {
    final roomId = generateRoomCode();
    
    // Create the room document
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .set({
          'name': name,
          'creatorId': userId,
          'capacity': capacity,
          'currentPosition': 1,
          'notice': notice,
          'formSchema': formSchema,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });

    // Add room reference to user_rooms collection
    await _firestore
        .collection('user_rooms')
        .doc(userId)
        .collection('rooms')
        .doc(roomId)
        .set({
          'roomId': roomId,
          'type': 'creator',
          'position': 0,
          'joinedAt': FieldValue.serverTimestamp(),
        });

    return roomId;
  }

  Future<void> sendJoinRequest(
    String roomId,
    Map<String, String> formData,
  ) async {
    // Add join request
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('joinRequests')
        .doc(userId)  // Use userId as document ID to prevent duplicates
        .set({
          'userId': userId,
          'formData': formData,
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

    // Add room reference to user_rooms collection
    await _firestore
        .collection('user_rooms')
        .doc(userId)
        .collection('rooms')
        .doc(roomId)
        .set({
          'roomId': roomId,
          'type': 'pending',
          'position': 0,
          'joinedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    super.dispose();
  }
}

String generateRoomCode() {
  final random = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
  return random.toString().padLeft(6, '0');
}
