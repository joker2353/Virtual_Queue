
// ignore_for_file: use_build_context_synchronously

import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../APIS/apis.dart';
import '../../Signup_Login/login.dart';
import '../../helper/dialogs.dart';
import '../../main.dart';
import '../../models/chats/chat_user.dart';
//import '../widgets/chat_user_card.dart';


class ProfileScreen extends StatefulWidget {
  final ChatUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() =>  _ProfileScreenState();
}

class  _ProfileScreenState extends State <ProfileScreen> {

final _formKey = GlobalKey<FormState>();
String? _image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(

          title: const Text('profile screen'),
          
          ),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mq.height * .05),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(width: mq.width,height: mq.height* .03,),
                  Stack(
                    children: [
                      _image != null ? 
                      //local image
                      ClipRRect(
                              borderRadius: BorderRadius.circular(mq.height*.1),
                              child: Image.file(
                                File(_image!),
                                  height: mq.height * .2,
                                  width: mq.height * .2,
                                  fit: BoxFit.cover,
                                  // imageUrl: "http://via.placeholder.com/350x150",
                                  // placeholder: (context, url) => CircularProgressIndicator(),
                                  // errorWidget: (context, url, error) => Icon(Icons.error),
                              ),
                            )
                            :
                      ClipRRect(
                              borderRadius: BorderRadius.circular(mq.height*.1),
                              child: CachedNetworkImage(
                                  height: mq.height * .2,
                                  width: mq.height * .2,
                                  fit: BoxFit.cover,
                                  imageUrl: widget.user.image !=null ? widget.user.image! :"http://via.placeholder.com/350x150",
                                  // placeholder: (context, url) => CircularProgressIndicator(),
                                   errorWidget: (context, url, error) => const CircleAvatar(child: Icon(CupertinoIcons.person),),
                              ),
                            ),

                            //edit image button
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: MaterialButton(
                                elevation: 1,
                                onPressed: (){
                                  _showBottomSheet();
                                },
                              shape: const CircleBorder(),
                              color: Colors.white,
                              child: const Icon(Icons.edit),),
                            )
                    ],
                  ),
                    
                        SizedBox(height: mq.height* .03,),
                    
                        Text(widget.user.email,style: const TextStyle(color: Colors.black54,fontSize: 16),),
                    
                         SizedBox(height: mq.height* .05,),
                    
                        TextFormField(
                          initialValue: widget.user.name,
                          onSaved: (val) => appUser.name =val ?? '',
                          validator: (val) => val != null && val.isNotEmpty ? null : 'Required Field',
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person,color: Colors.blue,) , 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText:'eg. raj rai',
                            label : const Text('Name')),
                            
                        ),
                    
                         SizedBox(height: mq.height* .02,),
                    
                        TextFormField(
                          initialValue: widget.user.about,
                          onSaved: (val) => appUser.about=val ?? '',
                          validator: (val) => val != null && val.isNotEmpty ? null : 'Required Field',
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.info_outline,color: Colors.blue,) , 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText:'eg. feeling happy',
                            label : const Text('About')),
                            
                        ),
                    
                        SizedBox(height: mq.height* .03),
                      
                      // updatr profile button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            minimumSize: Size(mq.width * .5, mq.height* .08),
                          ),
                          onPressed: (){
                            if(_formKey.currentState!.validate()){
                              _formKey.currentState!.save();
                              APIs.updateUserInfo().then((value){
                                Dialogs.showSnackbar(context, 'profile update successfully!');
                              });
                              log('inside validate');
                            }
                          }, 
                          icon: const Icon(Icons.edit,size: 30,),
                          label: const Text('update',style: TextStyle(fontSize: 16),),)
                    
                ],
              ),
            ),
          ),
        ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FloatingActionButton.extended(
              backgroundColor: Colors.redAccent,
              onPressed: () async {
              await APIs.updateActiveStatus(false);
              Dialogs.showProcessBar(context);
              await APIs.auth.signOut().then((Value) async{
                // await GoogleSignIn().signOut();
                //pop up dialog
                Navigator.pop(context);
                //pop up login screen
                Navigator.pop(context);
                APIs.auth = FirebaseAuth.instance;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }); 
             
            },
            icon: const Icon(Icons.logout),
            label: const Text('logout'),),
          ),
        
       
          ),
    );

  }

  //botton sheet for picking a profile for user
  void _showBottomSheet(){
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20),topRight: Radius.circular(20))),

          builder: (_)  {
            return ListView(
              shrinkWrap: true,
              padding: EdgeInsets.only(top: mq.height * .03,bottom: mq.height * .05),
              children: [
                const Text('pick profile picture',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20,fontWeight: FontWeight.w500)),
                SizedBox(height: mq.height* 0.02),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      //pick from gallery button
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 235, 205, 205),
                        shape: const CircleBorder(),
                        fixedSize: Size(mq.width* .3, mq.height *.15)),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        // Pick an image.
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery ,imageQuality: 80);

                        if(image != null){
                          setState(() {
                            _image = image.path;
                          });

                          APIs.updateProfilePicture(File(_image!));
                              Navigator.pop(context);
                        }
                      
                        
                      },
                       child: Image.asset('images/g.png',height: mq.height * .1 ,)),

                       
                      //take picture from camera
                       ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: const CircleBorder(),
                        fixedSize: Size(mq.width* .3, mq.height *.15)),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        // Pick an image.
                        final XFile? image = await picker.pickImage(source: ImageSource.camera,imageQuality: 80);

                        if(image != null){
                          setState(() {
                            _image = image.path;
                          });
                           APIs.updateProfilePicture(File(_image!));
                              Navigator.pop(context);
                        }
                      },
                       child: Image.asset('images/camera.jpg',height: mq.height * .1,)),

                  ],
                  
                )
              ],
            );
    });
  }

  
}

