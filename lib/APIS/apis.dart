import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
//import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '../main.dart';
import '../models/chats/chat_user.dart';
import '../models/chats/message.dart';

class APIs{
  //static late ChatUser me;
  //for authentication
  static FirebaseAuth auth = FirebaseAuth.instance;
  //for accessing cujrrent user
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  //for accessing firebase stroage
  static FirebaseStorage storage = FirebaseStorage.instance;
// //to return current user
   //static User get user => auth.currentUser!;
//for checkjing jif user exist or not j?


 // for accessing firebase messaging (push Notification)
 static FirebaseMessaging fMessaging = FirebaseMessaging.instance;
// for getting firebase messaging token
static Future<void> getFirebaseMessaingToken() async{
 await fMessaging.requestPermission();
 await fMessaging.getAPNSToken().then((t) {
  if( t != null){
    appUser.pushToken = t;
    log('Push Token: $t');
  }
 });

} 

//for sending push notification
 static Future<void> sendPushNotification(ChatUser chatUser, String msg) async {
    try {
      final body = {
        "message": {
          "token": chatUser.pushToken,
          "notification": {
            "title": appUser.name, 
            "body": msg,
            "android_channel_id": 'chats',
          },        
        "data": {
            "some_data" : "User ID: ${appUser.id!}",
          },
        }
      };

      // Firebase Project > Project Settings > General Tab > Project ID
      const projectID = 'wechat-a4729';

      // get firebase admin token
      final bearerToken = await NotificationAccessToken.getToken;

      log('bearerToken: $bearerToken');

      // handle null token
      if (bearerToken == null) return;

      var res = await post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$projectID/messages:send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken'
        },
        body: jsonEncode(body),
      );

      log('Response status: ${res.statusCode}');
      log('Response body: ${res.body}');
    } catch (e) {
      log('\nsendPushNotificationE: $e');
    }
  }

//for checking if user exists or not
  static Future<bool> userExists() async{
    return (await firestore.collection('users').doc(appUser.email).get()).exists;
  }

  // for adding an chat user for our conversation
  static Future<bool> addChatUser(String email) async{
    final data = await firestore.collection('users').where('email',isEqualTo: email).get();
    if(data.docs.isNotEmpty && data.docs.first.id != appUser.email){
       firestore
          .collection('users')
          .doc(appUser.email)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});
        firestore
          .collection('users')
          .doc(data.docs.first.id)
          .collection('my_users')
          .doc(appUser.email)
          .set({});
      return true;
    }else{
      return false;
    }
  }
