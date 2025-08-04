import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String chatId; // Unique identifier for the chat conversation

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.chatId,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      chatId: map['chatId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'chatId': chatId,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? receiverName,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? chatId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      chatId: chatId ?? this.chatId,
    );
  }
}

class ChatConversation {
  final String chatId;
  final String participant1Id;
  final String participant1Name;
  final String participant2Id;
  final String participant2Name;
  final DateTime lastMessageTime;
  final String lastMessage;
  final bool isRead;
  final int unreadCount;
  final String roomId;

  ChatConversation({
    required this.chatId,
    required this.participant1Id,
    required this.participant1Name,
    required this.participant2Id,
    required this.participant2Name,
    required this.lastMessageTime,
    required this.lastMessage,
    this.isRead = false,
    this.unreadCount = 0,
    required this.roomId,
  });

  factory ChatConversation.fromMap(String id, Map<String, dynamic> map) {
    return ChatConversation(
      chatId: id,
      participant1Id: map['participant1Id'] ?? '',
      participant1Name: map['participant1Name'] ?? '',
      participant2Id: map['participant2Id'] ?? '',
      participant2Name: map['participant2Name'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp).toDate(),
      lastMessage: map['lastMessage'] ?? '',
      isRead: map['isRead'] ?? false,
      unreadCount: map['unreadCount'] ?? 0,
      roomId: map['roomId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participant1Id': participant1Id,
      'participant1Name': participant1Name,
      'participant2Id': participant2Id,
      'participant2Name': participant2Name,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessage': lastMessage,
      'isRead': isRead,
      'unreadCount': unreadCount,
      'roomId': roomId,
    };
  }
}
