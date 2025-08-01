import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../APIS/apis.dart';
import '../../helper/my_date_util.dart';
import '../../main.dart';
import '../../models/chats/chat_user.dart';
import '../../models/chats/message.dart';
import '../../views/chats/chat_screen.dart';

import 'dialogs/profile_dialog.dart';

class ChatUserCard extends StatefulWidget {
  final ChatUser user;
  const ChatUserCard({super.key,required this.user});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {

  //last message info (if null --> no message)
  Message? _message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(user: widget.user))
            );
          },
          child: StreamBuilder(
            stream: APIs.getLastMessage(widget.user),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final data = snapshot.data?.docs;
                final list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];

                if(list.isNotEmpty) _message = list[0];

                if(data != null && data.first.exists){
                  _message = Message.fromJson(data.first.data());
                }

              } else {
                _message = null; // No message
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.shade100,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(mq.height * .3),
                          child: CachedNetworkImage(
                            height: mq.height * .055,
                            width: mq.height * .055,
                            imageUrl: widget.user.image!,
                            errorWidget: (context, url, error) =>
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(CupertinoIcons.person,
                                  color: Colors.blue.shade700
                                ),
                              ),
                          ),
                        ),
                      ),
                      if (_message != null && _message!.read.isEmpty &&
                          _message!.sender != appUser.email)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    widget.user.name!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _message != null
                        ? _message!.type == Type.image
                            ? 'Image'
                            : _message!.msg
                        : widget.user.about!,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  trailing: _message == null
                      ? null
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              MyDateUtil.getLastMessageTime(
                                context: context,
                                time: _message!.sent,
                              ),
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}