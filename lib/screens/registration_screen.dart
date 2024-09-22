import 'package:flash_chat_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/components/rounded_button.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

class RegistrationScreen extends StatefulWidget {
  static const String id = 'registration_screen';

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // Initialize Firestore
  bool showSpinner = false;
  late String email;
  late String password;
  late String displayName; // Add a variable for the user name

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Register'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the Login screen
          },
        ),
      ),
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
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
              SizedBox(
                height: 48.0,
              ),
              TextField(
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  email = value;
                },
                decoration: kTextFieldDecoration.copyWith(hintText: 'Enter your Email'),
              ),
              SizedBox(
                height: 8.0,
              ),
              TextField(
                textAlign: TextAlign.center,
                onChanged: (value) {
                  displayName = value; // Store user name input
                },
                decoration: kTextFieldDecoration.copyWith(hintText: 'Enter your Name'),
              ),
              SizedBox(
                height: 8.0,
              ),
              TextField(
                obscureText: true,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  password = value;
                },
                decoration: kTextFieldDecoration.copyWith(hintText: 'Enter Password'),
              ),
              SizedBox(
                height: 24.0,
              ),
              RoundedButton(
                color: Colors.lightBlueAccent,
                title: 'REGISTER',
                onPressed: () async {
                  setState(() {
                    showSpinner = true;
                  });
                  try {
                    final newUser = await _auth.createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                    if (newUser != null) {
                      // Store user data in Firestore
                      await _firestore.collection('users').doc(email).set({
                        'email': email,
                        'displayName': displayName, // Add user name to Firestore
                        'lastActive': FieldValue.serverTimestamp(),
                      });
                      print('User registered and document created.');
                      Navigator.pushNamed(context, LoginScreen.id);
                    }
                    setState(() {
                      showSpinner = false;
                    });
                  } catch (e) {
                    print(e);
                    setState(() {
                      showSpinner = false;
                    });
                  }
                },
              ),
              SizedBox(height: 16.0), // Add some spacing
              Center( // Center the Row
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Center the Row content
                  children: [
                    Text('Already Registered? ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, LoginScreen.id); // Navigate to Login screen
                      },
                      child: Text(
                        ' Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

