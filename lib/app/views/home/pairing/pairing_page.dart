import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import '../../../controllers/pairing_controller.dart';
import '../../../controllers/transfer_controller.dart';
import '../../../models/file_meta.dart';
import '../../../models/device_info.dart';
import '../../../../components/radar.dart';
import 'dart:math' as math;
import '../../../controllers/bluetooth_controller.dart';
import 'dart:io';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with TickerProviderStateMixin {
  final pairing = Get.put(PairingController());
  final transfer = Get.put(TransferController());
  final bluetooth = Get.put(BluetoothController());
  final nameCtrl = TextEditingController(text: 'Device');
  late AnimationController _radarCtrl;

  bool? _selectedMode; // null = not selected, true = sender, false = receiver
  DeviceInfo? _pairedDevice; // null = not paired, DeviceInfo = paired device
  bool _fileDialogShown =
      false; // Track if file selection dialog has been shown for sender mode
  bool _offerDialogShown = false; // Track if offer dialog is currently showing

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _askPermissions();

    // Start device discovery immediately with actual device name
    pairing.startServer();
    pairing.discover();
  }

  void _pairWithDevice(DeviceInfo device) async {
    setState(() {
      _pairedDevice = device;
      _fileDialogShown = false; // Reset dialog flag for new pairing
    });
    print(
      '✅ Paired with device: ${device.name} at ${device.ip}:${device.transferPort}',
    );

    // Start WebSocket server immediately after pairing (needed for both sender and receiver)
    pairing.startServer();

    // Navigate to mode selection page and wait for result
    print('🔄 Navigating to mode selection page');
    final result = await AppNavigator.toChooseFile(device: device);
    print('🔄 Returned from mode selection with result: $result');

    if (result != null) {
      print('✅ Mode selected: isSender = ${result['isSender']}');
      setState(() {
        _selectedMode = result['isSender'] as bool;
        _pairedDevice = result['device'] as DeviceInfo;
      });
      print(
        '✅ State updated: _selectedMode = $_selectedMode, _pairedDevice = ${_pairedDevice?.name}',
      );

      // Start transfer server only for receiver mode
      if (!_selectedMode!) {
        // Receiver mode
        print('📱 Receiver mode: Starting TCP server for file reception');
        transfer.startServer();
      } else {
        // Sender mode - directly open file selection dialog
        print('📤 Sender mode: Opening file selection dialog');
        _showFileTypeSelection();
      }
    }
  }

  void unpairDevice() {
    setState(() {
      _pairedDevice = null;
      _selectedMode = null;
      _fileDialogShown = false; // Reset dialog flag
    });
    print('🔄 Unpaired device');
  }

  Future<void> _askPermissions() async {
    await [
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showIncomingOfferDialog(Map<String, dynamic> offer) {
    // Prevent showing multiple dialogs
    if (_offerDialogShown) {
      print('⚠️ Offer dialog already showing, skipping...');
      return;
    }

    final ip = offer['fromIp'] as String;
    final meta = FileMeta.fromJson(offer['meta'] as Map<String, dynamic>);

    _offerDialogShown = true;
    Get.dialog(
      AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [Lottie.asset('assets/lottie/wifi.json')]),
            Text('From: ${_pairedDevice!.name}'),
            const SizedBox(height: 8),
            Text(
              'File: ${meta.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Size: ${_formatFileSize(meta.size)}'),
            const SizedBox(height: 16),
            const Text(
              'Do you want to accept this file?',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ User rejected file transfer from $ip');
              _offerDialogShown = false;
              pairing.respondToOffer(ip, false);
              Get.back();
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              print('✅ User accepted file transfer from $ip');
              _offerDialogShown = false;
              pairing.respondToOffer(ip, true);
              Get.back();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
      barrierDismissible: false, // Prevent dismissing by tapping outside
    );
  }

  void _showFileTypeSelection() {
    print('🔘 File selection button clicked');
    _showFileTypeSelectionForDevice(null);
  }

  void _showFileTypeSelectionForDevice(DeviceInfo? device) {
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
                      onTap: () {
                        print('🔘 APK file type selected');
                        _pickFileWithType(FileType.custom, ['apk'], device);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.video_library,
                      label: 'Videos',
                      color: Colors.red,
                      onTap: () {
                        print('🔘 Video file type selected');
                        _pickFileWithType(FileType.video, null, device);
                      },
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
                      onTap: () {
                        print('🔘 Image file type selected');
                        _pickFileWithType(FileType.image, null, device);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.insert_drive_file,
                      label: 'Files',
                      color: Colors.orange,
                      onTap: () {
                        print('🔘 Files file type selected');
                        _pickFileWithType(FileType.any, null, device);
                      },
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

  Future<void> _pickFileWithType(
    FileType type,
    List<String>? allowedExtensions, [
    DeviceInfo? device,
  ]) async {
    print(
      '📁 Opening file picker with type: $type, extensions: $allowedExtensions',
    );
    Get.back(); // Close the file type selection dialog

    FilePickerResult? result;
    try {
      if (type == FileType.custom && allowedExtensions != null) {
        result = await FilePicker.platform.pickFiles(
          type: type,
          allowedExtensions: allowedExtensions,
          withReadStream: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: type,
          withReadStream: true,
        );
      }

      print(
        '📁 File picker result: ${result != null ? 'Success' : 'Cancelled'}',
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        print('📁 Selected file path: $path');
        if (path != null) {
          await _sendSelectedFile(path, device);
        } else {
          print('❌ File path is null');
          Get.snackbar('Error', 'Selected file path is null');
        }
      } else {
        print('📁 No file selected or picker cancelled');
      }
    } catch (e) {
      print('❌ File picker error: $e');
      Get.snackbar('File Picker Error', 'Failed to open file picker: $e');
    }
  }

  Future<void> _sendSelectedFile(String path, [DeviceInfo? device]) async {
    final targetDevice = device ?? _pairedDevice!;
    final meta = FileMeta(
      name: path.split('/').last,
      size: await File(path).length(),
      type: '',
    );

    print('📤 Sending file offer to ${targetDevice.name}...');
    final accepted = await pairing.sendOffer(targetDevice, meta);

    if (accepted) {
      print('✅ Offer accepted! Starting file transfer...');
      print(
        '📋 Device info: ${targetDevice.name} at ${targetDevice.ip}:${targetDevice.transferPort}',
      );

      // Navigate to transfer page
      AppNavigator.toTransferFile(device: targetDevice);

      // Give receiver a moment to fully start their server
      await Future.delayed(const Duration(milliseconds: 300));

      print(
        '🚀 Starting file transfer to ${targetDevice.ip}:${targetDevice.transferPort}',
      );
      await transfer.sendFile(path, targetDevice.ip, targetDevice.transferPort);
    } else {
      print('❌ Offer was rejected or timed out');
      Get.snackbar(
        'Transfer Failed',
        'The receiving device did not accept the transfer or timed out',
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Global incoming offer detection - works regardless of current step
    // This allows receivers to get offers immediately after pairing
    return Stack(
      children: [
        // Main content
        _buildMainContent(),
        // Overlay for incoming offer dialog
        Obx(() {
          final offer = pairing.incomingOffer.value;
          if (offer != null) {
            // Show dialog when offer is received (regardless of pairing status)
            // The receiver can receive offers even before pairing if their server is running
            print('🎯 Incoming offer detected, showing dialog...');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              print('📱 Triggering offer dialog display');
              _showIncomingOfferDialog(offer);
            });
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildMainContent() {
    // Step 1: Device Discovery (if no device paired OR device paired but mode not selected)
    if (_pairedDevice == null || _selectedMode == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Pairing Screen"),
          automaticallyImplyLeading: true,
        ),
        resizeToAvoidBottomInset: true,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(height: 50),
              // Radar View
              Obx(() {
                final sweep = _radarCtrl.value * 2 * math.pi;
                // if (pairing.isScanning.value && !_radarCtrl.isAnimating)
                //   _radarCtrl.repeat();
                // if (!pairing.isScanning.value && _radarCtrl.isAnimating)
                //   _radarCtrl.stop();
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    RadarView(
                      size: 220,
                      devices: pairing.devices.toList(),
                      sweep: sweep,
                    ),
                    // Enhanced scanning animation overlay
                    AnimatedOpacity(
                      opacity: pairing.isScanning.value ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child:
                          pairing.isScanning.value
                              ? Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.green.withOpacity(0.1),
                                      Colors.green.withOpacity(0.05),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.7, 1.0],
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Pulsing rings animation
                                    ...List.generate(3, (index) {
                                      return AnimatedBuilder(
                                        animation: _radarCtrl,
                                        builder: (context, child) {
                                          final pulseProgress =
                                              (_radarCtrl.value * 2 +
                                                  index * 0.3) %
                                              1.0;
                                          final scale =
                                              0.5 + pulseProgress * 0.5;
                                          return Transform.scale(
                                            scale: scale,
                                            child: Container(
                                              width: 220,
                                              height: 220,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.green
                                                      .withOpacity(
                                                        (1.0 - pulseProgress) *
                                                            0.3,
                                                      ),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }),

                                    // Rotating radar sweep lines
                                    AnimatedBuilder(
                                      animation: _radarCtrl,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle: _radarCtrl.value * 2 * 3.14159,
                                          child: Container(
                                            width: 220,
                                            height: 220,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                            ),
                                            child: CustomPaint(
                                              painter: ScanningRadarPainter(
                                                devices:
                                                    pairing.devices.toList(),
                                                sweep: sweep,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Central pulsing dot
                                    AnimatedBuilder(
                                      animation: _radarCtrl,
                                      builder: (context, child) {
                                        final pulse =
                                            (math.sin(
                                                  _radarCtrl.value *
                                                      4 *
                                                      3.14159,
                                                ) +
                                                1) /
                                            2;
                                        return Container(
                                          width: 8 + pulse * 4,
                                          height: 8 + pulse * 4,
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(
                                                  0.6,
                                                ),
                                                blurRadius: pulse * 8,
                                                spreadRadius: pulse * 2,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),

                                    // Scanning text with fade effect
                                  ],
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 16),
              Obx(
                () => ElevatedButton(
                  onPressed: pairing.isScanning.value ? null : pairing.discover,
                  child:
                      pairing.isScanning.value
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Discovering...'),
                            ],
                          )
                          : const Text('Discover'),
                ),
              ),

              const SizedBox(height: 16),

              // Discovered devices list
              Expanded(
                child: Obx(
                  () =>
                      pairing.devices.isEmpty
                          ? const Center(
                            child: Text(
                              'No devices found.\nMake sure both devices are on the same Wi-Fi network.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                          : ListView.builder(
                            itemCount: pairing.devices.length,
                            itemBuilder: (context, index) {
                              final d = pairing.devices[index];
                              return Column(
                                children: [
                                  Dismissible(
                                    key: Key('device_${d.ip}_${index}'),
                                    direction: DismissDirection.startToEnd,
                                    background: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.only(right: 20),
                                      alignment: Alignment.centerRight,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) {
                                      // Remove the device from the list
                                      pairing.devices.removeAt(index);

                                      // If no devices left, restart discovery automatically
                                      if (pairing.devices.isEmpty) {
                                        pairing.discover();
                                      }

                                      // Show snackbar feedback
                                      Get.snackbar(
                                        'Device Removed',
                                        '${d.name} removed from list',
                                        duration: const Duration(seconds: 2),
                                      );
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.devices,
                                          color: Colors.deepPurple,
                                        ),
                                        title: Text(d.name),
                                        subtitle: Text(
                                          'Device • Ready to pair',
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () => _pairWithDevice(d),
                                          child: const Text('Pair'),
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: 20),
                                  Text(
                                    "Swipe left to right to reject the pairing request",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                ),
              ),

              // Bluetooth devices
              Obx(() {
                final list = bluetooth.devices.toList();
                final err = bluetooth.error.value;
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bluetooth nearby'),
                    if (err.isNotEmpty)
                      Text(err, style: const TextStyle(color: Colors.red)),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final d = list[i];
                        return ListTile(
                          title: Text(d.platformName),
                          subtitle: Text(d.remoteId.str),
                          trailing: ElevatedButton(
                            onPressed: () {
                              // For Bluetooth, we need to find the corresponding WiFi device
                              // This is simplified - in a real app you'd handle BT-only pairing
                              Get.snackbar(
                                'Bluetooth Pairing',
                                'Please use Wi-Fi pairing for file transfer',
                                duration: const Duration(seconds: 2),
                              );
                            },
                            child: const Text('Pair'),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    }

    // Transfer Interface (device paired AND mode selected)
    final isSender = _selectedMode!;

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

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Show server status for receiver

                // Show paired device info and transfer controls
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 16),
                        Text(
                          'Connected to ${_pairedDevice!.name}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pairedDevice!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 48),
                        if (isSender) ...[
                          // Automatically open file selection dialog for sender mode
                          Builder(
                            builder: (context) {
                              // Use addPostFrameCallback to open dialog after build is complete
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!_fileDialogShown) {
                                  _fileDialogShown = true;
                                  _showFileTypeSelection();
                                }
                              });
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.file_upload,
                                      color: Colors.blue,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Opening file selection...',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Choose the type of file you want to send',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ] else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: const Column(
                              children: [
                                SizedBox(height: 30),
                                Icon(Icons.wifi, color: Colors.green, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'Ready to receive files',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Show received files section for receiver mode
                if (!isSender) ...[
                  const SizedBox(height: 16),
                  Obx(() {
                    final files = transfer.receivedFiles;
                    if (files.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.folder, color: Colors.grey),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No received files yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.folder, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Received Files (${files.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ListView.builder(
                        //   shrinkWrap: true,
                        //   physics: const NeverScrollableScrollPhysics(),
                        //   itemCount: files.length,
                        //   itemBuilder: (context, index) {
                        //     final file = files[index];
                        //     final fileName = file['name'] as String;
                        //     final fileSize = file['size'] as int;
                        //     final fileType = file['type'] as String;
                        //     final timestamp = file['timestamp'] as DateTime;

                        //     IconData icon;
                        //     Color iconColor;
                        //     switch (fileType) {
                        //       case 'image':
                        //         icon = Icons.image;
                        //         iconColor = Colors.blue;
                        //         break;
                        //       case 'video':
                        //         icon = Icons.video_file;
                        //         iconColor = Colors.red;
                        //         break;
                        //       case 'document':
                        //         icon = Icons.description;
                        //         iconColor = Colors.orange;
                        //         break;
                        //       default:
                        //         icon = Icons.insert_drive_file;
                        //         iconColor = Colors.grey;
                        //     }

                        //     return Card(
                        //       margin: const EdgeInsets.symmetric(
                        //         horizontal: 16,
                        //         vertical: 4,
                        //       ),
                        //       child: ListTile(
                        //         leading: Icon(icon, color: iconColor),
                        //         title: Text(
                        //           fileName,
                        //           maxLines: 1,
                        //           overflow: TextOverflow.ellipsis,
                        //         ),
                        //         subtitle: Text(
                        //           '${_formatFileSize(fileSize)} • ${_formatTimestamp(timestamp)}',
                        //           style: const TextStyle(fontSize: 12),
                        //         ),
                        //         trailing: IconButton(
                        //           icon: const Icon(Icons.download),
                        //           onPressed: () async {
                        //             await transfer.saveToDownloads(
                        //               file['path'],
                        //               file['name'],
                        //             );
                        //           },
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: files.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, // 3 items per row
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1, // square items
                              ),
                          itemBuilder: (context, index) {
                            final file = files[index];
                            final fileName = file['name'] as String;
                            final fileType = file['type'] as String;
                            final filePath = file['path'] as String;

                            return GestureDetector(
                              onTap: () async {
                                // Open the file
                                if (fileType == 'image') {
                                  // Show image in full screen
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => Dialog(
                                          child: InteractiveViewer(
                                            child: Image.file(File(filePath)),
                                          ),
                                        ),
                                  );
                                } else {
                                  // Open other file types using system default app
                                  try {
                                    await OpenFilex.open(filePath);
                                  } catch (e) {
                                    print('Cannot open file: $e');
                                  }
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade200,
                                ),
                                child:
                                    fileType == 'image'
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            File(filePath),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              fileType == 'video'
                                                  ? Icons.video_file
                                                  : fileType == 'document'
                                                  ? Icons.description
                                                  : Icons.insert_drive_file,
                                              size: 40,
                                              color: Colors.blueGrey,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              fileName,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
