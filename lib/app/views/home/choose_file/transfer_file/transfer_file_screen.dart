// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
// import 'dart:io';
// import '../../../../controllers/progress_controller.dart';
// import '../../../../controllers/transfer_controller.dart';
// import '../../../../models/device_info.dart';
// import '../../../../controllers/pairing_controller.dart';
// import '../../../../models/file_meta.dart';

// class TransferFileScreen extends StatefulWidget {
//   const TransferFileScreen({super.key});
//   @override
//   State<TransferFileScreen> createState() => _TransferFileScreenState();
// }

// class _TransferFileScreenState extends State<TransferFileScreen> {
//   late final DeviceInfo device;

//   final transfer = Get.find<TransferController>();
//   final progress = Get.find<ProgressController>();
//   final pairing = Get.find<PairingController>();

//   final isInitializingTransfer = false.obs;

//   @override
//   void initState() {
//     super.initState();
//     device = Get.arguments as DeviceInfo; // ✅ correct place
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Transfer')),
//       body: Stack(
//         children: [
//           ClipPath(
//             clipper: CurvedBackground(),
//             child: Container(
//               height: MediaQuery.of(context).size.height * 0.45,
//               width: double.infinity,
//               color: const Color(0xFF5DADE2),
//               child: CustomPaint(painter: BackgroundEllipses()),
//             ),
//           ),

//           SafeArea(
//             child: Column(
//               children: [
//                 SizedBox(height: 100),
//                 Container(
//                   margin: const EdgeInsets.only(top: 80, left: 12, right: 12),
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     image: DecorationImage(
//                       image: AssetImage("assets/icons/global.png"),
//                       fit: BoxFit.contain, // Scale down to fit within container
//                       alignment:
//                           Alignment.centerRight, // Show image on the right
//                     ),
//                     color: Color(0xff3D88FC),
//                     borderRadius: BorderRadius.circular(16),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.08),
//                         blurRadius: 20,
//                         offset: const Offset(0, 10),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         height: 50,
//                         width: 50,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(50),
//                           color: Colors.white,
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Image.asset(
//                             "assets/icons/galleryimage.png",
//                             height: 10,
//                             width: 10,
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: 30),
//                       Text(
//                         "Transfer Your Data",
//                         style: GoogleFonts.roboto(
//                           color: Colors.white,
//                           fontSize: 30,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         "TRANSFER ALL YOUR DATA IN ONE TAP. SECURE, FAST AND RELIABLE MIGRATION.",
//                         style: GoogleFonts.roboto(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                       ),
//                       SizedBox(height: 30),
//                     ],
//                   ),
//                 ),

//                 Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     children: [
//                       ElevatedButton(
//                         onPressed: () async {
//                           final result = await FilePicker.platform.pickFiles(
//                             withReadStream: true,
//                           );
//                           if (result != null && result.files.isNotEmpty) {
//                             final path = result.files.first.path;
//                             if (path != null) {
//                               final f = FileMeta(
//                                 name: path.split('/').last,
//                                 size: await File(path).length(),
//                                 type: '',
//                               );
//                               final accepted = await pairing.sendOffer(
//                                 device,
//                                 f,
//                               );
//                               if (accepted) {
//                                 await transfer.sendFile(
//                                   path,
//                                   device.ip,
//                                   device.transferPort,
//                                 );
//                               } else {
//                                 Get.snackbar(
//                                   'Offer rejected',
//                                   'Receiver declined',
//                                 );
//                               }
//                             }
//                           }
//                         },
//                         child: const Text('Select File'),
//                       ),
//                       const SizedBox(height: 16),
//                       Obx(
//                         () => Column(
//                           children: [
//                             if (progress.status.value.isEmpty &&
//                                 progress.error.value.isEmpty)
//                               Column(
//                                 children: [
//                                   const CircularProgressIndicator(),
//                                   const SizedBox(height: 16),
//                                   const Text(
//                                     'Waiting for receiver to accept...',
//                                     textAlign: TextAlign.center,
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     'File: ${device.name}',
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ],
//                               )
//                             else
//                               Column(
//                                 children: [
//                                   LinearProgressIndicator(
//                                     value: progress.sendProgress.value,
//                                   ),
//                                   const SizedBox(height: 8),
//                                   LinearProgressIndicator(
//                                     value: progress.receiveProgress.value,
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(progress.status.value),
//                                   Text(
//                                     progress.error.value,
//                                     style: const TextStyle(color: Colors.red),
//                                   ),
//                                 ],
//                               ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
import 'package:share_app_latest/components/custom_upload_bar.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

