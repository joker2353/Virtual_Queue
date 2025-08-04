import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _messagesSubscription;

  List<ChatConversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Generate a unique chat ID for two participants in a specific room
  String _generateChatId(
    String participant1Id,
    String participant2Id,
    String roomId,
  ) {
    // Sort IDs to ensure consistent chat ID regardless of who initiates
    final sortedIds = [participant1Id, participant2Id]..sort();
    return '${roomId}_${sortedIds[0]}_${sortedIds[1]}';
  }

  // Send a message
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String message,
    required String roomId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final chatId = _generateChatId(senderId, receiverId, roomId);
      final timestamp = DateTime.now();

      print(
        'ChatProvider: Sending message with chatId: $chatId, roomId: $roomId',
      );

      // Create the message
      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'message': message,
        'timestamp': Timestamp.fromDate(timestamp),
        'isRead': false,
        'chatId': chatId,
        'roomId': roomId,
      };

      // Add message to Firestore
      await _firestore.collection('chat_messages').add(messageData);
      print('ChatProvider: Message sent successfully to Firestore');

      // Update or create conversation
      await _updateConversation(
        chatId: chatId,
        participant1Id: senderId,
        participant1Name: senderName,
        participant2Id: receiverId,
        participant2Name: receiverName,
        lastMessage: message,
        lastMessageTime: timestamp,
        roomId: roomId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update or create conversation
  Future<void> _updateConversation({
    required String chatId,
    required String participant1Id,
    required String participant1Name,
    required String participant2Id,
    required String participant2Name,
    required String lastMessage,
    required DateTime lastMessageTime,
    required String roomId,
  }) async {
    final conversationData = {
      'participant1Id': participant1Id,
      'participant1Name': participant1Name,
      'participant2Id': participant2Id,
      'participant2Name': participant2Name,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'isRead': false,
      'unreadCount': FieldValue.increment(1),
      'roomId': roomId,
    };

    await _firestore
        .collection('chat_conversations')
        .doc(chatId)
        .set(conversationData, SetOptions(merge: true));
  }

  // Load conversations for a user in a specific room
  Future<void> loadConversations(String userId, String roomId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Cancel existing subscription
      _conversationsSubscription?.cancel();

      // Listen to conversations where user is a participant in this specific room
      _conversationsSubscription = _firestore
          .collection('chat_conversations')
          .where('participant1Id', isEqualTo: userId)
          .where('roomId', isEqualTo: roomId)
          .snapshots()
          .listen((snapshot1) {
            _processConversationsSnapshot(snapshot1, userId);
          });

      // Also listen to conversations where user is participant2 in this specific room
      _firestore
          .collection('chat_conversations')
          .where('participant2Id', isEqualTo: userId)
          .where('roomId', isEqualTo: roomId)
          .snapshots()
          .listen((snapshot2) {
            _processConversationsSnapshot(snapshot2, userId);
          });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processConversationsSnapshot(QuerySnapshot snapshot, String userId) {
    print(
      'ChatProvider: Processing conversations snapshot with ${snapshot.docs.length} documents',
    );

    final newConversations =
        snapshot.docs
            .map(
              (doc) => ChatConversation.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ),
            )
            .toList();

    // Merge with existing conversations and remove duplicates
    final allConversations = [..._conversations, ...newConversations];
    final uniqueConversations = <String, ChatConversation>{};

    for (final conversation in allConversations) {
      uniqueConversations[conversation.chatId] = conversation;
    }

    _conversations =
        uniqueConversations.values.toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    print(
      'ChatProvider: Updated conversations list with ${_conversations.length} conversations',
    );
    notifyListeners();
  }

  // Load messages for a specific chat
  Future<void> loadMessages(String chatId) async {
    try {
      print('ChatProvider: Loading messages for chatId: $chatId');
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Cancel existing subscription
      _messagesSubscription?.cancel();

      // Listen to messages for this chat
      _messagesSubscription = _firestore
          .collection('chat_messages')
          .where('chatId', isEqualTo: chatId)
          .snapshots()
          .listen(
            (snapshot) {
              print(
                'ChatProvider: Received ${snapshot.docs.length} messages for chatId: $chatId',
              );
              _messages =
                  snapshot.docs
                      .map(
                        (doc) => ChatMessage.fromMap(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ),
                      )
                      .toList()
                    ..sort(
                      (a, b) => a.timestamp.compareTo(b.timestamp),
                    ); // Sort in memory
              print(
                'ChatProvider: Updated messages list with ${_messages.length} messages',
              );
              notifyListeners();
            },
            onError: (error) {
              print('ChatProvider: Error in messages stream: $error');
              _error = error.toString();
              notifyListeners();
            },
          );

      _isLoading = false;
      notifyListeners();
      print(
        'ChatProvider: Messages stream setup completed for chatId: $chatId',
      );
    } catch (e) {
      print('ChatProvider: Error setting up messages stream: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    try {
      final batch = _firestore.batch();

      // Mark messages as read
      final messagesQuery =
          await _firestore
              .collection('chat_messages')
              .where('chatId', isEqualTo: chatId)
              .where('receiverId', isEqualTo: currentUserId)
              .where('isRead', isEqualTo: false)
              .get();

      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Reset unread count in conversation
      batch.update(_firestore.collection('chat_conversations').doc(chatId), {
        'unreadCount': 0,
        'isRead': true,
      });

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get conversation by chat ID
  ChatConversation? getConversation(String chatId) {
    try {
      return _conversations.firstWhere((conv) => conv.chatId == chatId);
    } catch (e) {
      return null;
    }
  }

  // Get other participant name
  String getOtherParticipantName(String chatId, String currentUserId) {
    final conversation = getConversation(chatId);
    if (conversation == null) return 'Unknown';

    if (conversation.participant1Id == currentUserId) {
      return conversation.participant2Name;
    } else {
      return conversation.participant1Name;
    }
  }

  // Clear messages when leaving chat
  void clearMessages() {
    print('ChatProvider: Clearing messages');
    _messages = [];
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  // Manually refresh messages for a specific chat
  Future<void> refreshMessages(String chatId) async {
    print('ChatProvider: Manually refreshing messages for chatId: $chatId');
    await loadMessages(chatId);
  }

  // Dispose
  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
