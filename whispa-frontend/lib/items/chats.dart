import 'package:flutter/material.dart';

class Chats extends StatelessWidget {
  const Chats({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage("https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEibQ9rfXlUqQ_MxIjF60ljbnF_THtEZ_qOSOpwfavE6z3k-g2Fuye8MUp2kD6XbVyb8tpNTE6YQjSfoAuSxpHGu4sMqpmA4TrI8QVLcU9-2gSfZc0t1bXBeOBleizYisD4EvRLQ36a3ArY/s640/06_hbna50203681_021_10.jpeg"),
          ),
          SizedBox(width: 20,),
          Column(
            children: [
              Text("Cipher_nomad",
              style: TextStyle(
                color: Colors.white
              ),),
              Text("How are u?",
              style: TextStyle(
                color: Colors.white
              ),),
            ],),
            SizedBox(width: 140,),
          Column(
            children: [
              Text("19:30",
              style: TextStyle(
                color: Colors.white
              ),),
              Icon(Icons.star),
            ],),
      
      
        ],
      ),
    );
  }
}