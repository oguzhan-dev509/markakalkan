import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:markakalkan/core/theme/markakalkan_theme.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _hasDetectedCode = false;

  void _handleDetection(BarcodeCapture capture) {
    if (_hasDetectedCode || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue?.trim();

    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    _hasDetectedCode = true;

    Navigator.of(context).pop(rawValue.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'QR Kodu Tara',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _handleDetection),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.45),
                  width: 42,
                ),
              ),
              child: Center(
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: MarkaKalkanTheme.teal, width: 4),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 34,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Ürün üzerindeki MarkaKalkan QR kodunu çerçevenin '
                'içine getirin. Kod algılandığında otomatik olarak '
                'Marka Dedektifi’ne aktarılacaktır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
