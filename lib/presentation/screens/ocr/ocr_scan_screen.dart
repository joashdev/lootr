import 'package:flutter/material.dart';

class OcrScanScreen extends StatelessWidget {
  const OcrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: const Center(child: Text('OCR Scan Camera')),
    );
  }
}
