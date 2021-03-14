import 'dart:typed_data';

abstract class FileIO {
  Uint8List? load(String filename);
  void save(String filename, Uint8List bytes);
}