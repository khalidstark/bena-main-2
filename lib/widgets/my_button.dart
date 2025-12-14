
import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String text;
  final Color buttoncolor;
  final Color textColo;
  final void Function() onTap;

  const MyButton({super.key,
   required this.text, 
   required this.buttoncolor, 
   required this.textColo,
   required this.onTap,
   });

  @override
  Widget build(BuildContext context) {
    return Container(
                width: MediaQuery.of(context).size.width,
                height: 55,
                decoration:  BoxDecoration(
                  color: buttoncolor,
                  borderRadius: BorderRadius.all(Radius.circular(8))),
                  child : MaterialButton(
                    onPressed: onTap,
                    child:  Center(
                    child: Text(
                      text, 
                    style: TextStyle(
                      fontSize: 18,
                      color: textColo,
                      fontWeight: FontWeight.bold,
                    ),
                    ),
                  ),
                  ),                          
              );
  }
}
