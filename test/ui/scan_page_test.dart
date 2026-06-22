import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/scan_page.dart';

void main() {
  test('firstBarcodeValue 取首个非空', () {
    expect(
      firstBarcodeValue(<String?>['', null, 'https://x.com', 'y']),
      'https://x.com',
    );
  });

  test('firstBarcodeValue 全空返回 null', () {
    expect(firstBarcodeValue(<String?>[null, '']), isNull);
  });
}
