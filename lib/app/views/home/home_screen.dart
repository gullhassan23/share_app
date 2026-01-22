import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
import 'package:share_app_latest/components/custom_button.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ClipPath(
            clipper: CurvedBackground(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              color: const Color(0xFF5DADE2),
              child: CustomPaint(painter: BackgroundEllipses()),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                /// TOP BAR
                const SizedBox(height: 20),

                /// TITLE
                const SizedBox(height: 98),

                /// WHITE CARD / CONTAINER
                Container(
                  margin: const EdgeInsets.only(top: 80, left: 12, right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/icons/global.png"),
                      fit: BoxFit.contain, // Scale down to fit within container
                      alignment:
                          Alignment.centerRight, // Show image on the right
                    ),
                    color: Color(0xff3D88FC),
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
                          child: Image.asset(
                            "assets/icons/galleryimage.png",
                            height: 10,
                            width: 10,
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      Text(
                        "Transfer Your Data",
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "TRANSFER ALL YOUR DATA IN ONE TAP. SECURE, FAST AND RELIABLE MIGRATION.",
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),

                /// DESCRIPTION
                const SizedBox(height: 60),

                /// BUTTON
                Custombutton(
                  textColor: Colors.white,
                  colors: [Color(0xff04E0FF), Color(0xff6868FF)],
                  text: "start pairing",
                  ontap: () {
                   AppNavigator.toPairing();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
