import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ContanstContainer extends StatelessWidget {
  final Color bgcolor;
  final String icon;
  final VoidCallback ontap;
  final String title;
  final String subtitle;
  ContanstContainer({
    Key? key,
    required this.bgcolor,
    required this.icon,
    required this.ontap,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        margin: const EdgeInsets.only(top: 80, left: 12, right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/icons/global.png"),
            fit: BoxFit.contain, // Scale down to fit within container
            alignment: Alignment.topRight, // Show image on the right
          ),
          color: bgcolor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(icon, height: 10, width: 10),
              ),
            ),
            SizedBox(height: 30),
            Text(
              title,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 10),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
