import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/contant_container.dart';
import '../../../models/device_info.dart';

class ChooseFileScreen extends StatelessWidget {
  const ChooseFileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DeviceInfo device = Get.arguments as DeviceInfo;
    print("device infor ${device.ip}");
    print("device infor ${device.name}");
    print("device infor ${device.transferPort}");
    print("device infor ${device.wsPort}");
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Mode Selection"),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Device name input and controls
            Text(
              'Connected to ${device.name ?? ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),

            // Mode selection buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ContanstContainer(
                  ontap: () {
                    print('🔘 Send button clicked');
                    Get.back(result: {'device': device, 'isSender': true});
                  },
                  bgcolor: Color(0xff3D88FC),
                  icon: "assets/icons/galleryimage.png",
                  title: "SEND",
                  subtitle: "SEND FILES FAST AND SECURE",
                ),
                ContanstContainer(
                  ontap: () {
                    print('🔘 Receive button clicked');
                    Get.back(result: {'device': device, 'isSender': false});
                  },
                  bgcolor: Color(0xff00E5FF),
                  icon: "assets/icons/galleryimage.png",
                  title: "RECIEVE",
                  subtitle: "RECIEVE FILES SAFELY AND INSTANTLY",
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Choose whether you want to send files to this device or receive files from it.",
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: Color(0xff72777F)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
