
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flash_chat_app/components/rounded_button.dart';
import 'package:flash_chat_app/screens/registration_screen.dart';
import 'package:flash_chat_app/screens/login_screen.dart';
import 'package:flash_chat_app/screens/group_chat_screen.dart';

class WelcomeScreen extends StatefulWidget {
  static const String id = 'welcome_screen';
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation animation;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    controller = AnimationController(
      duration: Duration(seconds: 5),
      vsync: this,
    );

    //animation = CurvedAnimation(parent: controller, curve: Curves.easeIn);
    animation =
        ColorTween(begin: Colors.green, end: Colors.red).animate(controller);
    controller.forward();
    animation.addStatusListener((status) {
      print(status);
    });
    controller.addListener(() {
      setState(() {});
      print(animation.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: animation.value,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Hero(
                  tag: 'logo',
                  child: Container(
                    child: Image.asset('images/logo.png'),
                    height: 60.0,
                  ),
                ),
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'Flash Chat',
                      textStyle: const TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                      ),
                      speed: const Duration(milliseconds: 2000),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(
              height: 48.0,
            ),
            RoundedButton(
              color: Colors.lightBlueAccent,
              title: 'LOGIN',
              onPressed: () {
                //Go to login screen.
                Navigator.pushNamed(context, LoginScreen.id);
              },
            ),
            RoundedButton(
              color: Colors.lightBlueAccent,
              title: 'REGISTER',
              onPressed: () {
                //Go to login screen.
                Navigator.pushNamed(context, RegistrationScreen.id);
              },
            ),


          ],
        ),
      ),
    );
  }
}
