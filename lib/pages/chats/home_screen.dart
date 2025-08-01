import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../APIS/apis.dart';
import '../../Widget/chats/chat_user_card.dart';
import '../../helper/dialogs.dart';
import '../../main.dart';
import '../../models/chats/chat_user.dart';
import 'profile_screen.dart';
//import '../widgets/chat_user_card.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() =>  _HomeScreenState();
}

class  _HomeScreenState extends State <HomeScreen> {
 List<ChatUser> _list = [];
 final List<ChatUser> _searchList = [];
 bool _isSearching =false;

@override
 void initState(){
  super.initState();
  APIs.getSelfInfo();
  
  SystemChannels.lifecycle.setMessageHandler((message){
    if(message.toString().contains('resume'))APIs.updateActiveStatus(true);
    if(message.toString().contains('pause'))APIs.updateActiveStatus(false);
      return Future.value(message);
  });
 }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        onWillPop: () {
          if(_isSearching) {
            setState(() => _isSearching = !_isSearching);
            return Future.value(false);
          }
          return Future.value(true);
        },
        child: Scaffold(
          backgroundColor: Colors.blue.shade50,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Icon(CupertinoIcons.home,
              color: Colors.blue.shade700
            ),
            title: _isSearching
                ? TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(color: Colors.blue.shade200),
                    ),
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: 0.5,
                      color: Colors.black87,
                    ),
                    onChanged: (val) {
                      _searchList.clear();
                      for(var i in _list){
                        if(i.name!.toLowerCase().contains(val.toLowerCase()) ||
                          i.name!.toLowerCase().contains(val.toLowerCase())){
                          _searchList.add(i);
                        }
                        setState(() {
                          _searchList;
                        });
                      }
                    },
                  )
                : Text('Messages',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    )
                  ),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() => _isSearching = !_isSearching);
                },
                icon: Icon(
                  _isSearching
                      ? CupertinoIcons.clear_circled_solid
                      : Icons.search,
                  color: Colors.blue.shade700,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: appUser)
                    ),
                  );
                },
                icon: Icon(Icons.more_vert,
                  color: Colors.blue.shade700
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addChatUserDialog,
            backgroundColor: Colors.blue.shade400,
            child: Icon(Icons.add_comment_rounded,
              color: Colors.white
            ),
            elevation: 4,
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
            child: StreamBuilder(
              stream: APIs.getMyUsersId(),
             builder: (context, Snapshot){
              if(Snapshot.hasData){
              return  StreamBuilder(
              stream: APIs.getAllUsers(
                Snapshot.data?.docs.map((e) => e.id).toList() ?? []
              ),
              builder: (context ,snapshot){
                if (snapshot.connectionState == ConnectionState.waiting) {
                return const AlertDialog(
                  content: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return AlertDialog(
                  content: Text('Error: ${snapshot.error}'),
                );
              }
        
                // Switch(snapshot.connectionState){
        
                //   case ConnectionState.waiting:
                //   case ConnectionState.none:
                //     return const Center(child: CircularProgressIndicator());
        
                //   case ConnectionState.active:
                //   case ConnectionState.done:
        
        
                // }
        
                // final list = [];
        
                if(snapshot.hasData){
                  final data = snapshot.data?.docs;
        
                  _list =data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
                
                }
                if(_list.isNotEmpty){
                    return ListView.builder(
                    itemCount: _isSearching ? _searchList.length : _list.length,
                    padding: EdgeInsets.only(top: mq.height * .01),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return ChatUserCard(user: _isSearching? _searchList[index] : _list[index]);
                     // return Text('name: salasaowa');
                    });
                }else{
                  return const Center(
                    child: Text('No Connections Found!',
                            style: TextStyle(fontSize: 20),)
                  );
                }
                
              }
            );
              }
              return const Center(child: CircularProgressIndicator(strokeWidth: 2,),);
            })
        ),
      ),
    ),);
  }

  //for adding new chat user
  void _addChatUserDialog() {
    String email = '';

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              contentPadding: const EdgeInsets.only(
                  left: 24, right: 24, top: 20, bottom: 10),

              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20))),

              //title
              title: const Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: Colors.blue,
                    size: 28,
                  ),
                  Text(' Add User')
                ],
              ),

              //content
              content: TextFormField(
                // initialValue: 'updatedMsg',
                maxLines: null,
                onChanged: (value) => email = value,
                decoration: const InputDecoration(
                  hintText: 'Email id',
                  prefixIcon: Icon(Icons.email,color: Colors.blue,),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)))),
              ),

              //actions
              actions: [
                //cancel button
                MaterialButton(
                    onPressed: () {
                      //hide alert dialog
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    )),

                //add button
                MaterialButton(
                    onPressed: () async {
                      //hide alert dialog
                      Navigator.pop(context);
                      if(email.isNotEmpty){
                       await APIs.addChatUser(email).then((value){
                        if(!value){
                          Dialogs.showSnackbar(context,'User does not Exists!');
                        }
                       });
                      }
                      //APIs.updateMessage(widget.message, updatedMsg);
                    },
                    child: const Text(
                      'Add',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ))
              ],
            ));
  }
}