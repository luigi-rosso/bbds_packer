import 'dart:typed_data';

import 'package:bbds_packer/crc32.dart';
import 'package:test/test.dart';

void main() {
  test('change', () {
    {
      final crc = CRC32();
      crc.add(Uint8List.fromList([0x7, 0x31, 0x82]));
      expect(crc.value, 0x3FE52A29, reason: 'three byte test');
      crc.add(Uint8List.fromList([0x2, 0x22, 0x86, 0x2, 0x15, 0x20]));
      expect(crc.value, 0xE522F765, reason: 'six more byte test');
    }
  });
}
