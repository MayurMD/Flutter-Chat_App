
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash_chat_app/constants.dart';


final FirebaseFirestore _firestore = FirebaseFirestore.instance;
User? loggedInUser;

class ChatScreen extends StatefulWidget {
  static String id = 'chat_screen';
  final String groupId;

  ChatScreen({required this.groupId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageTextController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String messageText;
  String groupName = '';
  String groupAdminEmail = '';

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    getGroupName();
  }

  void getCurrentUser() {
    try {
      final User? user = _auth.currentUser;

      if (user != null) {
        setState(() {
          loggedInUser = user;
        });
        print(loggedInUser?.email ?? 'No email available');
      } else {
        print('No user is currently logged in.');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void getGroupName() async {
    try {
      DocumentSnapshot groupSnapshot =
      await _firestore.collection('groups').doc(widget.groupId).get();

      if (groupSnapshot.exists) {
        setState(() {
          groupName = groupSnapshot['name'] ?? 'Group Chat';
          groupAdminEmail = groupSnapshot['admin'] ?? '';
        });
      } else {
        print('Group not found');
      }
    } catch (e) {
      print('Error getting group name: $e');
    }
  }

  void _addMember(String mailId) async {
    try {
      // Reference to the group's document
      final groupDocRef = _firestore.collection('groups').doc(widget.groupId);

      // Fetch the current group document
      final groupDocSnapshot = await groupDocRef.get();

      if (groupDocSnapshot.exists) {
        // Get the current members list, if any
        List<dynamic> currentMembers =
            groupDocSnapshot.data()?['members'] ?? [];

        // Add the new member if not already present
        if (!currentMembers.contains(mailId)) {
          currentMembers.add(mailId);

          // Update the group's document with the new members list
          await groupDocRef.update({'members': currentMembers});
          print('Member added successfully');
        } else {
          print('Member already exists');
        }
      } else {
        print('Group does not exist');
      }
    } catch (e) {
      print('Error adding member: $e');
    }
  }

  Future<String?> _showAddMemberDialog(BuildContext context) async {
    final TextEditingController _controller = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Member',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: 'Enter user email'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                final emailRegex = RegExp(
                  r'^[^@]+@[^@]+\.[^@]+$',
                );
                if (!emailRegex.hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[

            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, _controller.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: Text(
                'Add',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 20.0),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: null,
        actions: <Widget>[
          if (loggedInUser?.email ==
              groupAdminEmail) // Only show if current user is the admin
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () async {
                var userMail = await _showAddMemberDialog(context);
                if (userMail != null) {
                  _addMember(userMail);
                }
              },
            ),
        ],
        title: Row(
          children: [
            Icon(Icons.group), // Replace with your desired icon
            SizedBox(width: 8), // Space between icon and text
            Text(' $groupName'),
          ],
        ),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MessageStream(groupId: widget.groupId),
            Container(
              decoration: kMessageContainerDecoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: messageTextController,
                      onChanged: (value) {
                        messageText = value;
                      },
                      decoration: kMessageTextFieldDecoration,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (messageText.isNotEmpty) {
                        try {
                          messageTextController.clear();
                          await _firestore.collection('messages').add({
                            'text': messageText,
                            'sender': loggedInUser?.email,
                            'timestamp': FieldValue.serverTimestamp(),
                            'groupId': widget.groupId,
                          });
                          setState(() {
                            messageText = '';
                          });
                        } catch (e) {
                          print('Error adding document: $e');
                        }
                      } else {
                        print('Message text is empty');
                      }
                    },
                    child: Text(
                      'Send',
                      style: kSendButtonTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageStream extends StatelessWidget {
  final String groupId;

  MessageStream({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('messages')
          .where('groupId', isEqualTo: groupId)
          .orderBy('timestamp', descending: false) // Order by timestamp
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              backgroundColor: Colors.lightBlueAccent,
            ),
          );
        } else {
          final messages = snapshot.data!.docs.reversed;
          List<MessageBubble> messageBubbles = [];
          final currentUser = loggedInUser?.email;

          for (var message in messages) {
            final messageText = message.get('text') as String?;
            final messageSender = message.get('sender') as String?;

            if (messageText == null || messageSender == null) {
              continue;
            }

            final messageWidget = MessageBubble(
              sender: messageSender,
              text: messageText,
              isMe: currentUser == messageSender,
            );

            messageBubbles.add(messageWidget);
          }

          return Expanded(
            child: ListView(
              reverse: true,
              padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
              children: messageBubbles,
            ),
          );
        }
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final bool isMe;

  MessageBubble({required this.sender, required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sender,
            style: const TextStyle(color: Colors.black54, fontSize: 12.0),
          ),
          Material(
            borderRadius: isMe
                ? const BorderRadius.only(
              bottomLeft: Radius.circular(15.0),
              bottomRight: Radius.circular(15.0),
              topLeft: Radius.circular(15.0),
            )
                : const BorderRadius.only(
              bottomLeft: Radius.circular(15.0),
              bottomRight: Radius.circular(15.0),
              topRight: Radius.circular(15.0),
            ),
            elevation: 5.0,
            color: isMe ? Colors.lightBlueAccent : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15.0,
                  color: isMe ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
