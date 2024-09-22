
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_chat_app/screens/individual_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash_chat_app/screens/group_chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  static String id = 'groups_screen';

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  Map<String, String> userGroups = {};
  List<Map<String, String>> allUsers = [];
  List<Map<String, dynamic>> combinedList = [];
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  bool _isCreatingGroup = false;
  bool _isSearching = false;
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    getUserDetails();
    getAllUsers();
  }

  Future<void> getUserDetails() async {
    try {
      final loggedInUser = _auth.currentUser;
      if (loggedInUser == null) {
        print('No user is currently logged in.');
        return;
      }
      await getUserGroups();
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  Future<void> getUserGroups() async {
    try {
      final loggedInUser = _auth.currentUser;
      if (loggedInUser == null) return;

      String userEmail = loggedInUser.email!;
      QuerySnapshot groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userEmail)
          .get();

      if (groupsSnapshot.docs.isNotEmpty) {
        Map<String, String> groupMap = {};
        for (var doc in groupsSnapshot.docs) {
          String groupId = doc.id;
          String groupName = doc['name'] ?? 'Unnamed Group';
          groupMap[groupId] = groupName;
        }
        setState(() {
          userGroups = groupMap;
          _updateCombinedList();
        });
      } else {
        setState(() {
          userGroups = {};
          _updateCombinedList();
        });
      }
    } catch (e) {
      print('Error fetching user groups: $e');
    }
  }

  Future<void> createGroup(String groupName) async {
    try {
      final loggedInUser = _auth.currentUser;
      if (loggedInUser == null) return;

      if (groupName.isEmpty) {
        print('Group name cannot be empty.');
        return;
      }

      String userEmail = loggedInUser.email!;
      DocumentReference newGroupRef = _firestore.collection('groups').doc();
      await newGroupRef.set({
        'name': groupName,
        'members': [userEmail],
        'admin': userEmail,
        'lastActive': FieldValue.serverTimestamp(),
      });

      print('Group created successfully.');
      await getUserGroups();
      setState(() {
        _isCreatingGroup = false;
        _groupNameController.clear();
      });
    } catch (e) {
      print('Error creating group: $e');
    }
  }

  Future<void> getAllUsers() async {
    try {
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      if (usersSnapshot.docs.isNotEmpty) {
        List<Map<String, String>> userList = [];
        for (var doc in usersSnapshot.docs) {
          String displayName = doc['displayName'] ?? 'Unknown';
          String email = doc['email'] ?? 'No email';
          userList.add({'displayName': displayName, 'email': email});
        }
        setState(() {
          allUsers = userList;
          _updateCombinedList();
        });
      }
    } catch (e) {
      print('Error fetching all users: $e');
    }
  }



  Future<void> exitGroup(String groupId) async {
    try {
      final loggedInUser = _auth.currentUser;
      if (loggedInUser == null) return;

      String userEmail = loggedInUser.email!;
      DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(groupId).get();
      List<dynamic> members = groupDoc['members'];

      // Check if the user exiting is the admin
      if (groupDoc['admin'] == userEmail) {
        // Remove the user from the members
        members.remove(userEmail);

        // If there are remaining members, assign the first one as the new admin
        if (members.isNotEmpty) {
          String newAdminEmail = members[0];
          await _firestore.collection('groups').doc(groupId).update({
            'members': members,
            'admin': newAdminEmail,
            'lastActive': FieldValue.serverTimestamp(),
          });
          print('Admin exited group. New admin assigned: $newAdminEmail.');
        } else {
          // If no members are left, you may want to delete the group or handle accordingly
          await _firestore.collection('groups').doc(groupId).delete();
          print('Last admin exited group. Group deleted.');
        }
      } else {
        // If the user is not the admin, simply remove them
        await _firestore.collection('groups').doc(groupId).update({
          'members': FieldValue.arrayRemove([userEmail]),
          'lastActive': FieldValue.serverTimestamp(),
        });
        print('Exited group successfully.');
      }

      await getUserGroups();
    } catch (e) {
      print('Error exiting group: $e');
    }
  }


  Future<void> updateUserLastActive(String email) async {
    try {
      await _firestore.collection('users').doc(email).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
      print('User $email lastActive updated successfully.');
    } catch (e) {
      print('Error updating user lastActive for $email: $e');
    }
  }

  Future<void> updateGroupLastActive(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating group lastActive: $e');
    }
  }

  Future<void> _updateCombinedList() async {
    List<Map<String, dynamic>> groupsList = await Future.wait(userGroups.entries.map((e) async {
      DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(e.key).get();
      return {
        'type': 'group',
        'id': e.key,
        'name': e.value,
        'lastActive': groupDoc['lastActive'],
      };
    }));

    List<Map<String, dynamic>> usersList = await Future.wait(allUsers.map((e) async {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(e['email']).get();
      return {
        'type': 'user',
        'email': e['email']!,
        'name': e['displayName']!,
        'lastActive': userDoc['lastActive'],
      };
    }));

    // Combine and sort the lists based on lastActive timestamp
    List<Map<String, dynamic>> combined = [...groupsList, ...usersList];
    combined.sort((a, b) {
      DateTime aLastActive = (a['lastActive'] as Timestamp).toDate();
      DateTime bLastActive = (b['lastActive'] as Timestamp).toDate();
      return bLastActive.compareTo(aLastActive); // Descending order
    });

    setState(() {
      combinedList = combined;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredList = combinedList.where((item) {
      final name = item['name']?.toLowerCase() ?? '';
      final email = item['email']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey,
        title: Text(
          _isSearching ? 'Search Results' : 'Groups and Users',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isCreatingGroup)
            IconButton(
              icon: Icon(_isSearching ? Icons.clear : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                  _isSearching = !_isSearching;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Search',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(child: Text('No results found.'))
                      : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isGroup = item['type'] == 'group';
                      final itemName = item['name'] ?? '';
                      final itemEmail = item['email'] ?? '';
                      final itemId = item['id'] ?? '';

                      return ListTile(
                        leading: Icon(isGroup ? Icons.group : Icons.person),
                        title: Text(itemName),
                        subtitle: isGroup ? null : Text(itemEmail),
                        onTap: () {
                          if (isGroup) {
                            updateGroupLastActive(itemId); // Update group lastActive on tap
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(groupId: itemId),
                              ),
                            );
                          } else {
                            updateUserLastActive(itemEmail); // Update chosen user's lastActive on tap
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IndividualChatScreen(chatUserEmail: itemEmail),
                              ),
                            );
                          }
                        },
                        trailing: isGroup
                            ? IconButton(
                          icon: Icon(Icons.exit_to_app),
                          onPressed: () {
                            exitGroup(itemId);
                          },
                        )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isCreatingGroup)
            Positioned(
              bottom: 16.0,
              right: 16.0,
              child: Container(
                width: 300,
                child: Card(
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _groupNameController,
                          decoration: InputDecoration(
                            labelText: 'Enter group name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: () {
                            final groupName = _groupNameController.text.trim();
                            if (groupName.isNotEmpty) {
                              createGroup(groupName);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                          ),
                          child: Text(
                            'Create Group',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isCreatingGroup = false;
                              _groupNameController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              backgroundColor: Colors.green,
              onPressed: () {
                setState(() {
                  _isCreatingGroup = true;
                });
              },
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.chat_bubble, color: Colors.white),
                  ),
                  Center(
                    child: Icon(Icons.add, color: Colors.green, size: 18.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

