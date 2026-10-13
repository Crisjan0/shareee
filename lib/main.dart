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
// Default: classical deep navy (elegant, dili hayag)
ValueNotifier<Color> appThemeColor =
    ValueNotifier<Color>(const Color(0xFF1E2A4A));

// Port sa P2P server — usa ra ka lugar para dali usbon
const int p2pPort = 8888;

// ==========================================
// ELEGANT CLASSICAL DESIGN TOKENS
// ==========================================
const Color kIvory = Color(0xFFF6F0E2);
const Color kParchment = Color(0xFFFCF9F1);
const Color kCharcoal = Color(0xFF1C1A16);
const Color kCharcoalSoft = Color(0xFF2E2A24);
const Color kGold = Color(0xFFC6A15B);
const Color kGoldDeep = Color(0xFF9A7B2D);
const Color kGoldSoft = Color(0xFFEADFC3);
const Color kStoneGrey = Color(0xFF8A8175);

// Classical chameleon palette (muted, elegant — dili neon)
const List<Color> kClassicalPalette = [
  Color(0xFF1E2A4A), // Royal Navy
  Color(0xFF5C1F24), // Burgundy
  Color(0xFF2F4A3C), // Forest
  Color(0xFF4A3563), // Plum
  Color(0xFF8A6D2B), // Antique Gold
  Color(0xFF2F5D5A), // Slate Teal
];

TextStyle classicalHeading({double size = 16, Color? color}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: color ?? kCharcoal,
  );
}

TextStyle classicalSmallCaps({double size = 11, Color? color}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: color ?? kStoneGrey,
  );
}

