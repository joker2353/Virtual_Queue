class Message {
  Message({
    required this.msg,
    required this.read,
    required this.receiver,
    required this.sender,
    required this.sent,
    required this.type,
  });
  late final String msg;
  late final String read;
  late final String receiver;
  late final String sender;
  late final String sent;
  late final Type type;
  
  Message.fromJson(Map<String, dynamic> json){
    msg = json['msg'].toString();
    read = json['read'].toString();
    receiver = json['receiver'].toString();
    sender = json['sender'].toString();
    sent = json['sent'].toString();
    type = json['type'].toString() == Type.image.name ? Type.image : Type.text;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['msg'] = msg;
    data['read'] = read;
    data['receiver'] = receiver;
    data['sender'] = sender;
    data['sent'] = sent;
    data['type'] = type.name;
    return data;
  }
}

enum Type { text ,image }