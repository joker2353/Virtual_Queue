import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class MyDateUtil {
  //for getting formatted time frjom millisecondsSince string
  static String getFormattedTime(
    {required BuildContext context,required String time}){
      final date = DateTime.fromMicrosecondsSinceEpoch(int.parse(time));

    return TimeOfDay.fromDateTime(date).format(context);
  }
  
    // for getting formatted time for sent & read
  static String getMessageTime(
      {required BuildContext context, required String time}) {
    final DateTime sent = DateTime.fromMillisecondsSinceEpoch(int.parse(time));
    final DateTime now = DateTime.now();

    final formattedTime = TimeOfDay.fromDateTime(sent).format(context);
    if (now.day == sent.day &&
        now.month == sent.month &&
        now.year == sent.year) {
      return formattedTime;
    }

    return now.year == sent.year
        ? '$formattedTime - ${sent.day} ${_getMonth(sent)}'
        : '$formattedTime - ${sent.day} ${_getMonth(sent)} ${sent.year}';
  }

   //for getting formatted time frjom millisecondsSince string
  static String getLastMessageTime(
    {required BuildContext context,required String time , bool showYear =false }){
      final DateTime sent = DateTime.fromMicrosecondsSinceEpoch(int.parse(time));

      final DateTime now = DateTime.now();

      if(now.day == sent.day && now.month == sent.month && now.year == sent.year){
        return TimeOfDay.fromDateTime(sent).format(context);
      }

    return showYear ? '${sent.day} ${_getMonth(sent)}b${sent.year}' : '${sent.day} ${_getMonth(sent)}';
  }

  //get month name from month no. or index
  static String _getMonth(DateTime date){
    return DateFormat('MMM').format(date);
  }

  //get formatted last active time of user in chat screen
  static String getLastActiveTime({required BuildContext context,required String lastActive }){
    final int i = int.tryParse(lastActive) ?? -1;
    //if time is not available then return below ststement
    if(i == -1) return 'Last seen not available';
    DateTime time =  DateTime.fromMillisecondsSinceEpoch(i);
    DateTime now = DateTime.now();

    String fromDateTime = TimeOfDay.fromDateTime(time).format(context);
    if(time.day == now.day && time.month == now.month && time.year == now.year){
      return 'Last seen today at $fromDateTime';
    }
    if((now.difference(time).inHours/24).round() == 1){
      return 'Last seen yesterday at $fromDateTime';
    }
    String month = _getMonth(time);
    return 'Last seen on ${time.day} $month on $fromDateTime';
  }
}