class GoldDivider extends StatelessWidget {
  final double width;
  const GoldDivider({super.key, this.width = 48});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 1, width: width, color: kGoldSoft),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: kGold,
            shape: BoxShape.circle,
            border: Border.all(color: kGoldDeep, width: 0.8),
          ),
        ),
        Container(height: 1, width: width, color: kGoldSoft),
      ],
    );
  }
}

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
        final scheme = ColorScheme.fromSeed(
          seedColor: currentColor,
          brightness: Brightness.light,
        );
        return MaterialApp(
          title: 'Chameleon P2P Share',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: currentColor,
            colorScheme: scheme.copyWith(
              primary: currentColor,
              secondary: kGold,
              surface: kParchment,
            ),
            scaffoldBackgroundColor: kIvory,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: kCharcoal,
              foregroundColor: Color(0xFFF3EAD3),
              centerTitle: true,
              elevation: 0,
              titleTextStyle: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            cardTheme: CardThemeData(
              color: kParchment,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: kGoldSoft, width: 1),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              labelStyle: const TextStyle(color: kStoneGrey, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: kGoldSoft, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: kGoldDeep, width: 1.6),
              ),
              prefixIconColor: kGoldDeep,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: kCharcoal,
                foregroundColor: const Color(0xFFF3EAD3),
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontFamily: 'Georgia',
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: kGoldDeep, width: 1),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: kCharcoal,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: kGoldDeep, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Georgia',
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: Colors.white,
              selectedColor: kCharcoal,
              secondarySelectedColor: kCharcoal,
              labelStyle: const TextStyle(fontSize: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: kGoldSoft),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: kParchment,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: kGoldSoft, width: 1.2),
              ),
              titleTextStyle: classicalHeading(size: 16),
              contentTextStyle:
                  const TextStyle(color: kCharcoalSoft, fontSize: 13.5, height: 1.5),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: kGoldDeep,
              linearTrackColor: kGoldSoft,
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: kCharcoal,
              contentTextStyle: const TextStyle(
                color: Color(0xFFF3EAD3),
                fontFamily: 'Georgia',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: kGoldDeep),
              ),
              behavior: SnackBarBehavior.floating,
            ),
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
      backgroundColor: kIvory,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("EST. MMXXVI",
                    style: classicalSmallCaps(size: 11, color: kGoldDeep)),
                const SizedBox(height: 8),
                Text("CHAMELEON",
                    style: classicalHeading(size: 30, color: kCharcoal)),
                const Text("P2P  SHARE",
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 13,
                      letterSpacing: 6,
                      color: kStoneGrey,
                    )),
                const SizedBox(height: 12),
                const GoldDivider(width: 70),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: kParchment,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kGoldSoft, width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A1C1A16),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCharcoal,
                          border: Border.all(color: kGold, width: 2),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            size: 40, color: Color(0xFFF3EAD3)),
                      ),
                      const SizedBox(height: 16),
                      Text("Private Salon",
                          style: classicalHeading(
                              size: 15, color: kCharcoal)),
                      Text("Sign in to enter",
                          style: classicalSmallCaps(size: 10)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          labelText: "Username",
                          hintText: "e.g. Sss",
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        onSubmitted: (_) => _handleLogin(),
                        decoration: const InputDecoration(
                          labelText: "Password",
                          hintText: "min. 4 characters",
                          prefixIcon: Icon(Icons.key_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          child: const Text("ENTER"),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text("Face & fingerprint guarded • Wi-Fi salon",
                    style: classicalSmallCaps(size: 9)),
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
      total += _fileSizeOf(file);
    }
    return total;
  }

  int _fileSizeOf(File file) {
    try {
      if (file.existsSync()) return file.lengthSync();
    } catch (_) {}
    return 0;
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
          title: const Text("Atelier Palette"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("CLASSICAL TONES",
                  style: classicalSmallCaps(size: 10, color: kGoldDeep)),
              const SizedBox(height: 4),
              const GoldDivider(width: 40),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final c in kClassicalPalette) _colorBox(c),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _colorBox(Color color) {
    final selected = appThemeColor.value == color;
    return GestureDetector(
      onTap: () {
        appThemeColor.value = color;
        Navigator.pop(context);
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? kGoldDeep : kGold,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, color: Color(0xFFF3EAD3), size: 20)
            : null,
      ),
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
          title: const Text("Seal of Transfer"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text("INVENTORY",
                  style: classicalSmallCaps(
                      size: 10, color: kGoldDeep))),
              const SizedBox(height: 4),
              const GoldDivider(width: 36),
              const SizedBox(height: 12),
              _ledgerRow("Payload", payloadText),
              _ledgerRow("Pieces", "${userFiles.length}"),
              _ledgerRow("Via", transferMode),
              const SizedBox(height: 12),
              const Text(
                "Proceed to face & fingerprint verification?",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Decline",
                  style: TextStyle(color: kStoneGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _runBiometricVerification();
              },
              child: const Text("VERIFY"),
            ),
          ],
        );
      },
    );
  }

  Widget _ledgerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: classicalSmallCaps(size: 10)),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
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
          title: Text("Dispatch via $transferMode"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text("SALON SEAL",
                    style: classicalSmallCaps(
                        size: 10, color: kGoldDeep))),
                const SizedBox(height: 4),
                const GoldDivider(width: 36),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text("MOTIF  ",
                        style: classicalSmallCaps(size: 10)),
                    CircleAvatar(
                        backgroundColor: appThemeColor.value,
                        radius: 12),
                    const SizedBox(width: 8),
                    Text(themeToHex(appThemeColor.value),
                        style: const TextStyle(
                            fontSize: 12, color: kStoneGrey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    "${userFiles.length} pieces (${(_getTotalSize() / 1024).toStringAsFixed(2)} KB)",
                    style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  "The receiver may enter through a browser, or through the Receive button within this salon.",
                  style: TextStyle(
                      fontSize: 12,
                      color: kStoneGrey,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 14),
                Text("SALON ADDRESS",
                    style:
                        classicalSmallCaps(size: 10, color: kGoldDeep)),
                const SizedBox(height: 6),
                TextField(
                  controller: ipController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Sender IP",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Text("KNOWN ADDRESSES",
                    style:
                        classicalSmallCaps(size: 10, color: kGoldDeep)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check,
                          color: Color(0xFF2F4A3C), size: 16),
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
              child: const Text("Decline",
                  style: TextStyle(color: kStoneGrey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startHotspotServerAndSend();
              },
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text("DISPATCH"),
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
            final fileIdx = idx;
            final file = servedSnapshot[fileIdx];
            if (!file.existsSync()) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write("File wala na makita.");
              await request.response.close();
              if (mounted) {
                setState(() => serveStatus[fileIdx] = "error");
              }
              return;
            }
            final name = baseNameOf(file.path);
            final total = serveTotals[fileIdx];
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
                serveStatus[fileIdx] = "serving";
                lastClientIp = clientIp;
                // reset kung balik-download
                if (serveProgress[fileIdx] >= 1.0) {
                  serveProgress[fileIdx] = 0.0;
                  serveSent[fileIdx] = 0;
                }
              });
            }

            try {
              // Manual chunk streaming para ma-track ang upload progress
              await for (final chunk in file.openRead()) {
                request.response.add(chunk);
                if (mounted) {
                  setState(() {
                    serveSent[fileIdx] += chunk.length;
                    if (total > 0) {
                      serveProgress[fileIdx] =
                          (serveSent[fileIdx] / total).clamp(0.0, 1.0);
                    }
                  });
                }
              }
              await request.response.close();
              if (mounted) {
                setState(() {
                  serveProgress[fileIdx] = 1.0;
                  serveStatus[fileIdx] = "done";
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
                setState(() => serveStatus[fileIdx] = "error");
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

    // Awtomatikong usabon ang color pag-send (classical chameleon effect)
    appThemeColor.value =
        kClassicalPalette[Random().nextInt(kClassicalPalette.length)];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("The Salon Is Open"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GoldDivider(width: 40),
              const SizedBox(height: 12),
              Text(
                  "The salon now receives guests at\nhttp://$localIpAddress:$p2pPort\n\nMotif ${themeToHex(appThemeColor.value)} shall adorn the receiver's salon.\n\nBrowsers may also partake of the collection.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.6)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("GRACIAS"),
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
        title: const Text("Enter a Salon"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoldDivider(width: 36),
            const SizedBox(height: 10),
            const Text(
              "Inscribe the host's address, as displayed upon their salon wall:",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Host Address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Decline",
                  style: TextStyle(color: kStoneGrey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text("ENTER"),
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
    return Scaffold(
      backgroundColor: kIvory,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.username.toUpperCase(),
                style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700)),
            Text("PRIVATE SALON",
                style: classicalSmallCaps(
                    size: 9, color: const Color(0xFFC6A15B))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, size: 22),
            onPressed: _openColorPicker,
            tooltip: "Atelier Palette",
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 22),
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
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TRANSFER SALON",
                        style: classicalSmallCaps(
                            size: 10, color: kGoldDeep)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text("WiFi / Hotspot"),
                          selected: transferMode == "WiFi/Hotspot",
                          selectedColor: kCharcoal,
                          labelStyle: TextStyle(
                            color: transferMode == "WiFi/Hotspot"
                                ? const Color(0xFFF3EAD3)
                                : kCharcoal,
                            fontFamily: 'Georgia',
                            fontSize: 12,
                          ),
                          onSelected: (val) =>
                              setState(() => transferMode = "WiFi/Hotspot"),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("Bluetooth"),
                          selected: transferMode == "Bluetooth",
                          selectedColor: kCharcoal,
                          labelStyle: TextStyle(
                            color: transferMode == "Bluetooth"
                                ? const Color(0xFFF3EAD3)
                                : kCharcoal,
                            fontFamily: 'Georgia',
                            fontSize: 12,
                          ),
                          onSelected: (val) =>
                              setState(() => transferMode = "Bluetooth"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (transferMode == "Bluetooth")
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E4C3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kGold, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: kGoldDeep),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Bluetooth is not yet received in this salon. Please return to WiFi / Hotspot.",
                        style: TextStyle(
                            fontSize: 12, color: kCharcoalSoft, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kCharcoal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGoldDeep, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serverRunning
                            ? "SALON OPEN"
                            : "SALON ADDRESS",
                        style: classicalSmallCaps(
                            size: 9,
                            color: const Color(0xFFC6A15B)),
                      ),
                      Text(
                        serverRunning
                            ? "Receivers may now enter"
                            : transferMode,
                        style: const TextStyle(
                            color: Color(0xFFF3EAD3), fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGold, width: 1),
                    ),
                    child: Text("$localIpAddress:$p2pPort",
                        style: const TextStyle(
                            color: Color(0xFFF3EAD3),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.6)),
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
                        color: Color(0xFF2F4A3C), size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text("The salon is open — receivers may enter.",
                          style: TextStyle(
                              fontSize: 12, color: kCharcoalSoft)),
                    ),
                    TextButton.icon(
                      onPressed: _stopServer,
                      icon: const Icon(Icons.stop_circle_outlined,
                          size: 16, color: Color(0xFF5C1F24)),
                      label: const Text("Close",
                          style: TextStyle(
                              color: Color(0xFF5C1F24),
                              fontFamily: 'Georgia',
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            // BAG-O: Send/Upload progress card (sender side)
            if (serverRunning && servedSnapshot.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: kCharcoal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kGold, width: 1),
                            ),
                            child: const Icon(Icons.upload_outlined,
                                size: 16,
                                color: Color(0xFFF3EAD3)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "DISPATCH LEDGER",
                                  style: classicalSmallCaps(
                                      size: 9, color: kGoldDeep),
                                ),
                                Text(
                                  "$serveDoneCount of ${servedSnapshot.length} delivered",
                                  style: classicalHeading(size: 13),
                                ),
                              ],
                            ),
                          ),
                          if (lastClientIp.isNotEmpty)
                            Text("→ $lastClientIp",
                                style: const TextStyle(
                                    fontSize: 11, color: kStoneGrey)),
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                size: 18, color: kGoldDeep),
                            tooltip: "Reset progress",
                            onPressed: _resetServeProgress,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: servedSnapshot.isEmpty
                            ? 0.0
                            : serveDoneCount / servedSnapshot.length,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          itemCount: servedSnapshot.length,
                          itemBuilder: (context, i) {
                            final name =
                                baseNameOf(servedSnapshot[i].path);
                            final pct =
                                (serveProgress[i] * 100).toStringAsFixed(0);
                            Widget trailing;
                            if (serveStatus[i] == "done") {
                              trailing = const Icon(Icons.check_circle,
                                  color: Color(0xFF2F4A3C), size: 18);
                            } else if (serveStatus[i] == "serving") {
                              trailing = Text("$pct%",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: kGoldDeep,
                                      fontFamily: 'Georgia'));
                            } else if (serveStatus[i] == "error") {
                              trailing = const Icon(Icons.error_outline,
                                  color: Color(0xFF5C1F24), size: 18);
                            } else {
                              trailing = const Icon(
                                  Icons.hourglass_empty,
                                  color: kStoneGrey, size: 18);
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Georgia'),
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ),
                                      trailing,
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  LinearProgressIndicator(
                                    value: serveStatus[i] == "waiting"
                                        ? 0.0
                                        : serveProgress[i],
                                    minHeight: 7,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  Text(
                                    serveStatus[i] == "done"
                                        ? "${formatBytes(serveTotals[i])} • Na-send"
                                        : serveStatus[i] == "serving"
                                            ? "${formatBytes(serveSent[i])} / ${formatBytes(serveTotals[i])}"
                                            : serveStatus[i] == "error"
                                                ? "Naputol — hulata mo-retry ang receiver"
                                                : "Naghulat ug receiver... (${formatBytes(serveTotals[i])})",
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
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
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text("COLLECTION",
                    style:
                        classicalSmallCaps(size: 10, color: kGoldDeep)),
                const SizedBox(width: 8),
                const Expanded(child: Divider(color: kGoldSoft)),
                Text("${userFiles.length} PIECES",
                    style:
                        classicalSmallCaps(size: 9, color: kStoneGrey)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kParchment,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGoldSoft, width: 1),
                ),
                child: userFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: kGoldSoft, width: 1.2),
                              ),
                              child: const Icon(
                                  Icons.folder_open_outlined,
                                  size: 28,
                                  color: kStoneGrey),
                            ),
                            const SizedBox(height: 10),
                            Text("The cabinet is empty",
                                style: classicalHeading(
                                    size: 13, color: kCharcoal)),
                            const SizedBox(height: 4),
                            Text("ADD FILES TO BEGIN",
                                style: classicalSmallCaps(size: 9)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: userFiles.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: kGoldSoft, indent: 56),
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kIvory,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: kGoldSoft, width: 1),
                              ),
                              child: const Icon(
                                  Icons.description_outlined,
                                  size: 20,
                                  color: kCharcoal),
                            ),
                            title: Text(
                                baseNameOf(userFiles[index].path),
                                style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                formatBytes(_fileSizeOf(
                                    userFiles[index])),
                                style: const TextStyle(
                                    fontSize: 11, color: kStoneGrey)),
                            trailing: IconButton(
                              icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFF5C1F24),
                                  size: 20),
                              onPressed: () => setState(
                                  () => userFiles.removeAt(index)),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("ADD"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _showConfirmDialog,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text("SEAL & SEND"),
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
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(_isReceiving
                    ? "RECEIVING..."
                    : "RECEIVE FROM SALON"),
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
      title: Text("Reception ($_doneCount/$totalFiles)",
          textAlign: TextAlign.center),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoldDivider(width: 36),
            const SizedBox(height: 12),
            // Overall progress
            Row(
              children: [
                Text("ENTIRE  ",
                    style:
                        classicalSmallCaps(size: 9, color: kGoldDeep)),
                Expanded(
                  child: LinearProgressIndicator(value: overall),
                ),
                const SizedBox(width: 8),
                Text("${(overall * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700)),
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
                        color: Color(0xFF2F4A3C), size: 20);
                  } else if (_status[i] == "error") {
                    trailing = const Icon(Icons.error_outline,
                        color: Color(0xFF5C1F24), size: 20);
                  } else if (_status[i] == "downloading") {
                    trailing = Text("$pct%",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: kGoldDeep,
                            fontFamily: 'Georgia'));
                  } else {
                    trailing = const Icon(Icons.hourglass_empty,
                        color: kStoneGrey, size: 20);
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
                                      fontSize: 13,
                                      fontFamily: 'Georgia'),
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
                              ? "${formatBytes(_totals[i])} • Received"
                              : _status[i] == "error"
                                  ? "Interrupted — please retry"
                                  : _status[i] == "waiting"
                                      ? "Awaiting... (${formatBytes(_totals[i])})"
                                      : "${formatBytes(_received[i])} / ${formatBytes(_totals[i])}",
                          style: const TextStyle(
                              fontSize: 11, color: kStoneGrey),
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
            child: const Text("Withdraw",
                style: TextStyle(color: Color(0xFF5C1F24))),
          ),
        if (_finished)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _doneCount),
            child: Text(_doneCount == totalFiles ? "GRACIAS" : "CLOSE"),
          ),
      ],
    );
  }
}
