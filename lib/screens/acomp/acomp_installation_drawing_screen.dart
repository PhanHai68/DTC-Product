import 'package:flutter/material.dart';

class AcompInstallationDrawingScreen extends StatelessWidget {
  const AcompInstallationDrawingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản vẽ lắp đặt')),
      backgroundColor: Colors.white,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.asset(
            'assets/images/So_do_lap_dat.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
