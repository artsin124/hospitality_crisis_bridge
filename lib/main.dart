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

  // 🗺️ TACTICAL MAP ENGINE: Indoor Schematic View (Zoom & Pan Enabled)
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
          constrained: false, // 🚀 Magic Line: Isse map dabbe ke bahar "expand" hoga
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 5.0,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('incidents')
                .where('status', isEqualTo: 'RESPONDING')
                .snapshots(),
            builder: (context, snapshot) {
              // Default position agar data na mile
              double staffX = 450.0; 
              double staffY = 300.0;

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final staffData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                staffX = (staffData['staffX'] ?? 450.0).toDouble();
                staffY = (staffData['staffY'] ?? 300.0).toDouble();
              }

              return Stack(
                children: [
                  // 🗺️ High-Resolution Floor Plan
                  Image.asset(
                    'assets/images/floor_plan_r1.png',
                    // Width/Height mat dena, image ko natural size lene do
                  ),

                  // 🔥 Tactical Assets (Inhe image ke pixels ke hisaab se adjust kar lena)
                  _tacticalMarker(top: 210, left: 30, icon: Icons.fire_extinguisher, color: Colors.orangeAccent),
                  _tacticalMarker(top: 450, left: 150, icon: Icons.medical_services, color: Colors.redAccent),
                  _tacticalMarker(top: 50, left: 800, icon: Icons.exit_to_app, color: Colors.greenAccent, isExit: true),
                  
                  // 📍 Live Staff Node (Ab ye database se move hoga)
                  _tacticalMarker(top: staffY, left: staffX, icon: Icons.person_pin_circle, color: Colors.cyanAccent, isStaff: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  

  // 🛠️ Marker Helper: Precision Positioning
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

  Future<void> _dispatchSOS(BuildContext context, String alertType) async {
    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          content: Text("ACCESS DENIED: Please scan Room QR to verify location.", 
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    try {
      await _globalPlayer.play(AssetSource('sounds/ping.mp3'));
      await FirebaseFirestore.instance.collection('incidents').add({
        'type': alertType,
        'location': scannedRoom, 
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'ACTIVE',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent.shade700, content: Text("CRITICAL: $alertType DISPATCHED FROM $scannedRoom")),
      );
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
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const QRScannerPage())
                    );
                    if (result != null) {
                      setState(() {
                        scannedRoom = result;
                        isVerified = true;
                      });
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text("ACTIVATE ROOM TERMINAL", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

            const Icon(Icons.podcasts, color: Colors.redAccent, size: 45),
            const Text("HIMALAYAN CREST", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const Text("MANALI ALPINE NODE", style: TextStyle(fontSize: 10, letterSpacing: 5, color: Colors.cyanAccent)),
            const SizedBox(height: 20),

            // 📡 LIVE STATUS BANNER
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
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
                        Expanded(child: Text("STAFF ${data['staffName'] ?? ''} EN ROUTE. ETA: ${data['eta'] ?? '--'} MINS", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // 🗺️ TACTICAL MAP DISPLAY (Verified Only)
            if (isVerified) _buildTacticalMap(),

            _actionTile(context, "FIRE", Colors.orangeAccent, Icons.local_fire_department, customHeight: 160, isBiggerText: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _actionTile(context, "MEDICAL", Colors.redAccent, Icons.medical_services, customHeight: 140)),
                const SizedBox(width: 15),
                Expanded(child: _actionTile(context, "SECURITY", Colors.blueAccent, Icons.shield_outlined, customHeight: 140)),
              ],
            ),
            const SizedBox(height: 20),
            _actionTile(context, "UTILITY FAILURE", Colors.yellowAccent, Icons.bolt, customHeight: 70, isSleek: true),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, String label, Color color, IconData icon, 
      {double customHeight = 80, bool isBiggerText = false, bool isSleek = false}) {
    return InkWell(
      onTap: () => _dispatchSOS(context, label),
      child: Container(
        height: customHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(isVerified ? 0.4 : 0.1), width: isBiggerText ? 3 : 1.5),
          gradient: LinearGradient(colors: [color.withOpacity(isVerified ? 0.15 : 0.05), Colors.transparent]),
        ),
        child: Opacity(
          opacity: isVerified ? 1.0 : 0.3, 
          child: isSleek 
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color), const SizedBox(width: 10), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: isBiggerText ? 50 : 35), const SizedBox(height: 10), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isBiggerText ? 24 : 16))]),
        ),
      ),
    );
  }
}

// ==========================================
// 🛡️ STAFF LOGIN GATEWAY
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
        child: Column(
          children: [
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 📡 STAFF COMMAND: MANALI HQ DASHBOARD
// ==========================================
// 📍 Replace your StaffCommandCenter with this Tactical Version:

class StaffCommandCenter extends StatelessWidget {
  const StaffCommandCenter({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔐 Security Guard
    if (FirebaseAuth.instance.currentUser == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("MANALI HQ DASHBOARD", style: TextStyle(letterSpacing: 2, fontSize: 14)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), 
            onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushReplacementNamed(context, '/'))
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('incidents').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          // 🔔 SIREN TRIGGER: Fortified Logic
          if (snapshot.hasData && snapshot.data!.docChanges.isNotEmpty) {
           for (var change in snapshot.data!.docChanges) {
            // Condition: Naya doc + Live Ingress (Not from initial cache load)
             if (change.type == DocumentChangeType.added && !snapshot.data!.metadata.isFromCache) {

                // 🚀 THE FIX: Stop current audio before triggering new one
               _globalPlayer.stop().then((_) {
                  _globalPlayer.play(AssetSource('sounds/siren.mp3')).catchError((e) {
                   debugPrint("Audio Concurrency Error: $e");
                 });
               });
      
                debugPrint("🚨 NEW CRITICAL ALERT: Siren Triggered");
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
              bool isActive = data['status'] == 'ACTIVE';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.redAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isActive ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.2)),
                ),
                child: ListTile(
                  title: Text(data['type'], style: TextStyle(fontWeight: FontWeight.w900, color: isActive ? Colors.redAccent : Colors.cyanAccent)),
                  subtitle: Text("LOC: ${data['location']}\nSTATUS: ${data['status']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  trailing: isActive 
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                        onPressed: () => doc.reference.update({
                          'status': 'RESPONDING',
                          'staffName': 'Rahul S.',
                          'eta': 5,
                          'staffX': 220.0, 
                          'staffY': 180.0,
                        }),
                        child: const Text("ACKNOWLEDGE"),
                      )
                    : const Icon(Icons.verified_user, color: Colors.greenAccent),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 🔍 QR SCANNER DELEGATE
// ==========================================
class QRScannerPage extends StatelessWidget {
  const QRScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SCAN ROOM TOKEN"), 
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
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