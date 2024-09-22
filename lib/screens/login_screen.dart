import 'package:flash_chat_app/screens/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/components/rounded_button.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_chat_app/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  static const String id = 'login_screen';
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool showSpinner = false;
  late String email;
  late String password;
  User? loggedInUser;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamed(context, RegistrationScreen.id); // Navigate back to the previous screen
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flexible(
                child: Hero(
                  tag: 'logo',
                  child: Container(
                    height: 200.0,
                    child: Image.asset('images/logo.png'),
                  ),
                ),
              ),
              const SizedBox(
                height: 48.0,
              ),
              TextField(
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  email = value;
                },
                decoration:
                kTextFieldDecoration.copyWith(hintText: 'Enter your Email'),
              ),
              const SizedBox(
                height: 8.0,
              ),
              TextField(
                obscureText: true,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  password = value;
                },
                decoration:
                kTextFieldDecoration.copyWith(hintText: 'Enter Password'),
              ),
              const SizedBox(
                height: 24.0,
              ),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14.0,
                ),
              ),
              SizedBox(
                height: 24.0,
              ),
              RoundedButton(
                color: Colors.lightBlueAccent,
                title: 'LOGIN',
                onPressed: () async {
                  await loginUser();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> loginUser() async {
    try {
      setState(() {
        showSpinner = true;
        errorMessage = ''; // Clear previous error message
      });

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      loggedInUser = userCredential.user;

      if (loggedInUser != null) {
        List<String> userGroups = await getUserGroups();
        Navigator.pushNamed(context, HomeScreen.id, arguments: userGroups);
      } else {
        print('User not logged in.');
      }
    } catch (e) {
      print('Login error: $e');
      setState(() {
        errorMessage = 'Invalid email or password. Please try again.';
      });
    } finally {
      setState(() {
        showSpinner = false;
      });
    }
  }

  Future<List<String>> getUserGroups() async {
    try {
      if (loggedInUser == null) {
        print('No user is currently logged in....');
        return [];
      }

      String userEmail = loggedInUser!.email!;

      QuerySnapshot groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userEmail)
          .get();

      if (groupsSnapshot.docs.isNotEmpty) {
        List<String> userGroups =
        groupsSnapshot.docs.map((doc) => doc.id).toList();
        print('User is in groups: $userGroups');
        return userGroups;
      } else {
        print('No groups found for the user.');
        return [];
      }
    } catch (e) {
      print('Error fetching user groups: $e');
      return [];
    }
  }
}