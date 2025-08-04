import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

import '../widgets/loading_indicator.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String roomId;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.roomId,
  });

  static void navigate(
    BuildContext context, {
    required String receiverId,
    required String receiverName,
    required String roomId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatPage(
              receiverId: receiverId,
              receiverName: receiverName,
              roomId: roomId,
            ),
      ),
    );
  }

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatProvider _chatProvider;
  late AuthProvider _authProvider;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Generate chat ID with roomId
    final currentUserId = _authProvider.user?.uid ?? '';
    final sortedIds = [currentUserId, widget.receiverId]..sort();
    _chatId = '${widget.roomId}_${sortedIds[0]}_${sortedIds[1]}';

    // Load messages
    await _chatProvider.loadMessages(_chatId!);

    // Mark messages as read
    await _chatProvider.markMessagesAsRead(_chatId!, currentUserId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatProvider.clearMessages();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final currentUser = _authProvider.user;
    if (currentUser == null) return;

    // Clear input immediately for better UX
    _messageController.clear();

    try {
      await _chatProvider.sendMessage(
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'Customer',
        receiverId: widget.receiverId,
        receiverName: widget.receiverName,
        message: message,
        roomId: widget.roomId,
      );

      // Force refresh messages to ensure real-time update
      if (_chatId != null) {
        await _chatProvider.refreshMessages(_chatId!);
      }

      // Wait a bit for the real-time update to process
      await Future.delayed(Duration(milliseconds: 100));
      _scrollToBottom();
    } catch (e) {
      // If sending fails, restore the message
      _messageController.text = message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.store, color: Colors.teal.shade700),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Shop Owner',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      body: Column(
        children: [
          // Messages area
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return Center(child: LoadingIndicator());
                }

                if (chatProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(chatProvider.error!),
                      ],
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      if (_chatId != null) {
                        await _chatProvider.refreshMessages(_chatId!);
                      }
                    },
                    child: ListView(
                      children: [
                        SizedBox(height: 200),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start a conversation with the shop owner',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (_chatId != null) {
                      await _chatProvider.refreshMessages(_chatId!);
                    }
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      final isMe = message.senderId == _authProvider.user?.uid;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment:
                              isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.teal.shade100,
                                child: Icon(
                                  Icons.store,
                                  size: 16,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isMe
                                          ? Colors.teal.shade500
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.message,
                                      style: TextStyle(
                                        color:
                                            isMe
                                                ? Colors.white
                                                : Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _formatTime(message.timestamp),
                                      style: TextStyle(
                                        color:
                                            isMe
                                                ? Colors.white70
                                                : Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.teal.shade100,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // Message input area
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    return GestureDetector(
                      onTap: chatProvider.isLoading ? null : _sendMessage,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              chatProvider.isLoading
                                  ? Colors.grey.shade300
                                  : Colors.teal,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child:
                            chatProvider.isLoading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey.shade600,
                                    ),
                                  ),
                                )
                                : Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
