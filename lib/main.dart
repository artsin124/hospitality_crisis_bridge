import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'firebase_options.dart';
import 'dart:async';

// 📡 GLOBAL ACOUSTIC ENGINE: Singleton instance to prevent audio race conditions
final AudioPlayer _globalPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HospitalityBridgeApp());
}

class HospitalityBridgeApp extends StatelessWidget {
  const HospitalityBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Himalayan Crest Bridge',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent, 
          brightness: Brightness.dark
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GuestPortal(), 
        '/login': (context) => const StaffLoginGateway(),
        '/staff': (context) => const StaffCommandCenter(),
      },
    );
  }
}

// ==========================================
// 🏔️ GUEST PORTAL: THE ALPINE INGRESS
// ==========================================
class GuestPortal extends StatefulWidget {
  const GuestPortal({super.key});
  @override
  State<GuestPortal> createState() => _GuestPortalState();
}

class _GuestPortalState extends State<GuestPortal> {
  String scannedRoom = "NOT VERIFIED"; 
  bool isVerified = false;

  // 🗺️ MAP RESOLVER: Localizing schematics based on QR/URL Ingress
  String _getMapAsset() {
    if (!isVerified) return 'assets/images/outside_view.png';

    // Room ID 'G' se start ho (e.g. G101) -> Ground Floor
    if (scannedRoom.toUpperCase().startsWith('G')) {
      return 'assets/images/ground_floor.png';
    } 
    // Room ID '1' se start ho (e.g. 101) -> 1st Floor
    else if (scannedRoom.startsWith('1')) {
      return 'assets/images/first_floor.png';
    } 
    // Default or Exterior View
    return 'assets/images/outside_view.png';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🕵️ Sabse pehle poora URL print karo debug console mein
      final String currentUrl = Uri.base.toString();
      print("🔎 DEBUG URL: $currentUrl");

      // Check if 'room' exists anywhere in the string
      if (currentUrl.contains('room=')) {
        try {
          // Splitting logic
          final parts = currentUrl.split('room=');
          if (parts.length > 1) {
            final roomId = parts[1].split('&')[0].split('#')[0];
            print("🎯 EXTRACTED ROOM: $roomId");
            
            setState(() {
              scannedRoom = roomId;
              isVerified = true;
            });
          }
        } catch (e) {
          print("❌ PARSING ERROR: $e");
        }
      } else {
        print("❓ NO ROOM PARAMETER FOUND");
      }
    });
  }

  // 🗺️ TACTICAL MAP ENGINE: Indoor Schematic View (Zoom & Pan)
  Widget _buildTacticalMap() {
    return Container(
      height: 350,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InteractiveViewer(
          constrained: false, // 🚀 Allows map to expand beyond viewport for panning
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 5.0,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('incidents')
                .where('location', isEqualTo: scannedRoom)
                .where('status', isEqualTo: 'RESPONDING')
                .orderBy('timestamp', descending: true) // 🕒 Latest Staff movement
                .snapshots(),
            builder: (context, snapshot) {
              double staffX = 320.0; 
              double staffY = 525.0;

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final staffData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                staffX = (staffData['staffX'] ?? 320.0).toDouble();
                staffY = (staffData['staffY'] ?? 525.0).toDouble();
              }

              return Stack(
                children: [
                  Image.asset(
                    _getMapAsset(), 
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 1000, 
                      height: 800, 
                      color: Colors.grey.withOpacity(0.1),
                      child: const Center(child: Text("MAP ASSET 404")),
                    ),
                  ),
                  _tacticalMarker(
                    top: staffY, 
                    left: staffX, 
                    icon: Icons.person_pin_circle, 
                    color: Colors.redAccent, 
                    isStaff: true
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tacticalMarker({required double top, required double left, required IconData icon, required Color color, bool isStaff = false, bool isExit = false}) {
    return Positioned(
      top: top,
      left: left,
      child: Column(
        children: [
          Icon(icon, color: color, size: isStaff ? 28 : 20),
          if (isExit) const Text("EXIT", style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _dispatchSOS(String alertType) async {
    if (!isVerified) return;
    try {
      await _globalPlayer.play(AssetSource('sounds/ping.mp3'));
      await FirebaseFirestore.instance.collection('incidents').add({
        'type': alertType,
        'location': scannedRoom, 
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'ACTIVE',
      });
    } catch (e) {
      debugPrint("Telemetry Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(isVerified ? "LOC: $scannedRoom" : "UNVERIFIED NODE", 
            style: const TextStyle(fontSize: 12, color: Colors.cyanAccent, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.cyanAccent),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            if (!isVerified)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerPage()));
                  if (result != null) setState(() { scannedRoom = result; isVerified = true; });
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text("ACTIVATE ROOM TERMINAL", style: TextStyle(fontWeight: FontWeight.bold)),
              ),

            const SizedBox(height: 20),
            const Icon(Icons.podcasts, color: Colors.redAccent, size: 45),
            const Text("HIMALAYAN CREST", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const Text("MANALI ALPINE NODE", style: TextStyle(fontSize: 10, letterSpacing: 5, color: Colors.cyanAccent)),
            const SizedBox(height: 20),

            // 📡 LIVE ETA BANNER: Isse guest ko staff ki location pata chalegi
            StreamBuilder<QuerySnapshot>(
              // 🚀 Dynamic Stream: Sirf isi room ka active responding incident uthao
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .where('location', isEqualTo: scannedRoom) // 🎯 Room filter
                  .where('status', isEqualTo: 'RESPONDING')  // 🎯 Sirf responding wala
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyanAccent, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_problem_rounded, color: Colors.cyanAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "STAFF ${data['staffName'] ?? ''} EN ROUTE. ETA: ${data['eta'] ?? '--'} MINS", 
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink(); // Jab tak koi respond na kare, banner hidden rahega
              },
            ),

            if (isVerified) _buildTacticalMap(),

            _actionTile("FIRE", Colors.orangeAccent, Icons.local_fire_department, h: 160, b: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _actionTile("MEDICAL", Colors.redAccent, Icons.medical_services, h: 140)),
                const SizedBox(width: 15),
                Expanded(child: _actionTile("SECURITY", Colors.blueAccent, Icons.shield_outlined, h: 140)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(String label, Color color, IconData icon, {double h = 80, bool b = false}) {
    return InkWell(
      onTap: () => _dispatchSOS(label),
      child: Container(
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(isVerified ? 0.4 : 0.1), width: b ? 3 : 1.5),
          gradient: LinearGradient(colors: [color.withOpacity(isVerified ? 0.15 : 0.05), Colors.transparent]),
        ),
        child: Opacity(
          opacity: isVerified ? 1.0 : 0.3, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Icon(icon, color: color, size: b ? 50 : 35),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: b ? 24 : 16))
            ]
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🛡️ STAFF LOGIN & COMMAND CENTER
// ==========================================
class StaffLoginGateway extends StatefulWidget {
  const StaffLoginGateway({super.key});
  @override State<StaffLoginGateway> createState() => _StaffLoginGatewayState();
}

class _StaffLoginGatewayState extends State<StaffLoginGateway> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("COMMAND AUTH")),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: "Staff ID")),
          TextField(controller: _pass, decoration: const InputDecoration(labelText: "Access Key"), obscureText: true),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
                if (mounted) Navigator.pushReplacementNamed(context, '/staff');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AUTH DENIED")));
              }
            },
            child: const Text("AUTHORIZE", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }
}

class StaffCommandCenter extends StatelessWidget {
  const StaffCommandCenter({super.key});
  // 📍 ROOM DIRECTORY: PNG pixels ke hisaab se coordinates
  static const Map<String, Offset> roomDirectory = {
    'G01': Offset(400.0, 420.0),
    '101': Offset(400.0, 445.0),
    'G12': Offset(900.0, 525.0),
  };
// 🛠️ INCIDENT CONTROL MODAL: ETA updates aur Resolution handle karne ke liye
  void _openIncidentPanel(BuildContext context, DocumentSnapshot doc) {
    final TextEditingController etaController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("INCIDENT CONTROL", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: etaController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Enter ETA (mins)", 
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          // 🚀 Action 1: Dispatch Staff with ETA
          TextButton(
            onPressed: () {
              // 1. Target dhundo (e.g., G01 or 101)
              final incidentData = doc.data() as Map<String, dynamic>;
              String roomName = incidentData['location'] ?? 'G01';
              Offset target = roomDirectory[roomName] ?? const Offset(400.0, 420.0);

              // 2. Starting Point (Utility Room)
              double currentX = 320.0;
              double currentY = 525.0;

              // 3. Initial Push to Firestore
              doc.reference.update({
                'status': 'RESPONDING',
                'staffName': 'Staff',
                'eta': etaController.text,
                'staffX': currentX,
                'staffY': currentY,
              });
              
              Navigator.pop(context);

              // 🚀 THE TRACKER ENGINE: Har 300ms mein coordinates update honge
              Timer.periodic(const Duration(milliseconds: 300), (timer) {
                if ((currentX - target.dx).abs() > 4) {
                  currentX += (target.dx > currentX) ? 6 : -6;
                }
                if ((currentY - target.dy).abs() > 4) {
                  currentY += (target.dy > currentY) ? 6 : -6;
                }

                // 📡 Live Broadcast to Guest Portal
                doc.reference.update({'staffX': currentX, 'staffY': currentY});

                // 🏁 Destination reached?
                if ((currentX - target.dx).abs() <= 5 && (currentY - target.dy).abs() <= 5) {
                  timer.cancel();
                }
              });
            },
            child: const Text("SEND STAFF & ETA"),
          ),
          // ✅ Action 2: Resolve & Clear Dashboard
          TextButton(
            onPressed: () {
              doc.reference.update({'status': 'RESOLVED'});
              Navigator.pop(context);
            },
            child: const Text("RESOLVE & DISMISS", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("MANALI HQ DASHBOARD"),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), 
            onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushReplacementNamed(context, '/'))
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🚀 Replace Line 369 with this:
        stream: FirebaseFirestore.instance
            .collection('incidents')
            .where('status', isNotEqualTo: 'RESOLVED') 
            .snapshots(),
        builder: (context, snapshot) {
          // 🔔 SIREN LOGIC: Fortified to prevent "already playing" crashes
          if (snapshot.hasData && snapshot.data!.docChanges.isNotEmpty) {
            for (var change in snapshot.data!.docChanges) {
              if (change.type == DocumentChangeType.added && !snapshot.data!.metadata.isFromCache) {
                _globalPlayer.stop().then((_) => _globalPlayer.play(AssetSource('sounds/siren.mp3')));
              }
            }
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              bool active = data['status'] == 'ACTIVE';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: active ? Colors.redAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: active ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.2)),
                ),
                child: ListTile(
                  title: Text(data['type'], style: TextStyle(fontWeight: FontWeight.w900, color: active ? Colors.redAccent : Colors.cyanAccent)),
                  subtitle: Text("LOC: ${data['location']}\nSTATUS: ${data['status']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  trailing: active 
                    ? ElevatedButton(
                        // 🚀 Replace the old onPressed with this single line:
                        onPressed: () => _openIncidentPanel(context, doc),
                        child: const Text("ACKNOWLEDGE"),
                      )
                    : const Icon(Icons.verified, color: Colors.greenAccent),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class QRScannerPage extends StatelessWidget {
  const QRScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SCAN ROOM TOKEN"), backgroundColor: Colors.black),
      body: MobileScanner(
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue); 
              break;
            }
          }
        },
      ),
    );
  }
}