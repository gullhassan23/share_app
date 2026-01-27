import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:share_app_latest/app/views/home/choose_file/choose_file_screen.dart';
import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
import 'package:share_app_latest/components/custom_upload_bar.dart';

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

  final transfer = Get.put(TransferController());
  final pairing = Get.put(PairingController());
  final progress = Get.put(ProgressController());
  Worker? _transferCompleteWorker;
  bool _didAutoNavigate = false;

  @override
  void initState() {
    super.initState();
    device = Get.arguments as DeviceInfo;

    // Auto-close this screen as soon as the upload completes successfully.
    // This does NOT change transfer logic; it only reacts to existing progress signals.
    // _transferCompleteWorker = ever<double>(progress.sendProgress, (value) {
    //   if (_didAutoNavigate) return;

    //   final isDone = value >= 1.0;
    //   final isSuccess = progress.status.value == 'sent';
    //   final hasError = progress.error.value.isNotEmpty;

    //   if (isDone && isSuccess && !hasError) {
    //     _didAutoNavigate = true;
    //     // Navigate to the "next" screen by popping this transfer screen if possible.
    //     // Fallback to home if it can't pop.
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //       if (!mounted) return;
    //       if (Get.key.currentState?.canPop() ?? false) {
    //         Get.back();
    //       } else {
    //         AppNavigator.toHome();
    //       }
    //     });
    //   }
    // });

    _transferCompleteWorker = ever<String>(progress.status, (status) {
      if (_didAutoNavigate) return;

      final isSuccess = status == 'sent';
      final hasError = progress.error.value.isNotEmpty;

      if (isSuccess && !hasError) {
        _didAutoNavigate = true;

        // 🎉 Print + UI feedback
        print("✅ File successfully sent to receiver!");
        Get.snackbar(
          "Transfer Completed",
          "Your file transfer successfully 🎉",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        Get.to(() => ChooseFileScreen());
        // Auto-navigate back after showing success message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Get.key.currentState?.canPop() == true) {
            Get.back();
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

  void _showFileTypeSelection() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select File Type',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose what type of files you want to send',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.android,
                      label: 'APK',
                      color: Colors.green,
                      onTap: () => _pickFileWithType(FileType.custom, ['apk']),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.video_library,
                      label: 'Videos',
                      color: Colors.red,
                      onTap: () => _pickFileWithType(FileType.video, null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.photo_library,
                      label: 'Photos',
                      color: Colors.blue,
                      onTap: () => _pickFileWithType(FileType.image, null),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.insert_drive_file,
                      label: 'Files',
                      color: Colors.orange,
                      onTap: () => _pickFileWithType(FileType.any, null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _pickFileWithType(
    FileType type,
    List<String>? allowedExtensions,
  ) async {
    Get.back(); // Close the file type selection dialog

    try {
      // Use TransferController to select file
      final selectedPath = await transfer.selectFile(
        type: type,
        allowedExtensions: allowedExtensions,
      );

      if (selectedPath != null) {
        // Now initiate the transfer with the selected file
        await _sendSelectedFile(selectedPath);
      }
    } catch (e) {
      print('❌ File picker error: $e');
      Get.snackbar('File Picker Error', e.toString());
    }
  }

  Future<void> _sendSelectedFile(String path) async {
    try {
      // Create file metadata
      final file = File(path);
      final meta = FileMeta(
        name: path.split('/').last,
        size: await file.length(),
        type: _extType(path),
      );

      // Send offer first
      final pairing = Get.find<PairingController>();
      final accepted = await pairing.sendOffer(device, meta);

      if (accepted) {
        print('✅ Offer accepted! Starting file transfer...');
        // Transfer the file
        await transfer.sendFile(
          path,
          device.ip ?? "",
          device.transferPort,
        );
      } else {
        print('❌ Offer was rejected or timed out');
        Get.snackbar(
          'Transfer Failed',
          'The receiving device did not accept the transfer or timed out',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('❌ Error sending file: $e');
      Get.snackbar(
        'Transfer Failed',
        e.toString(),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Widget _buildFileTypeContainer({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.apk') return 'apk';
    if (ext == '.mp4' || ext == '.mov') return 'video';
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return 'image';
    return 'file';
  }

  Future<void> pickAndSendFile() async {
    try {
      // Use TransferController to handle the complete file transfer flow
      await transfer.initiateFileTransfer(device);
    } catch (e) {
      print('❌ File transfer failed: $e');
      Get.snackbar(
        'Transfer Failed',
        e.toString(),
        duration: const Duration(seconds: 3),
      );
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
                          onPressed: _showFileTypeSelection,
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
