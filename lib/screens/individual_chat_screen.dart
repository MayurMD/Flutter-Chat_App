
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../constants.dart';

class IndividualChatScreen extends StatefulWidget {
  final String chatUserEmail; // Add this to pass the email of the chat user

  const IndividualChatScreen({super.key, required this.chatUserEmail});

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  final TextEditingController _controller = TextEditingController();
  late String currentUserEmail;
  late String chatUserEmail;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    currentUserEmail = _auth.currentUser!.email!;
    chatUserEmail = widget.chatUserEmail;
  }

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      await _firestore.collection('messages').add({
        'sender': currentUserEmail,
        'receiver': chatUserEmail,
        'message': _controller.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getMessagesStream() {
    final userMessagesStream = _firestore
        .collection('messages')
        .where('sender', isEqualTo: currentUserEmail)
        .where('receiver', isEqualTo: chatUserEmail)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    final chatMessagesStream = _firestore
        .collection('messages')
        .where('sender', isEqualTo: chatUserEmail)
        .where('receiver', isEqualTo: currentUserEmail)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    return Rx.combineLatest2(
      userMessagesStream,
      chatMessagesStream,
          (List<QueryDocumentSnapshot<Map<String, dynamic>>> userMessages,
          List<QueryDocumentSnapshot<Map<String, dynamic>>> chatMessages) {
        final allMessages = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        allMessages.addAll(userMessages);
        allMessages.addAll(chatMessages);
        allMessages.sort((a, b) {
          final timestampA = (a.data()['timestamp'] as Timestamp).toDate();
          final timestampB = (b.data()['timestamp'] as Timestamp).toDate();
          return timestampA.compareTo(timestampB);
        });
        return allMessages;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        title: Text('Chat with $chatUserEmail'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: getMessagesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages found.'));
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data();
                    final messageText = message['message'] ?? 'No message';
                    final messageSender = message['sender'] ?? 'Unknown sender';
                    final isCurrentUser = messageSender == currentUserEmail;

                    return ChatBubble(
                      message: messageText,
                      isMe: isCurrentUser,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:kMessageTextFieldDecoration,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: isMe ? Colors.lightBlueAccent : Colors.grey[300],
            borderRadius: isMe
                ? const BorderRadius.only(
              bottomLeft:  Radius.circular(15.0),
              bottomRight:  Radius.circular(15.0),
              topLeft:  Radius.circular(15.0),
            )
                : const BorderRadius.only(
              bottomLeft:  Radius.circular(15.0),
              bottomRight: Radius.circular(15.0),
              topRight:  Radius.circular(15.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          child: Text(
            message,
            style: TextStyle(fontSize: 16.0,
              color: isMe ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

