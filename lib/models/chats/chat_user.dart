// class ChatUser {
//   ChatUser({
//      required this.email,
//      required this.password,
//      this.about,
//      this.name,
//      this.createdAt,
//      this.id,
//      this.image,
//      this.isOnline,
//      this.lastActive,
//      this.pushToken,  
//   });

//   late  String email;
//   late  String password;
//   late  String? about;
//   late  String? createdAt;
//   late  String? id;
//   late  String? image;
//   late  bool? isOnline;
//   late  String? lastActive;
//   late  String? name;
//   late  String? pushToken;
//   late  String? role;
//   late List<String>? courses;
   

//   ChatUser.fromJson(Map<String, dynamic> json) {
//     about = json['about'] ?? ' ';
//     createdAt = json['created_at'] ?? ' ';
//     email = json['email'] ?? ' ';
//     id = json['id'] ?? ' ';
//     image = json['image'] ?? ' ';
//     isOnline = json['is_online'] ?? false; // isOnline is a bool, so default to false
//     lastActive = json['last_active'] ?? ' ';
//     name = json['name'] ?? ' ';
//     pushToken = json['push_token'] ?? ' ';
//     password = json['password'] ?? ' '; 
//   }

//   Map<String, dynamic> toJson() {
//     return {
//        "about": about,
//       if (createdAt != null) "created_at": createdAt,
//            "email": email,
//       if (isOnline != null) "is_online": isOnline,
//       if (lastActive != null) "last_active": lastActive,
//         "name": name,
//       if (pushToken != null) "push_token": pushToken,
//            "password": password,
//       if (image != null) "image" :image,
//       if (id != null) "id" :id
//     };
//   }
// }
class ChatUser {
  ChatUser({
    required this.email,
    required this.password,
    this.about,
    this.name,
    this.createdAt,
    this.id,
    this.image,
    this.isOnline,
    this.lastActive,
    this.pushToken,
    this.courses,
    this.role,
  });

  late String email;
  late String password;
  late String? about;
  late String? createdAt;
  late String? id;
  late String? image;
  late bool? isOnline;
  late String? lastActive;
  late String? name;
  late String? pushToken;
  late String? role;
  late List<String>? courses; // List to hold multiple course IDs

  ChatUser.fromJson(Map<String, dynamic> json) {
    about = json['about'] ?? ' ';
    createdAt = json['created_at'] ?? ' ';
    email = json['email'] ?? ' ';
    id = json['id'] ?? ' ';
    image = json['image'] ?? ' ';
    isOnline = json['is_online'] ?? false; // default to false if not provided
    lastActive = json['last_active'] ?? ' ';
    name = json['name'] ?? ' ';
    pushToken = json['push_token'] ?? ' ';
    password = json['password'] ?? ' ';
    role = json['role'] ?? ' ';

    // Check if courses exists and is a list, then cast each element to String
    if (json['courses'] != null) {
      courses = List<String>.from(json['courses']);
    } else {
      courses = [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "about": about,
      if (createdAt != null) "created_at": createdAt,
      "email": email,
      if (isOnline != null) "is_online": isOnline,
      if (lastActive != null) "last_active": lastActive,
      "name": name,
      if (pushToken != null) "push_token": pushToken,
      "password": password,
      if (image != null) "image": image,
      if (id != null) "id": id,
      if (role != null) "role": role,
      if (courses != null) "courses": courses,
    };
  }
}

