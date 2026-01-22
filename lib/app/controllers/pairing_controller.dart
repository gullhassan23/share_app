import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/device_info.dart';
import '../models/file_meta.dart';
import 'transfer_controller.dart';

class PairingController extends GetxController {
  final devices = <DeviceInfo>[].obs;
  final isServer = false.obs;
  final deviceName = ''.obs;
  final wsPort = 7070;
  final transferPort = 9090;
  HttpServer? _wsHttpServer;
  ReceivePort? _scanReceivePort;
  final incomingOffer = Rxn<Map<String, dynamic>>();
  final Map<String, WebSocket> _pendingSockets = {};
  final isScanning = false.obs;

  /// Gets the device name from platform-specific device info
  /// 
  /// **Purpose:** Retrieves a human-readable device name (e.g., "SAMSUNG Galaxy S21", "iPhone 13")
  /// **Why:** Used to display device names during pairing/discovery so users can identify devices
  /// **When called:** Called internally by `startServer()` when starting the pairing server
  /// **Side:** Used by both sender and receiver (any device that starts a server)
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand.toUpperCase();
        final model = androidInfo.model;
        return '$brand $model'.trim();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final name = iosInfo.name;
        final model = iosInfo.model;
        return name.isNotEmpty ? name : 'iPhone $model'.trim();
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
    return 'Unknown Device';
  }

  /// Starts the WebSocket server for device discovery and pairing
  /// 
  /// **Purpose:** Creates a WebSocket server on port 7070 that allows other devices to discover
  ///             this device and receive pairing offers. This is the RECEIVER-side pairing server.
  /// **Why:** Enables this device to be discoverable on the network and accept file transfer offers
  /// **When called:** Called when user wants to make their device discoverable (receiver mode)
  /// **Side:** RECEIVER side - makes this device available for pairing
  /// **Port:** 7070 (WebSocket for pairing/discovery)
  /// **Note:** This is DIFFERENT from TransferController.startServer() which uses TCP port 9090 for file transfer
  Future<void> startServer([String? customName]) async {
    // Use custom name if provided, otherwise get actual device name
    final actualDeviceName = customName ?? await _getDeviceName();
    deviceName.value = actualDeviceName;
    isServer.value = true;
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      wsPort,
      shared: true,
    );
    _wsHttpServer = server;
    print(
      'WebSocket Server running on ${_wsHttpServer?.address.address}:$wsPort',
    );

    server.listen((HttpRequest request) async {
      print(
        '🌐 WebSocket connection from ${request.connectionInfo?.remoteAddress.address}',
      );
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        print('🔗 WebSocket upgraded successfully');
        final info = NetworkInfo();
        final wifiIp = await info.getWifiIP();
        final ipToSend = wifiIp ?? _wsHttpServer?.address.address ?? '';
        print(
          '📡 Sending device info: $deviceName.value at $ipToSend:$transferPort',
        );
        socket.add(
          jsonEncode({
            'name': deviceName.value,
            'ip': ipToSend,
            'wsPort': wsPort,
            'transferPort': transferPort,
          }),
        );
        socket.listen(
          (dynamic data) async {
            try {
              final map = jsonDecode(data as String) as Map<String, dynamic>;
              if (map['type'] == 'offer') {
                final fromIp =
                    request.connectionInfo?.remoteAddress.address ?? '';
                print('📥 Received offer from $fromIp: ${map['meta']}');
                print('📝 Setting incomingOffer for UI dialog...');
                _pendingSockets[fromIp] = socket;
                incomingOffer.value = {
                  'fromIp': fromIp,
                  'meta':
                      FileMeta.fromJson(
                        map['meta'] as Map<String, dynamic>,
                      ).toJson(),
                };
                print('✅ incomingOffer set: ${incomingOffer.value}');
              }
            } catch (e) {
              print('Socket error: $e');
            }
          },
          onDone: () {},
          onError: (e) {
            print('Socket onError: $e');
          },
        );
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      }
    });
  }

  /// Stops the WebSocket pairing server
  /// 
  /// **Purpose:** Closes the WebSocket server (port 7070) that was used for device discovery
  /// **Why:** Allows the device to stop being discoverable and frees up network resources
  /// **When called:** Called when user wants to stop being discoverable or when app closes
  /// **Side:** RECEIVER side - stops the pairing server
  /// **Note:** This stops the PAIRING server, not the file transfer server (see TransferController.stopServer())
  Future<void> stopServer() async {
    await _wsHttpServer?.close(force: true);
    _wsHttpServer = null;
    isServer.value = false;
  }

  /// Scans the local network to discover other devices running the pairing server
  /// 
  /// **Purpose:** Scans all IPs in the local network subnet (e.g., 192.168.1.1-255) to find
  ///             devices that have started their pairing server (WebSocket on port 7070)
  /// **Why:** Allows users to see a list of available devices they can send files to
  /// **When called:** Called when user taps "Scan" or "Discover Devices" button (sender mode)
  /// **Side:** SENDER side - actively searches for receiver devices
  /// **How:** Uses an isolate to scan network in parallel without blocking UI
  Future<void> discover() async {
    final info = NetworkInfo();
    final localIp = await info.getWifiIP();
    if (localIp == null) return;
    final base = localIp.split('.');
    final prefix = '${base[0]}.${base[1]}.${base[2]}';
    _scanReceivePort?.close();
    _scanReceivePort = ReceivePort();
    isScanning.value = true;
    _scanReceivePort!.listen((dynamic msg) {
      if (msg is Map<String, dynamic>) {
        final d = DeviceInfo.fromJson(msg);
        print('🔍 Found device: ${d.name} at ${d.ip}:${d.transferPort}');
        // Don't add our own device to the list
        if (d.ip != localIp) {
          final existing = devices.where((e) => e.ip == d.ip).isNotEmpty;
          if (!existing) {
            devices.add(d);
            print('✅ Added device to list: ${d.name}');
          } else {
            print('⚠️ Device already in list: ${d.name}');
          }
        } else {
          print('🚫 Skipping own device: ${d.ip}');
        }
      } else if (msg is String && msg == 'done') {
        print('🔍 Device discovery completed');
        isScanning.value = false;
      }
    });
    await Isolate.spawn(_scanIsolate, {
      'prefix': prefix,
      'sendPort': _scanReceivePort!.sendPort,
    });
  }

  /// Connects to a discovered device to verify it's available and get its full info
  /// 
  /// **Purpose:** Establishes a quick WebSocket connection to a discovered device to confirm
  ///             it's online and retrieve its complete device information
  /// **Why:** Validates that a discovered device is still active and gets updated device details
  /// **When called:** Called automatically during device discovery or when refreshing device list
  /// **Side:** SENDER side - connects to receiver devices to verify availability
  /// **Note:** This is a quick connection/close, not for sending file offers (use sendOffer() for that)
  Future<void> pairWith(DeviceInfo device) async {
    final uri = Uri.parse('ws://${device.ip}:${device.wsPort}');
    try {
      final ws = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(milliseconds: 600));
      final first = await ws.first;
      final jsonMap = jsonDecode(first as String) as Map<String, dynamic>;
      final peer = DeviceInfo.fromJson(jsonMap);
      ws.close();
      final info = NetworkInfo();
      final localIp = await info.getWifiIP();
      // Don't add our own device to the list
      if (peer.ip != localIp) {
        final existing = devices.where((e) => e.ip == peer.ip).isNotEmpty;
        if (!existing) devices.add(peer);
      }
    } catch (_) {}
  }

  /// Sends a file transfer offer to a receiver device
  /// 
  /// **Purpose:** Connects to a receiver's WebSocket server (port 7070) and sends a file transfer
  ///             offer containing file metadata. Waits for receiver's accept/reject response.
  /// **Why:** Allows sender to request permission before starting the actual file transfer
  /// **When called:** Called when sender selects a file and chooses a receiver device
  /// **Side:** SENDER side - initiates file transfer negotiation
  /// **Flow:** 1. Connects to receiver's WebSocket → 2. Sends offer with file metadata →
  ///          3. Waits for accept/reject response → 4. Returns true if accepted
  /// **Note:** If accepted, the actual file transfer happens via TransferController.sendFile()
  Future<bool> sendOffer(DeviceInfo device, FileMeta meta) async {
    print('📤 Sending offer to ${device.ip}:${device.wsPort}');
    final uri = Uri.parse('ws://${device.ip}:${device.wsPort}');
    WebSocket? ws;
    try {
      ws = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 5)); // Increased timeout for connection
      print('✅ Connected to receiver WS. Sending offer data...');
      
      final offerJson = jsonEncode({'type': 'offer', 'meta': meta.toJson()});
      ws.add(offerJson);
      print('📤 Offer sent: $offerJson');
      print('⏳ Waiting for receiver response (10 second timeout)...');

      // Listen to all messages and filter for offer_response
      // Note: Receiver might send device info first, so we need to filter
      final response = await ws
          .timeout(
            const Duration(seconds: 15), // Increased timeout to 15 seconds
          )
          .map((e) {
            try {
              final decoded = jsonDecode(e as String) as Map<String, dynamic>;
              print('📥 Received message: $decoded');
              return decoded;
            } catch (e) {
              print('⚠️ Error decoding message: $e');
              return <String, dynamic>{};
            }
          })
          .firstWhere(
            (m) => m['type'] == 'offer_response',
            orElse: () => <String, dynamic>{'type': 'timeout'},
          );

      if (response['type'] == 'timeout') {
        print('⏱️ Timeout waiting for receiver response');
        await ws.close();
        return false;
      }

      print('📨 Received offer response: $response');
      await ws.close();

      final accepted = response['accept'] == true;
      print(
        accepted
            ? '✅ Offer accepted by receiver'
            : '❌ Offer rejected by receiver',
      );
      return accepted;
    } catch (e) {
      print('❌ SendOffer failed: $e');
      print('📋 Error details: ${e.toString()}');
      try {
        await ws?.close();
      } catch (_) {}
      return false;
    }
  }

  /// Responds to an incoming file transfer offer from a sender
  /// 
  /// **Purpose:** When a sender sends a file transfer offer, this function sends back an
  ///             accept or reject response. If accepted, it also starts the TCP file transfer server.
  /// **Why:** Allows receiver to accept/reject file transfers and prepares for file reception
  /// **When called:** Called when user accepts or rejects an incoming file transfer offer dialog
  /// **Side:** RECEIVER side - responds to sender's file transfer offer
  /// **Flow:** 1. If accepted, starts TransferController.startServer() (TCP port 9090) →
  ///          2. Sends accept/reject response via WebSocket → 3. Closes WebSocket connection
  /// **Note:** The actual file reception happens in TransferController.startServer() TCP listener
  Future<void> respondToOffer(String fromIp, bool accept) async {
    print('📤 Sending ${accept ? 'ACCEPT' : 'REJECT'} response to $fromIp');

    if (accept) {
      // Start TCP server for receiving files
      try {
        final transfer = Get.find<TransferController>();
        print('🔄 Starting TCP server before accepting...');
        await transfer.startServer();
        // Give the server a moment to fully bind
        await Future.delayed(const Duration(milliseconds: 200));
        print('✅ TCP server ready, sending accept response');
      } catch (e) {
        print('⚠️ Could not start transfer server: $e');
        accept = false; // Don't accept if server failed
      }
    }

    final ws = _pendingSockets.remove(fromIp);
    if (ws != null) {
      try {
        final responseJson = jsonEncode({'type': 'offer_response', 'accept': accept});
        ws.add(responseJson);
        print(
          '📤 Response sent: $responseJson',
        );
        // Give the message time to be sent before closing
        await Future.delayed(const Duration(milliseconds: 100));
        await ws.close();
        print('📤 WebSocket closed after sending response');
      } catch (e) {
        print('❌ Error sending response: $e');
        try {
          await ws.close();
        } catch (_) {}
      }
    } else {
      print('❌ No pending socket found for $fromIp');
      print('📋 Available sockets: ${_pendingSockets.keys.toList()}');
    }
    incomingOffer.value = null;
  }

  /// Background isolate that scans the network for discoverable devices
  /// 
  /// **Purpose:** Runs in a separate isolate to scan all IPs in the local subnet (1-254) without
  ///             blocking the main UI thread. Connects to each IP's WebSocket port 7070 to find devices.
  /// **Why:** Network scanning is slow (255 IPs × 300ms timeout), so it needs to run in background
  /// **When called:** Spawned by `discover()` function when user initiates device discovery
  /// **Side:** SENDER side - used during device discovery
  /// **How:** Tries to connect to ws://[IP]:7070 for each IP, collects device info, sends results back
  static void _scanIsolate(Map<String, dynamic> params) async {
    final prefix = params['prefix'] as String;
    final sendPort = params['sendPort'] as SendPort;
    for (int i = 1; i < 255; i++) {
      final ip = '$prefix.$i';
      try {
        final uri = Uri.parse('ws://$ip:7070');
        final ws = await WebSocket.connect(
          uri.toString(),
        ).timeout(const Duration(milliseconds: 300));
        final data = await ws.first;
        ws.close();
        final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
        // Override IP with the one we actually connected to
        jsonMap['ip'] = ip;
        sendPort.send(jsonMap);
      } catch (_) {}
    }
    sendPort.send('done');
  }

  /// Gets the local IP address of this device
  /// 
  /// **Purpose:** Returns the IP address that the WebSocket pairing server is bound to
  /// **Why:** Used to display this device's IP address or for network-related operations
  /// **When called:** Called when UI needs to display the device's IP address
  /// **Side:** Used by both sender and receiver
  String localIp() {
    final addr = _wsHttpServer?.address.address;
    return addr ?? '';
  }
}
