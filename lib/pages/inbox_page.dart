import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

import '../widgets/loading_indicator.dart';
import 'chat_page.dart';

class InboxPage extends StatefulWidget {
  final String roomId;

  const InboxPage({super.key, required this.roomId});

  static void navigate(BuildContext context, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InboxPage(roomId: roomId)),
    );
  }

  @override
  _InboxPageState createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late ChatProvider _chatProvider;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final currentUserId = _authProvider.user?.uid;
    if (currentUserId != null) {
      await _chatProvider.loadConversations(currentUserId, widget.roomId);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _truncateMessage(String message, int maxLength) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inbox', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadConversations),
        ],
      ),
      body: Consumer<ChatProvider>(
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
                    'Error loading conversations',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(chatProvider.error!),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadConversations,
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (chatProvider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Customer messages will appear here',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: chatProvider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = chatProvider.conversations[index];
                final currentUserId = _authProvider.user?.uid;
                final otherParticipantName = chatProvider
                    .getOtherParticipantName(
                      conversation.chatId,
                      currentUserId ?? '',
                    );

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.teal.shade100,
                      child: Icon(
                        Icons.person,
                        color: Colors.teal.shade700,
                        size: 24,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherParticipantName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          _truncateMessage(conversation.lastMessage, 50),
                          style: TextStyle(
                            color:
                                conversation.unreadCount > 0
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                            fontWeight:
                                conversation.unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatTime(conversation.lastMessageTime),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Navigate to chat page
                      ChatPage.navigate(
                        context,
                        receiverId:
                            conversation.participant1Id == currentUserId
                                ? conversation.participant2Id
                                : conversation.participant1Id,
                        receiverName: otherParticipantName,
                        roomId: widget.roomId,
                      );
                    },
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