//for getting current user info
static Future<void> getSelfInfo() async{
    await firestore.collection('users').doc(appUser.email).get().then((user) async {
      if(user.exists){
        appUser = ChatUser.fromJson(user.data()!);
        await getFirebaseMessaingToken();

        //for setting user status to active
        await APIs.updateActiveStatus(true);
        //getFirebaseMessaingToken();
      }else {
        await createUser().then((value) => getSelfInfo());
      }
    });
  }

  static Future<void> getInstructorInfo(String email) async{
    await firestore.collection('users').doc(email).get().then((user) async {
      if(user.exists){
        courseInstructor = ChatUser.fromJson(user.data()!);
        await getFirebaseMessaingToken();

        //for setting user status to active
        await APIs.updateActiveStatus(true);
        //getFirebaseMessaingToken();
      }else {
        await createUser().then((value) => getSelfInfo());
      }
    });
  }

  //for creating a new user 
  static Future<void> createUser() async {
    try {
      // First create user in Firebase Auth
      final credential = await auth.createUserWithEmailAndPassword(
        email: appUser.email.toString(),
        password: appUser.password.toString(),
      );

      final time = DateTime.now().microsecondsSinceEpoch.toString();
      
      // Create ChatUser object with all required fields
      final chatUser = ChatUser(
        id: credential.user!.uid,
        about: 'Hey, I am using we Chat!', 
        createdAt: time, 
        email: appUser.email.toString(), 
        image: appUser.image?.toString() ?? '', 
        isOnline: false, 
        lastActive: time, 
        name: appUser.name.toString(), 
        pushToken: '',
        password: appUser.password.toString(),
        role: 'student', // default role
        courses: [], // initialize empty courses list
      );

      // Store user data in Firestore using email as document ID
      return await firestore
          .collection('users')
          .doc(appUser.email)
          .set(chatUser.toJson());

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw 'Password should be at least 8 characters';
        case 'email-already-in-use':
          throw 'Email is already registered';
        case 'invalid-email':
          throw 'Please enter a valid email address';
        default:
          throw 'Authentication error: ${e.message}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
  //geting aimy user id
  static Stream<QuerySnapshot<Map<String,dynamic>>> getMyUsersId(){
   // log(ChatUser.fromJson(firestore.collection('users').where('email', isEqualTo: appUser.email).snapshots()));
    return firestore.collection('users').doc(appUser.email).collection("my_users").snapshots();
  }
//geting aii user
  static Stream<QuerySnapshot<Map<String,dynamic>>> getAllUsers(List<String>userIds){
   // log(ChatUser.fromJson(firestore.collection('users').where('email', isEqualTo: appUser.email).snapshots()));
    return firestore.collection('users')
    .where('email', whereIn: userIds.isEmpty ? [''] : userIds)
    .snapshots();
  }

  //for adding an user to  my user when first message is send
 static Future<void> sendFirstMessage(ChatUser chatUser,String msg,Type type) async{
    await firestore.collection('users')
    .doc(chatUser.email).collection("my_users")
    .doc(appUser.email).set({})
    .then((value)=> sendMessage(chatUser, msg, type));
  }
//for updste user information
 static Future<void> updateUserInfo() async{
    await firestore.collection('users').doc(appUser.email).update({
      'name':appUser.name,
      'about': appUser.about});
  }
  //upload profile picture of user
  static Future<void>updateProfilePicture(File file) async{
    final ext = file.path.split('.').last;
    final ref = storage.ref().child('profile_pictures/${appUser.email}.$ext');
    await ref
        .putFile(file,SettableMetadata(contentType: 'image/$ext'))
        .then((po) {
          log('Data Transferred: ${po.bytesTransferred / 1000}kb');
        });

     appUser.image = await ref.getDownloadURL();

    await firestore.collection('users').doc(appUser.email).update({
      'image':appUser.image});
  }

  //for getting specific user info
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(ChatUser chatUser){
    return firestore.collection('users').where('email', isEqualTo: appUser.email).snapshots();
  }
  //update online or last active status of user
  static Future<void> updateActiveStatus(bool isOnline) async{
    return firestore.collection('users').doc(appUser.email)
    .update({'is_online' : isOnline, 
    'last_active' : DateTime.now().microsecondsSinceEpoch.toString(),
    'push_token' : appUser.pushToken,
    });
  }

  ///******************  chat Screen Related APIs  ***********************
  

  //useful for getting conversation
  static String getConversationID(String fndEmail) => appUser.email.hashCode <= fndEmail.hashCode 
    ? '${appUser.email}_$fndEmail' 
    : '${fndEmail}_${appUser.email}';

  //for getting all message of a specific conversation from firestore database
  static Stream<QuerySnapshot<Map<String,dynamic>>> getAllMessages(ChatUser user){
   // log(ChatUser.fromJson(firestore.collection('users').where('email', isEqualTo: appUser.email).snapshots()));
    return firestore.collection('chats/${getConversationID(user.email)}/messages/').orderBy('sent',descending: true).snapshots();
  }
  //for sending message
  static Future<void> sendMessage(ChatUser user,String msg ,Type type) async{
    //messsage sending time (also used as id)
    final time = DateTime.now().microsecondsSinceEpoch.toString();

    //message to send
    final Message message =  Message(msg: msg, read: "", receiver: user.email, sender: appUser.email, sent: time, type: type);

    final ref=firestore.collection('chats/${getConversationID(user.email)}/messages/');
    await ref.doc().set(message.toJson()).then((value) => sendPushNotification(user,type == Type.text ? msg : 'image'));
  }

  //update read status jof message
  static Future<void> updateMessageReadStatus(Message message) async {
    firestore.collection('chats/${getConversationID(message.sender)}/messages/')
    .doc(message.sent).update({'read':DateTime.now().microsecondsSinceEpoch.toString()});
  }


  //for getting only last message of a specific conversation from firestore database
  static Stream<QuerySnapshot<Map<String,dynamic>>> getLastMessage(ChatUser user){
   // log(ChatUser.fromJson(firestore.collection('users').where('email', isEqualTo: appUser.email).snapshots()));
    return firestore.collection('chats/${getConversationID(user.email)}/messages/')
    .orderBy('sent',descending: true)
    .limit(1).snapshots();
  }

  //send chat image
  static Future<void> sendChatImage(ChatUser chatUser,File file) async {
    
    final ext = file.path.split('.').last;
    final ref = storage.ref().child('images//${getConversationID(chatUser.email)}/${DateTime.now().microsecondsSinceEpoch}.$ext');
    await ref
        .putFile(file,SettableMetadata(contentType: 'image/$ext'))
        .then((po) {
          log('Data Transferred: ${po.bytesTransferred / 1000}kb');
        });

     final imageUrl = await ref.getDownloadURL();

    await APIs.sendMessage(chatUser, imageUrl, Type.image);
  }

  //delete message
  static Future<void> deleteMessage(Message message) async{
   await firestore.collection('chats/${getConversationID(message.receiver)}/messages/')
    .doc(message.sent).delete();

    
    if(message.type == Type.image){
      await storage.refFromURL(message.msg).delete();
    }
  
  }

  //update message
  static Future<void> updateMessage(Message message,String updatedMsg) async{
   await firestore.collection('chats/${getConversationID(message.receiver)}/messages/')
    .doc(message.sent).update({'msg':updatedMsg});
  }

  // for user login
  static Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // First verify with Firebase Auth
      final UserCredential credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // If auth successful, get user data from Firestore
        final userDoc = await firestore
            .collection('users')
            .doc(email)
            .get();

        if (userDoc.exists) {
          // Convert Firestore data to ChatUser object
          appUser = ChatUser.fromJson(userDoc.data()!);
          
          // Get Firebase messaging token
          await getFirebaseMessaingToken();

          // Update user's active status
          await updateActiveStatus(true);
          
          return "success";
        } else {
          // If user exists in Auth but not in Firestore
          await auth.signOut();
          return "User data not found";
        }
      } else {
        return "Login failed";
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return "No user found with this email";
        case 'wrong-password':
          return "Incorrect password";
        case 'invalid-email':
          return "Please enter a valid email address";
        case 'user-disabled':
          return "This account has been disabled";
        case 'too-many-requests':
          return "Too many failed attempts. Please try again later";
        default:
          return "Login error: ${e.message}";
      }
    } catch (e) {
      return e.toString();
    }
  }
}