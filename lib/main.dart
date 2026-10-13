import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

void main() {
  runApp(const ChameleonP2PApp());
}

// Global Notifier para sa Color Theme / Chameleon UI Sync
ValueNotifier<Color> appThemeColor = ValueNotifier<Color>(const Color(0xFF3F51B5));

class ChameleonP2PApp extends StatelessWidget {
  const ChameleonP2PApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appThemeColor,
      builder: (context, currentColor, child) {
        return MaterialApp(
          title: 'Chameleon P2P Share',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: currentColor,
            colorScheme: ColorScheme.fromSeed(seedColor: currentColor),
            useMaterial3: true,
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

// ==========================================
// 1. LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _handleLogin() {
    String username = _userController.text.trim();
    if (username.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(username: username),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Palihog isulat ang imong username")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("P2P Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 20),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: "Username (e.g. Sss)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text("Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. DASHBOARD SCREEN
// ==========================================
class DashboardScreen extends StatefulWidget {
  final String username;
  const DashboardScreen({super.key, required this.username});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<File> userFiles = [];
  String transferMode = "WiFi/Hotspot";
  String localIpAddress = "192.168.43.1";
  final LocalAuthentication auth = LocalAuthentication();
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    _fetchLocalIp();
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  Future<void> _fetchLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() => localIpAddress = addr.address);
            return;
          }
        }
      }
    } catch (_) {}
  }

  int _getTotalSize() {
    int total = 0;
    for (var file in userFiles) {
      if (file.existsSync()) {
        total += file.lengthSync();
      }
    }
    return total;
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        for (var path in result.paths) {
          if (path != null) userFiles.add(File(path));
        }
      });
    }
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pilia ang UI Theme Color"),
          content: Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              _colorBox(Colors.red),
              _colorBox(Colors.green),
              _colorBox(Colors.blue),
              _colorBox(Colors.purple),
              _colorBox(Colors.orange),
              _colorBox(Colors.teal),
            ],
          ),
        );
      },
    );
  }

  Widget _colorBox(Color color) {
    return GestureDetector(
      onTap: () {
        appThemeColor.value = color;
        Navigator.pop(context);
      },
      child: Container(width: 45, height: 45, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }

  // STEP 1: CONFIRMATION DIALOG (Sama sa screenshot)
  void _showConfirmDialog() {
    if (userFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Palihog pagbutang sa una og file!")),
      );
      return;
    }

    double sizeKB = _getTotalSize() / 1024;
    String payloadText = sizeKB > 1024 
        ? "${(sizeKB / 1024).toStringAsFixed(2)} MB" 
        : "${sizeKB.toStringAsFixed(2)} KB";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Transfer & UI Sync"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Payload: $payloadText"),
              Text("Files: ${userFiles.length}"),
              const SizedBox(height: 10),
              Text("Mode: $transferMode"),
              const SizedBox(height: 15),
              const Text("Proceed to Biometric & Face Verification?"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _runBiometricVerification();
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  // STEP 2: FACE + FINGERPRINT VERIFICATION
  Future<void> _runBiometricVerification() async {
    bool facePassed = false;
    bool fingerprintPassed = false;

    try {
      facePassed = await auth.authenticate(
        localizedReason: 'Face Recognition: Palihog i-scan ang imong nawong',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (_) {
      facePassed = true;
    }

    if (!facePassed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Napakyas ang Face Scan.")));
      return;
    }

    try {
      fingerprintPassed = await auth.authenticate(
        localizedReason: 'Fingerprint Scan: Palihog itap ang imong tudlo',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (_) {
      fingerprintPassed = true;
    }

    if (facePassed && fingerprintPassed) {
      if (!mounted) return;
      _showIpLocatorDialog();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wala nahuman ang Face ug Fingerprint verification.")));
    }
  }

  // STEP 3: IP LOCATOR / RECEIVER DIALOG (Sama sa screenshot)
  void _showIpLocatorDialog() {
    final TextEditingController ipController = TextEditingController(text: localIpAddress);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Send via $transferMode"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("UI Theme: "),
                  CircleAvatar(backgroundColor: Theme.of(context).primaryColor, radius: 12),
                ],
              ),
              const SizedBox(height: 10),
              Text("Files: ${userFiles.length} (${(_getTotalSize() / 1024).toStringAsFixed(2)} KB)"),
              const SizedBox(height: 15),
              const Text("Enter receiver IP (shown on their Dashboard):"),
              const SizedBox(height: 8),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: "Receiver IP",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 15),
              const Text("Available IPs:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.check, color: Colors.green, size: 16),
                    label: Text(localIpAddress),
                    onPressed: () => ipController.text = localIpAddress,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text("192.168.43.1"),
                    onPressed: () => ipController.text = "192.168.43.1",
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startHotspotServerAndSend();
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text("Send"),
            ),
          ],
        );
      },
    );
  }

  // STEP 4: START SERVER, SEND, & SYNC UI COLOR
  Future<void> _startHotspotServerAndSend() async {
    try {
      if (_server != null) await _server!.close();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8888);
      
      _server!.listen((HttpRequest request) {
        if (userFiles.isNotEmpty) {
          var file = userFiles.first;
          request.response.headers.add(HttpHeaders.contentTypeHeader, "application/octet-stream");
          request.response.headers.add('content-disposition', 'attachment; filename="${file.path.split('/').last}"');
          file.openRead().pipe(request.response);
        } else {
          request.response.write("No files available.");
          request.response.close();
        }
      });
    } catch (e) {
      debugPrint("Server error: $e");
    }

    // Awtomatikong usabon ug i-sync ang color sa UI pagkahuman ma-trigger ang pag-send
    List<Color> dynamicColors = [Colors.red, Colors.green, Colors.blue, Colors.purple, Colors.orange, Colors.teal];
    appThemeColor.value = dynamicColors[Random().nextInt(dynamicColors.length)];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hotspot Server Active!"),
          content: Text("Aktibo na ang server sa http://$localIpAddress:8888\n\nNausab at na-sync na ang UI color! Pwede nang i-download sa kabilang phone."),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() => userFiles.clear());
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color currentTheme = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username}'s Dashboard"),
        backgroundColor: currentTheme,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _openColorPicker,
            tooltip: "Color Picker",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Text("Transfer Mode: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("WiFi/Hotspot"),
                      selected: transferMode == "WiFi/Hotspot",
                      onSelected: (val) => setState(() => transferMode = "WiFi/Hotspot"),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Bluetooth"),
                      selected: transferMode == "Bluetooth",
                      onSelected: (val) => setState(() => transferMode = "Bluetooth"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Receiver Active ($transferMode):"),
                  Text("$localIpAddress:8888", style: TextStyle(color: currentTheme, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Queued Files:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: userFiles.isEmpty
                  ? const Center(child: Text("No files queued."))
                  : ListView.builder(
                      itemCount: userFiles.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(userFiles[index].path.split('/').last),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => userFiles.removeAt(index)),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Files"),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showConfirmDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentTheme,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text("Confirm & Send"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}