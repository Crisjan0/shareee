import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main() {
  runApp(const ChameleonP2PApp());
}

// Global Notifier para sa Color Theme / Chameleon UI Sync
ValueNotifier<Color> appThemeColor =
    ValueNotifier<Color>(const Color(0xFF3F51B5));

// Port sa P2P server — usa ra ka lugar para dali usbon
const int p2pPort = 8888;

// Helper: kuha filename nga mo-work sa Windows (\) ug Android/Linux (/)
String baseNameOf(String fullPath) {
  return fullPath.split(RegExp(r'[/\\]')).last;
}

// Helper: Color <-> Hex para ma-sync via network header/JSON
String themeToHex(Color c) {
  // ignore: deprecated_member_use
  return '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color? hexToColor(String hex) {
  try {
    var clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean'; // walay alpha -> opaque
    if (clean.length != 8) return null;
    return Color(int.parse(clean, radix: 16));
  } catch (_) {
    return null;
  }
}

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

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // FIX #1: password gi-validate na, dili lang username
  void _handleLogin() {
    String username = _userController.text.trim();
    String password = _passController.text;
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Palihog isulat ang imong username")),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Palihog isulat ang imong password")),
      );
      return;
    }
    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Password kinahanglan min. 4 ka karakter")),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(username: username),
      ),
    );
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
                const Icon(Icons.lock_person,
                    size: 80, color: Colors.blueAccent),
                const SizedBox(height: 20),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(
                      labelText: "Username (e.g. Sss)",
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  onSubmitted: (_) => _handleLogin(),
                  decoration: const InputDecoration(
                      labelText: "Password (min. 4 chars)",
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
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
  bool serverRunning = false;
  bool _isReceiving = false;

  // Upload/send progress tracking (sender side)
  List<File> servedSnapshot = [];
  List<double> serveProgress = [];
  List<int> serveSent = [];
  List<int> serveTotals = [];
  List<String> serveStatus = []; // waiting | serving | done | error
  String lastClientIp = "";
  int serveDoneCount = 0;

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
            if (mounted) setState(() => localIpAddress = addr.address);
            return;
          }
        }
      }
    } catch (_) {}
  }

  int _getTotalSize() {
    int total = 0;
    for (var file in userFiles) {
      try {
        if (file.existsSync()) total += file.lengthSync();
      } catch (_) {}
    }
    return total;
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        for (var path in result.paths) {
          if (path != null) {
            final f = File(path);
            // likay duplicate
            if (!userFiles.any((e) => e.path == f.path)) userFiles.add(f);
          }
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
      child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }

  // STEP 1: CONFIRMATION DIALOG
  void _showConfirmDialog() {
    if (userFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Palihog pagbutang sa una og file!")),
      );
      return;
    }

    // FIX #2: Bluetooth gibabagan kay wala pa na-implement
    if (transferMode == "Bluetooth") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Bluetooth transfer wala pa na-implement. Palihog gamit ug WiFi/Hotspot."),
          duration: Duration(seconds: 3),
        ),
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
  // FIX #5: gitangtang ang auto-pass sa catch (security hole)
  Future<void> _runBiometricVerification() async {
    bool canCheck = false;
    try {
      canCheck = await auth.canCheckBiometrics;
    } catch (_) {
      canCheck = false;
    }

    bool deviceSupported = false;
    try {
      deviceSupported = await auth.isDeviceSupported();
    } catch (_) {
      deviceSupported = false;
    }

    // Kung walay biometric hardware, ayaw mo-bypass — gamit device credential (PIN/pattern) isip fallback
    if (!canCheck || !deviceSupported) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Walay Biometric Sensor"),
          content: const Text(
              "Walay nakita na fingerprint/face sensor. Gusto nimo magpadayon gamit ang device PIN/lock imbis biometrics?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Padayon")),
          ],
        ),
      );
      if (proceed != true) return;
      try {
        final ok = await auth.authenticate(
          localizedReason: 'Confirm nga ikaw ang tag-iya para maka-send',
          options: const AuthenticationOptions(
            biometricOnly: false, // tugutan ang PIN/device credential
            stickyAuth: true,
          ),
        );
        if (!mounted) return;
        if (ok) {
          _showIpLocatorDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Napakyas ang verification.")));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification error: $e")));
      }
      return;
    }

    // Naa'y biometric hardware — 2-step gihapon pero walay bypass
    bool facePassed = false;
    bool fingerprintPassed = false;

    try {
      facePassed = await auth.authenticate(
        localizedReason: 'Face Recognition: Palihog i-scan ang imong nawong',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Face scan error: $e")));
      return;
    }

    if (!facePassed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Napakyas ang Face Scan.")));
      return;
    }

    try {
      fingerprintPassed = await auth.authenticate(
        localizedReason: 'Fingerprint Scan: Palihog itap ang imong tudlo',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fingerprint error: $e")));
      return;
    }

    if (facePassed && fingerprintPassed) {
      if (!mounted) return;
      _showIpLocatorDialog();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Wala nahuman ang Face ug Fingerprint verification.")));
    }
  }

  // STEP 3: IP LOCATOR / RECEIVER DIALOG
  void _showIpLocatorDialog() {
    final TextEditingController ipController =
        TextEditingController(text: localIpAddress);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Send via $transferMode"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("UI Theme: "),
                    CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 12),
                    const SizedBox(width: 8),
                    Text(themeToHex(Theme.of(context).primaryColor),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    "Files: ${userFiles.length} (${(_getTotalSize() / 1024).toStringAsFixed(2)} KB)"),
                const SizedBox(height: 8),
                const Text(
                  "Pahinumdom: ang receiver kay mo-open sa imong server URL sa browser, o gamiton ang 'Receive' button sulod ani nga app.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 15),
                const Text("Imong server IP (ipakita sa receiver):"),
                const SizedBox(height: 8),
                TextField(
                  controller: ipController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Sender IP (imohang IP)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 15),
                const Text("Available IPs:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check,
                          color: Colors.green, size: 16),
                      label: Text(localIpAddress),
                      onPressed: () => ipController.text = localIpAddress,
                    ),
                    ActionChip(
                      label: const Text("192.168.43.1"),
                      onPressed: () => ipController.text = "192.168.43.1",
                    ),
                  ],
                ),
              ],
            ),
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
  // FIX #3: multi-file + tinuod na theme sync via header/JSON/HTML
  // FIX #7: Windows filename bug (split RegExp)
  // BAG-O: upload progress tracking per file (sender side)
  Future<void> _startHotspotServerAndSend() async {
    try {
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }
      _server = await HttpServer.bind(InternetAddress.anyIPv4, p2pPort);

      // Snapshot sa files para consistent ang serve bisan ma-edit ang queue
      servedSnapshot = List<File>.from(userFiles);
      serveProgress = List.filled(servedSnapshot.length, 0.0);
      serveSent = List.filled(servedSnapshot.length, 0);
      serveStatus = List.filled(servedSnapshot.length, "waiting");
      serveTotals = servedSnapshot.map((f) {
        try {
          if (f.existsSync()) return f.lengthSync();
        } catch (_) {}
        return 0;
      }).toList();
      lastClientIp = "";
      serveDoneCount = 0;

      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path;
          final themeHex = themeToHex(appThemeColor.value);
          // Ibutang ang theme sa header para mabasa sa in-app receiver
          request.response.headers.add('X-Theme-Color', themeHex);
          request.response.headers.add('Access-Control-Allow-Origin', '*');

          // Route: /list -> JSON para sa in-app receiver
          if (path == '/list') {
            final list = <Map<String, dynamic>>[];
            for (int i = 0; i < servedSnapshot.length; i++) {
              list.add({
                'index': i,
                'name': baseNameOf(servedSnapshot[i].path),
                'size': serveTotals[i],
              });
            }
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'theme': themeHex,
              'count': servedSnapshot.length,
              'files': list,
            }));
            await request.response.close();
            return;
          }

          // Route: /theme -> plain hex (dali basahon)
          if (path == '/theme') {
            request.response.headers.contentType = ContentType.text;
            request.response.write(themeHex);
            await request.response.close();
            return;
          }

          // Route: /file/<index> o /file?i=<index> — naay upload progress
          if (path.startsWith('/file')) {
            int? idx;
            final seg = request.uri.pathSegments;
            // /file/0
            if (seg.length >= 2) idx = int.tryParse(seg[1]);
            // /file?i=0
            idx ??= int.tryParse(request.uri.queryParameters['i'] ?? '');
            if (idx == null ||
                idx < 0 ||
                idx >= servedSnapshot.length) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write("File index dili valid.");
              await request.response.close();
              return;
            }
            final file = servedSnapshot[idx];
            if (!file.existsSync()) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write("File wala na makita.");
              await request.response.close();
              if (mounted) {
                setState(() => serveStatus[idx!] = "error");
              }
              return;
            }
            final name = baseNameOf(file.path);
            final total = serveTotals[idx];
            final clientIp =
                request.connectionInfo?.remoteAddress.address ?? "unknown";

            request.response.headers.add(HttpHeaders.contentTypeHeader,
                "application/octet-stream");
            request.response.headers.add('content-disposition',
                'attachment; filename="$name"');
            // Importante: i-set ang contentLength para makita sa receiver ang %
            if (total > 0) request.response.contentLength = total;

            if (mounted) {
              setState(() {
                serveStatus[idx!] = "serving";
                lastClientIp = clientIp;
                // reset kung balik-download
                if (serveProgress[idx] >= 1.0) {
                  serveProgress[idx] = 0.0;
                  serveSent[idx] = 0;
                }
              });
            }

            try {
              // Manual chunk streaming para ma-track ang upload progress
              await for (final chunk in file.openRead()) {
                request.response.add(chunk);
                if (mounted) {
                  setState(() {
                    serveSent[idx!] += chunk.length;
                    if (total > 0) {
                      serveProgress[idx!] =
                          (serveSent[idx!] / total).clamp(0.0, 1.0);
                    }
                  });
                }
              }
              await request.response.close();
              if (mounted) {
                setState(() {
                  serveProgress[idx!] = 1.0;
                  serveStatus[idx!] = "done";
                  serveDoneCount =
                      serveStatus.where((s) => s == "done").length;
                });
              }
            } catch (_) {
              // Na-disconnect ang receiver tunga-tunga
              try {
                await request.response.close();
              } catch (_) {}
              if (mounted) {
                setState(() => serveStatus[idx!] = "error");
              }
            }
            return;
          }

          // Route: / (default) -> HTML page nga naay lista sa TANAN files + theme
          if (servedSnapshot.isEmpty) {
            request.response.write("No files available.");
            await request.response.close();
            return;
          }
          final buf = StringBuffer();
          buf.writeln('<!doctype html><html><head><meta charset="utf-8">');
          buf.writeln(
              '<meta name="viewport" content="width=device-width,initial-scale=1">');
          buf.writeln('<title>Chameleon P2P Share</title></head><body>');
          buf.writeln(
              '<h3>Chameleon P2P Share (${servedSnapshot.length} files)</h3>');
          buf.writeln(
              '<p>UI Theme: <span style="display:inline-block;width:14px;height:14px;background:$themeHex;border-radius:50%"></span> $themeHex</p>');
          buf.writeln('<ul>');
          for (int i = 0; i < servedSnapshot.length; i++) {
            final name = baseNameOf(servedSnapshot[i].path);
            buf.writeln(
                '<li><a href="/file/$i">$name</a></li>');
          }
          buf.writeln('</ul>');
          buf.writeln(
              '<p>Tip: kung naa kay Chameleon app, gamita ang Receive button imbis browser para ma-sync ang color.</p>');
          buf.writeln('</body></html>');
          request.response.headers.contentType = ContentType.html;
          request.response.write(buf.toString());
          await request.response.close();
        } catch (e) {
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write("Server error: $e");
            await request.response.close();
          } catch (_) {}
        }
      });

      if (mounted) setState(() => serverRunning = true);
    } catch (e) {
      debugPrint("Server error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dili ma-start ang server: $e")));
      return;
    }

    // Awtomatikong usabon ang color pag-send (chameleon effect)
    List<Color> dynamicColors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal
    ];
    appThemeColor.value =
        dynamicColors[Random().nextInt(dynamicColors.length)];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hotspot Server Active!"),
          content: Text(
              "Aktibo na ang server sa http://$localIpAddress:$p2pPort\n\nAng UI color kay ${themeToHex(appThemeColor.value)} — ma-sync ni sa receiver kung gamiton nila ang Receive button.\n\nBrowser pwede pud mo-download (lista sa tanan files)."),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _stopServer() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    if (mounted) {
      setState(() {
        serverRunning = false;
        // ayaw i-clear dayon ang progress para makita ang history,
        // pero i-reset ang status kung gusto mo-send usab
      });
    }
  }

  void _resetServeProgress() {
    setState(() {
      serveProgress = List.filled(servedSnapshot.length, 0.0);
      serveSent = List.filled(servedSnapshot.length, 0);
      serveStatus = List.filled(servedSnapshot.length, "waiting");
      serveDoneCount = 0;
      lastClientIp = "";
    });
  }

  // ==========================================
  // FIX #4: IN-APP RECEIVER / DOWNLOAD
  // ==========================================
  Future<void> _showReceiveDialog() async {
    final ipController = TextEditingController(text: "192.168.43.1");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Receive Files"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Isulat ang Sender IP (makita sa ilang Dashboard):",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Sender IP",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text("Connect"),
            onPressed: () {
              Navigator.pop(context);
              _receiveFromSender(ipController.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _receiveFromSender(String senderIp) async {
    if (senderIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Palihog isulat ang sender IP")));
      return;
    }
    setState(() => _isReceiving = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      // 1. Kuha file list + theme
      final listReq = await client
          .getUrl(Uri.parse('http://$senderIp:$p2pPort/list'));
      final listResp = await listReq.close().timeout(
            const Duration(seconds: 10),
          );
      if (listResp.statusCode != 200) {
        throw HttpException(
            'Server nibalik ug ${listResp.statusCode}. Sakto ba ang IP?');
      }
      final body = await listResp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      client.close();

      // 2. I-sync ang theme color gikan sa sender
      final themeHex = data['theme'] as String?;
      if (themeHex != null) {
        final c = hexToColor(themeHex);
        if (c != null) appThemeColor.value = c;
      }

      final files = (data['files'] as List).cast<Map<String, dynamic>>();
      if (files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Walay files sa sender.")));
        return;
      }

      if (!mounted) return;
      // 3. Pilia asa i-save
      String? saveDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilia asa i-save ang files',
      );
      if (saveDir == null) return; // gi-cancel sa user

      if (!mounted) return;
      // 4. Ablihi ang progress dialog — didto na ang per-file download
      final done = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReceiveProgressDialog(
          senderIp: senderIp,
          files: files,
          saveDir: saveDir,
        ),
      );

      if (!mounted) return;
      if (done != null && done > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Na-download ang $done/${files.length} files sa $saveDir. Na-sync na pud ang UI color!")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Dili maka-connect sa $senderIp:$p2pPort. Check kung same WiFi/Hotspot mo. ($e)")));
    } finally {
      if (mounted) setState(() => _isReceiving = false);
    }
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
            onPressed: () {
              _stopServer();
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()));
            },
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
                    const Text("Transfer Mode: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("WiFi/Hotspot"),
                      selected: transferMode == "WiFi/Hotspot",
                      onSelected: (val) =>
                          setState(() => transferMode = "WiFi/Hotspot"),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Bluetooth"),
                      selected: transferMode == "Bluetooth",
                      onSelected: (val) =>
                          setState(() => transferMode = "Bluetooth"),
                    ),
                  ],
                ),
              ),
            ),
            if (transferMode == "Bluetooth")
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  "Pahinumdom: Bluetooth wala pa na-suportahan. Palihog switch sa WiFi/Hotspot para maka-send.",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      serverRunning
                          ? "Server Running ($transferMode):"
                          : "Receiver Active ($transferMode):"),
                  Flexible(
                    child: Text("$localIpAddress:$p2pPort",
                        style: TextStyle(
                            color: currentTheme,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            if (serverRunning)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text("Server aktibo — pwede na mo-connect ang receiver.",
                          style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _stopServer,
                      icon: const Icon(Icons.stop,
                          size: 16, color: Colors.red),
                      label: const Text("Stop",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text("Queued Files:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: userFiles.isEmpty
                  ? const Center(child: Text("No files queued."))
                  : ListView.builder(
                      itemCount: userFiles.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(baseNameOf(userFiles[index].path)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => userFiles.removeAt(index)),
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
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isReceiving ? null : _showReceiveDialog,
                icon: _isReceiving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(
                    _isReceiving ? "Receiving..." : "Receive from Sender"),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// RECEIVE PROGRESS DIALOG (per-file progress bar)
// ==========================================
String formatBytes(int bytes) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB"];
  double size = bytes.toDouble();
  int i = 0;
  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }
  return "${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}";
}

class ReceiveProgressDialog extends StatefulWidget {
  final String senderIp;
  final List<Map<String, dynamic>> files;
  final String saveDir;

  const ReceiveProgressDialog({
    super.key,
    required this.senderIp,
    required this.files,
    required this.saveDir,
  });

  @override
  State<ReceiveProgressDialog> createState() => _ReceiveProgressDialogState();
}

class _ReceiveProgressDialogState extends State<ReceiveProgressDialog> {
  late List<double> _progress; // 0.0 - 1.0 per file
  late List<int> _received; // bytes na-download per file
  late List<int> _totals; // total bytes per file (gikan sa /list)
  late List<String> _status; // "waiting" | "downloading" | "done" | "error"
  int _doneCount = 0;
  bool _cancelled = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _progress = List.filled(widget.files.length, 0.0);
    _received = List.filled(widget.files.length, 0);
    _totals = widget.files
        .map((f) => (f['size'] as int?) ?? 0)
        .toList();
    _status = List.filled(widget.files.length, "waiting");
    // Sugdan ang download pag-open sa dialog
    _startDownload();
  }

  Future<void> _startDownload() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    int done = 0;

    for (int i = 0; i < widget.files.length; i++) {
      if (_cancelled) break;
      final f = widget.files[i];
      final idx = f['index'] as int;
      final name = (f['name'] as String?) ?? 'file_$idx';
      final safeName = name.replaceAll(RegExp(r'[<>:"|?*]'), '_');

      setState(() => _status[i] = "downloading");

      try {
        final req = await client
            .getUrl(Uri.parse('http://${widget.senderIp}:$p2pPort/file/$idx'));
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          if (mounted) setState(() => _status[i] = "error");
          continue;
        }

        // Mas sakto nga total gikan sa response header kung naa
        final headerTotal = resp.contentLength;
        if (headerTotal > 0 && mounted) {
          setState(() => _totals[i] = headerTotal);
        }

        final outFile =
            File('${widget.saveDir}/$safeName');
        final sink = outFile.openWrite();

        await for (final chunk in resp) {
          if (_cancelled) break;
          sink.add(chunk);
          if (!mounted) break;
          setState(() {
            _received[i] += chunk.length;
            if (_totals[i] > 0) {
              _progress[i] =
                  (_received[i] / _totals[i]).clamp(0.0, 1.0);
            } else {
              // Kung walay total, ipakita indeterminate-like (0.0 = animation)
              _progress[i] = 0.0;
            }
          });
        }
        await sink.close();

        if (_cancelled) {
          // Limpyohi ang half-downloaded file kung gi-cancel
          try {
            if (await outFile.exists()) await outFile.delete();
          } catch (_) {}
          if (mounted) setState(() => _status[i] = "waiting");
          break;
        }

        if (mounted) {
          setState(() {
            _progress[i] = 1.0;
            _status[i] = "done";
          });
        }
        done++;
        if (mounted) setState(() => _doneCount = done);
      } catch (_) {
        if (mounted) setState(() => _status[i] = "error");
      }
    }

    client.close();
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final totalFiles = widget.files.length;
    final overall =
        totalFiles == 0 ? 0.0 : _doneCount / totalFiles;

    return AlertDialog(
      title: Text("Downloading ($_doneCount/$totalFiles)"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Overall progress
            Row(
              children: [
                const Text("Overall: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: LinearProgressIndicator(value: overall),
                ),
                const SizedBox(width: 8),
                Text("${(overall * 100).toStringAsFixed(0)}%"),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: totalFiles,
                itemBuilder: (context, i) {
                  final name = widget.files[i]['name'] ?? 'file_$i';
                  final pct = (_progress[i] * 100).toStringAsFixed(0);
                  final showIndeterminate =
                      _status[i] == "downloading" && _totals[i] <= 0;
                  Widget trailing;
                  if (_status[i] == "done") {
                    trailing = const Icon(Icons.check_circle,
                        color: Colors.green, size: 20);
                  } else if (_status[i] == "error") {
                    trailing =
                        const Icon(Icons.error, color: Colors.red, size: 20);
                  } else if (_status[i] == "downloading") {
                    trailing = Text("$pct%",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12));
                  } else {
                    trailing = const Icon(Icons.hourglass_empty,
                        color: Colors.grey, size: 20);
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            trailing,
                          ],
                        ),
                        const SizedBox(height: 4),
                        showIndeterminate
                            ? const LinearProgressIndicator()
                            : LinearProgressIndicator(
                                value: _status[i] == "waiting"
                                    ? 0.0
                                    : _progress[i],
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                        const SizedBox(height: 2),
                        Text(
                          _status[i] == "done"
                              ? "${formatBytes(_totals[i])} • Humana"
                              : _status[i] == "error"
                                  ? "Napakyas — sulayi usab"
                                  : _status[i] == "waiting"
                                      ? "Naghulat... (${formatBytes(_totals[i])})"
                                      : "${formatBytes(_received[i])} / ${formatBytes(_totals[i])}",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_finished)
          TextButton(
            onPressed: () {
              setState(() {
                _cancelled = true;
                _finished = true;
              });
              Navigator.pop(context, _doneCount);
            },
            child: const Text("Cancel",
                style: TextStyle(color: Colors.red)),
          ),
        if (_finished)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _doneCount),
            child: Text(_doneCount == totalFiles ? "OK" : "Close"),
          ),
      ],
    );
  }
}
