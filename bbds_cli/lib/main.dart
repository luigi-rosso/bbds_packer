import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:bbds_packer/drum_kit.dart';
import 'package:bbds_packer/drum_kit_packer.dart';
import 'package:bbds_packer/file_io.dart';
import 'package:yaml/yaml.dart';

class CliFileIO extends FileIO {
  @override
  Uint8List? load(String filename) {
    try {
      return File(filename).readAsBytesSync();
    } on FileSystemException catch (error) {
      print('Failed to load $filename: $error');
      return null;
    }
  }

  @override
  void save(String filename, Uint8List bytes) {
    File(filename).writeAsBytesSync(bytes);
  }
}

Future<void> main(List<String> args) async {
  var parser = ArgParser();
  parser.addOption('file');
  var results = parser.parse(args);
  String? filename = results['file'] as String?;
  if (filename == null) {
    print('missing arugment --file');
    return;
  }
  String pathTo = '';
  if (filename.lastIndexOf('/') != -1) {
    var lastSlash = filename.lastIndexOf('/');
    pathTo = filename.substring(0, lastSlash + 1);
    filename = filename.substring(lastSlash + 1);
  }

  String outFilename;
  if (filename.lastIndexOf('.') != -1) {
    var lastDot = filename.lastIndexOf('.');
    outFilename = filename.substring(0, lastDot);
    outFilename += '.drm';
  } else {
    outFilename = '$filename.drm';
  }

  var io = CliFileIO();
  var file = File('$pathTo$filename');
  var yaml = file.readAsStringSync();
  dynamic data = loadYaml(yaml);
  if (data is YamlMap) {
    var kit = Drumkit(data);
    await kit.loadSamples(io, pathTo);

    var packer = DrumkitPacker(kit);
    packer.write(io, '$pathTo$outFilename');
    print('Wrote $pathTo$outFilename');
  }
}
