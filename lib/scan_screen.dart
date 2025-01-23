import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:bite_flutter_test/utils/snack_bar.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  // Initialize the Beacon Data Parser
  final BeaconDataParser beaconDataParser = BeaconDataParser();

  @override
  void initState() {
    super.initState();
    // Automatically start scanning when the screen loads
    startScan();

    // Listen for scan results
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    }, onError: (e) {
      Snackbar.show(ABC.b, "Scan Error: ${e.toString()}", success: false);
    });

    // Listen for scanning status
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      setState(() {
        _isScanning = state;
      });
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  // Automatically start scanning
  Future<void> startScan() async {
    try {
      setState(() {
        _isScanning = true;
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      Snackbar.show(ABC.b, "Start Scan Error: ${e.toString()}", success: false);
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      Snackbar.show(ABC.b, "Stop Scan Error: ${e.toString()}", success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Devices')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: startScan,
            child: ListView(
              children: _buildScanResultTiles(),
            ),
          ),
          if (_isScanning) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  List<Widget> _buildScanResultTiles() {
    return _scanResults.map((result) {
      final advertisementData = result.advertisementData;

      // Check if the device name starts with "BEACON"
      if (advertisementData.advName.startsWith("BEACON")) {
        // Parse manufacturer-specific data if available
        if (advertisementData.manufacturerData.isNotEmpty) {
          final manufacturerData =
              advertisementData.manufacturerData.values.first;
          final beaconData = beaconDataParser
              .parseBeaconData(Uint8List.fromList(manufacturerData));

          return ListTile(
            title: Text("Device: ${advertisementData.advName}"),
            subtitle: Text(
              "Temperature: ${beaconData['temperature']}, Humidity: ${beaconData['humidity']}",
            ),
          );
        } else {
          return ListTile(
            title: Text("Device: ${advertisementData.advName}"),
            subtitle: const Text("No beacon data"),
          );
        }
      }
      return const SizedBox.shrink();
    }).toList();
  }
}

// Beacon Data Parser logic
class BeaconDataParser {
  // Parse the beacon data to extract temperature and humidity
  Map<String, String?> parseBeaconData(Uint8List data) {
    // Convert the data to a hex string
    String hexString =
        data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

    String flagsHex = hexString.substring(2, 4);

    // Convert the flags byte (hex) to an integer
    int flags = int.parse(flagsHex, radix: 16);

    // Check individual flags using bit masks
    bool hasTemperature =
        (flags & 1) != 0; // Check if bit 0 (temperature) is set
    bool hasHumidity = (flags & 3) != 0; // Check if bit 1 (humidity) is set

    // Parse the temperature if the flag is set
    String? temperature =
        hasTemperature ? _parseTemperatureHex(hexString, 4) : null;

    // Parse the humidity if the flag is set
    String? humidity = hasHumidity ? _parseHumidityHex(hexString, 8) : null;

    return {
      'temperature': temperature,
      'humidity': humidity,
    };
  }

  // Parse temperature from hex string starting at the specified position
  String _parseTemperatureHex(String hexString, int start) {
    String tempHex = hexString.substring(start, start + 4);

    int tempValue = int.parse(tempHex, radix: 16);

    // Convert to actual temperature by dividing by 100.0
    return "${(tempValue / 100.0).toStringAsFixed(2)}°C";
  }

  // Parse humidity from hex string starting at the specified position
  String _parseHumidityHex(String hexString, int start) {
    String humidityHex = hexString.substring(start, start + 2);

    // Convert hex string to integer
    int humidityValue = int.parse(humidityHex, radix: 16);

    // Return the humidity as a percentage
    return "$humidityValue%";
  }
}