import '../../../../controllers/progress_controller.dart';
import '../../../../controllers/transfer_controller.dart';
import '../../../../controllers/pairing_controller.dart';
import '../../../../models/device_info.dart';
import '../../../../models/file_meta.dart';

class TransferFileScreen extends StatefulWidget {
  const TransferFileScreen({super.key});

  @override
  State<TransferFileScreen> createState() => _TransferFileScreenState();
}

class _TransferFileScreenState extends State<TransferFileScreen> {
  late final DeviceInfo device;

  final transfer = Get.find<TransferController>();
  final progress = Get.find<ProgressController>();
  final pairing = Get.find<PairingController>();
  Worker? _transferCompleteWorker;
  bool _didAutoNavigate = false;

  @override
  void initState() {
    super.initState();
    device = Get.arguments as DeviceInfo;

    // Auto-close this screen as soon as the upload completes successfully.
    // This does NOT change transfer logic; it only reacts to existing progress signals.
    _transferCompleteWorker = ever<double>(progress.sendProgress, (value) {
      if (_didAutoNavigate) return;

      final isDone = value >= 1.0;
      final isSuccess = progress.status.value == 'sent';
      final hasError = progress.error.value.isNotEmpty;

      if (isDone && isSuccess && !hasError) {
        _didAutoNavigate = true;
        // Navigate to the "next" screen by popping this transfer screen if possible.
        // Fallback to home if it can't pop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Get.key.currentState?.canPop() ?? false) {
            Get.back();
          } else {
            AppNavigator.toHome();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _transferCompleteWorker?.dispose();
    super.dispose();
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(withReadStream: true);
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final f = FileMeta(
          name: path.split('/').last,
          size: await File(path).length(),
          type: '',
        );

        final accepted = await pairing.sendOffer(device, f);

        if (accepted) {
          await transfer.sendFile(path, device.ip, device.transferPort);
        } else {
          Get.snackbar('Offer rejected', 'Receiver declined');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background curve
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
                const SizedBox(height: 100),

                /// Top Info Card
                Container(
                  margin: const EdgeInsets.only(top: 80, left: 12, right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage("assets/icons/global.png"),
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                    color: Colors.white,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                          child: Image.asset("assets/icons/cloud_image.png"),
                        ),
                      ),
                      Container(
                        height: 100,
                        width: 180,
                        child: Padding(
                          padding: const EdgeInsets.all(1.0),
                          child: Image.asset("assets/icons/document_image.png"),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "UPLOADING DATA....",
                        style: GoogleFonts.roboto(
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "PLEASE KEEP THIS SCREEN OPEN",
                        style: GoogleFonts.roboto(
                          color: Colors.blue,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                /// Main Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      /// Select File Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: pickAndSendFile,
                          child: const Text('Select File'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// Upload Progress Section
                      Obx(() {
                        if (progress.status.value.isEmpty &&
                            progress.error.value.isEmpty) {
                          return Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                'Waiting for receiver to accept...',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Device: ${device.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            /// Custom Upload Bar
                            CustomUploadProgress(
                              progress: progress.sendProgress.value,
                              sentMB: progress.sentMB.value,
                              totalMB: progress.totalMB.value,
                              speedMBps: progress.speedMBps.value,
                            ),

                            const SizedBox(height: 16),

                            /// Cancel Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2F3944),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: () {
                                  // transfer.cancelTransfer();
                                },
                                child: const Text(
                                  "CANCEL UPLOAD",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),

                            if (progress.error.value.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  progress.error.value,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
