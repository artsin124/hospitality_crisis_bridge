import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'firebase_options.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyanAccent, brightness: Brightness.dark),
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
  @override State<GuestPortal> createState() => _GuestPortalState();
}

class _GuestPortalState extends State<GuestPortal> {
  String scannedRoom = "NOT VERIFIED"; 
  bool isVerified = false;

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
          constrained: false, 
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 5.0,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('incidents').where('status', isEqualTo: 'RESPONDING').snapshots(),
            builder: (context, snapshot) {
              double staffX = 450.0; double staffY = 300.0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final staffData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                staffX = (staffData['staffX'] ?? 450.0).toDouble();
                staffY = (staffData['staffY'] ?? 300.0).toDouble();
              }
              return Stack(
                children: [
                  Image.asset('assets/images/floor_plan_r1.png'), // Check spelling!
                  _tacticalMarker(top: 210, left: 320, icon: Icons.fire_extinguisher, color: Colors.orangeAccent),
                  _tacticalMarker(top: 450, left: 150, icon: Icons.medical_services, color: Colors.redAccent),
                  _tacticalMarker(top: 50, left: 800, icon: Icons.exit_to_app, color: Colors.greenAccent, isExit: true),
                  _tacticalMarker(top: staffY, left: staffX, icon: Icons.person_pin_circle, color: Colors.cyanAccent, isStaff: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tacticalMarker({required double top, required double left, required IconData icon, required Color color, bool isStaff = false, bool isExit = false}) {
    return Positioned(top: top, left: left, child: Column(children: [Icon(icon, color: color, size: isStaff ? 28 : 20), if (isExit) const Text("EXIT", style: TextStyle(color: Colors.greenAccent, fontSize: 8))]));
  }

  Future<void> _dispatchSOS(BuildContext context, String alertType) async {
    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SCAN QR FIRST!")));
      return;
    }
    await _globalPlayer.play(AssetSource('sounds/ping.mp3'));
    await FirebaseFirestore.instance.collection('incidents').add({
      'type': alertType, 'location': scannedRoom, 'timestamp': FieldValue.serverTimestamp(), 'status': 'ACTIVE',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(isVerified ? "LOC: $scannedRoom" : "MANALI NODE", style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
        actions: [IconButton(icon: const Icon(Icons.admin_panel_settings_rounded), onPressed: () => Navigator.pushNamed(context, '/login'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            if (!isVerified)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerPage()));
                  if (result != null) setState(() { scannedRoom = result; isVerified = true; });
                },
                icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text("ACTIVATE TERMINAL"),
              ),
            const Icon(Icons.podcasts, color: Colors.redAccent, size: 45),
            const Text("HIMALAYAN CREST", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),

            // 📡 LIVE STATUS BANNER: Linking Guest to Staff Actions
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  // 🚀 Targeted Query: Only shows info for the specific room scanned
                  .where('location', isEqualTo: scannedRoom) 
                  .where('status', isEqualTo: 'RESPONDING')
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
                            "STAFF ${data['staffName'] ?? 'RESCUE'} EN ROUTE. ETA: ${data['eta'] ?? '--'} MINS", 
                            style: const TextStyle(
                              color: Colors.cyanAccent, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 11
                            )
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Jab tak koi staff respond nahi kar raha, banner hidden rahega
                return const SizedBox.shrink(); 
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, String label, Color color, IconData icon, 
        {double customHeight = 120, bool isBigger = false}) {
      return InkWell(
        onTap: () => _dispatchSOS(context, label),
        child: Container(
          height: customHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(isVerified ? 0.4 : 0.1), width: isBigger ? 2 : 1),
            gradient: LinearGradient(colors: [color.withOpacity(isVerified ? 0.1 : 0.02), Colors.transparent]),
          ),
          child: Opacity(
            opacity: isVerified ? 1.0 : 0.3, 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              mainAxisSize: MainAxisSize.min, // 🚀 Fixes the overflow
              children: [
                Icon(icon, color: color, size: isBigger ? 45 : 30), 
                const SizedBox(height: 5),
                FittedBox( // 🚀 Text ko squeeze hone se bachayega
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isBigger ? 20 : 14)),
                ),
              ],
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
  final _email = TextEditingController(); final _pass = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("STAFF AUTH")),
      body: Padding(padding: const EdgeInsets.all(32.0), child: Column(children: [
        TextField(controller: _email, decoration: const InputDecoration(labelText: "Staff ID")),
        TextField(controller: _pass, decoration: const InputDecoration(labelText: "Key"), obscureText: true),
        const SizedBox(height: 40),
        ElevatedButton(onPressed: () async {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
            Navigator.pushReplacementNamed(context, '/staff');
          } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DENIED"))); }
        }, child: const Text("AUTHORIZE")),
      ])),
    );
  }
}

class StaffCommandCenter extends StatelessWidget {
  const StaffCommandCenter({super.key});
  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text("MANALI HQ"), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushReplacementNamed(context, '/')))]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('incidents').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docChanges.isNotEmpty) {
            for (var change in snapshot.data!.docChanges) {
              if (change.type == DocumentChangeType.added && !snapshot.data!.metadata.isFromCache) {
                _globalPlayer.stop().then((_) => _globalPlayer.play(AssetSource('sounds/siren.mp3')));
              }
            }
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index]; var data = doc.data() as Map<String, dynamic>;
              bool isActive = data['status'] == 'ACTIVE';
              return Card(
                color: isActive ? Colors.redAccent.withOpacity(0.1) : Colors.white10,
                child: ListTile(
                  title: Text(data['type'], style: TextStyle(color: isActive ? Colors.redAccent : Colors.cyanAccent)),
                  subtitle: Text("LOC: ${data['location']}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (data['status'] == 'RESPONDING') ...[
                      IconButton(icon: const Icon(Icons.remove), onPressed: () {
                        int cur = data['eta'] ?? 5; if (cur > 0) doc.reference.update({'eta': cur - 1});
                      }),
                      Text("${data['eta']}m"),
                      IconButton(icon: const Icon(Icons.add), onPressed: () {
                        int cur = data['eta'] ?? 5; doc.reference.update({'eta': cur + 1});
                      }),
                    ] else ElevatedButton(onPressed: () => doc.reference.update({'status': 'RESPONDING', 'staffName': 'Rahul S.', 'eta': 5, 'staffX': 220.0, 'staffY': 180.0}), child: const Text("ACK")),
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.greenAccent), onPressed: () => doc.reference.delete()),
                  ]),
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
      appBar: AppBar(title: const Text("SCAN ROOM QR")),
      body: MobileScanner(onDetect: (capture) {
        for (final barcode in capture.barcodes) { if (barcode.rawValue != null) { Navigator.pop(context, barcode.rawValue); break; } }
      }),
    );
  }
}