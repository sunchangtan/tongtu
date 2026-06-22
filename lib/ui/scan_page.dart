import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 从扫码结果的原始值列表取首个非空文本（纯函数，可单测，不依赖相机）。
String? firstBarcodeValue(List<String?> rawValues) {
  for (final String? v in rawValues) {
    if (v != null && v.isNotEmpty) {
      return v;
    }
  }
  return null;
}

/// 扫码二维码页：扫到首个非空条码即 `Navigator.pop` 返回其文本（订阅 URL 或配置内容）。
/// 相机由 `mobile_scanner` 提供；扫码结果处理逻辑见 [firstBarcodeValue]（已单测）。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _popped = false; // 防多次条码回调重复 pop

  void _onDetect(BarcodeCapture capture) {
    if (_popped) {
      return;
    }
    final String? value = firstBarcodeValue(
      capture.barcodes.map((Barcode b) => b.rawValue).toList(),
    );
    if (value != null) {
      _popped = true;
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码二维码')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
