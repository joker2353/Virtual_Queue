import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../../APIS/apis.dart';
import '../../Widget/chats/message_card.dart';
import '../../helper/my_date_util.dart';
import '../../main.dart';
import '../../models/chats/chat_user.dart';
import '../../models/chats/message.dart';
import 'view_profile_screen.dart';

//import 'package:flutter/foundation.dart' as foundation;

class ChatScreen extends StatefulWidget {
  final ChatUser user;
  const ChatScreen({super.key,required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  //for storing all messages
  List<Message> _list = [];

//for handling  message text changes
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  //for storing value of showing or hiding emoji
  bool _showEmoji = false,_isUploading =false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Focus.of(context).unfocus(),
      child: SafeArea(
        child: WillPopScope(
          onWillPop: () {
            if(_showEmoji) {
              setState(() => _showEmoji = !_showEmoji);
              return Future.value(false);
            }
            return Future.value(true);
          },
          child: Scaffold(
            backgroundColor: Colors.blue.shade50,  // Light blue background
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              flexibleSpace: _appBar(),
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                    Colors.blue.shade50,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder(
                      stream: APIs.getAllMessages(widget.user),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                        // return const AlertDialog(
                        //   content: CircularProgressIndicator(),
                        // );
                        return const SizedBox();
                      }
                      if (snapshot.hasError) {
                        return const SizedBox();
                        // return AlertDialog(
                        //   content: Text('Error: ${snapshot.error}'),
                        // );
                      }
                    
                            
                      //final _list = ["hii" , "hello"];
                        if(snapshot.hasData){
                          final data = snapshot.data?.docs;
                            
                         _list =data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
                          
                        }
                    
                    //showing messages
                        if(_list.isNotEmpty){
                            return ListView.builder(
                              reverse: true,
                            itemCount: _list.length,
                            padding: EdgeInsets.only(top: mq.height * .01),
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                             // return ChatUserCard(user: _isSearching? _searchList[index] : _list[index]);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: MessageCard(message: _list[index]),
                              );
                            });
                        }else{
                          return const Center(
                            child: Text('Say HII!',
                                    style: TextStyle(fontSize: 20),)
                          );
                        }
                        
                      }
                    ),
                  ),

                  //progress indicator for showing uploading 
                 if(_isUploading) 
                 const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )),
                    //chat user input filed
                  _chatInput(),
                  
                  //showing emojis on keyboard emoji button click & vice versa
                  Offstage(
                  offstage: !_showEmoji,
                  child: EmojiPicker(
                    textEditingController: _textController,
                    scrollController: _scrollController,
                    config: Config(
                      height: 256,
                      checkPlatformCompatibility: true,
                      viewOrderConfig: const ViewOrderConfig(),
                      emojiViewConfig: EmojiViewConfig(
                        // Issue: https://github.com/flutter/flutter/issues/28894
                        emojiSizeMax: 28 *
                            (foundation.defaultTargetPlatform ==
                                    TargetPlatform.iOS
                                ? 1.2
                                : 1.0),
                      ),
                      skinToneConfig: const SkinToneConfig(),
                      categoryViewConfig: const CategoryViewConfig(),
                      bottomActionBarConfig: const BottomActionBarConfig(),
                      searchViewConfig: const SearchViewConfig(),
                    ),
                  ),
                ),       
                  
                  ],),
            ),
          ),
        ),
      ),
    );
  }
  Widget _appBar(){

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(user: widget.user)));
      },
     child: StreamBuilder(
      stream: APIs.getUserInfo(widget.user), 
      builder: (context,snapshot) {

        //List<ChatUser> list =[];
      
            final data = snapshot.data?.docs;
            final list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
          

        return Row(children: [
        //back button
        IconButton(onPressed: () => Navigator.pop(context), 
        icon: const Icon(Icons.arrow_back,color: Colors.black54,)),
      
        //user profile picture
        ClipRRect(
                    borderRadius: BorderRadius.circular(mq.height*.3),
                    child: CachedNetworkImage(
                        height: mq.height * .05,
                        width: mq.height * .05,
                        imageUrl: list.isNotEmpty ? list[0].image! : widget.user.image!,
                        //placeholder: (context, url) => CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const CircleAvatar(child: Icon(CupertinoIcons.person),),
                    ),
                  ),
              const SizedBox(width: 10,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //user name
                Text(list.isNotEmpty ? list[0].name! : widget.user.email,
                style:const TextStyle(fontSize: 16,color: Colors.black87,fontWeight: FontWeight.w500)),
      
                const SizedBox(height: 2,),
                //last seen time jof user
                Text(list.isNotEmpty ? list[0].isOnline !=null ? 'online' 
                : MyDateUtil.getLastActiveTime(context: context, lastActive: list[0].lastActive!) 
                : MyDateUtil.getLastActiveTime(context: context, lastActive: widget.user.lastActive!),
                style:const TextStyle(fontSize: 13,color: Colors.black54)),
      
              ],)
                  
      ],);
    
      } ),
    );
  }

  Widget _chatInput(){
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: mq.height * .01,
        horizontal: mq.width * .025
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [ 
          Expanded(
            child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: Row(
              children: [
                 //emoji button
                 IconButton(onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _showEmoji = !_showEmoji );
                 }, 
                 icon: Icon(Icons.emoji_emotions,
                   color: Colors.blue.shade400,
                   size: 25,)),
            
                 Expanded(
                  child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.blue.shade200),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                 )),
            
                //pic image from gallery button
                 IconButton(onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  // Pick an multiple images
                        final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
                      
                      if(images != null){
                        
                        for(var i in images){
                            setState(() => _isUploading = true);
                            await APIs.sendChatImage(widget.user , File(i.path));
                            setState(() => _isUploading = false);
                        }
                      }
                
                 }, 
                 icon: Icon(Icons.image,
                   color: Colors.blue.shade400,
                   size: 26,)),
            
                 //take image from camera button
                 IconButton(onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                  // Pick an image.
                        final XFile? image = await picker.pickImage(source: ImageSource.camera,imageQuality: 70);

                        if(image != null){
                          setState(() => _isUploading = true);
                          await APIs.sendChatImage(widget.user , File(image.path));
                          setState(() => _isUploading = false);
                        }
                 }, 
                 icon: Icon(Icons.camera_alt_rounded,
                   color: Colors.blue.shade400,
                   size: 26,)),
              ],
            ),
                  ),
          ),

          SizedBox(width: mq.width * .02,),
      
          //send message button
          MaterialButton(onPressed: () {
            if(_textController.text.isNotEmpty){
              //for first message (add user to my_user collection of chat user)
              if(_list.isEmpty){
                APIs.sendFirstMessage(widget.user, _textController.text, Type.text);
              }else{
                APIs.sendMessage(widget.user, _textController.text, Type.text);
              }
              _textController.text ='';
            }
          },
          minWidth: 0,
          padding: EdgeInsets.all(10),
          shape: CircleBorder(),
          color: Colors.blue.shade400,
          child: Icon(Icons.send,
            color: Colors.white,
            size: 28,),)
        ]
      ),
    );
  }
}