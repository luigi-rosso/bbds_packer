import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:bbds_packer/drum_kit.dart';
import 'package:bbds_packer/drum_kit_packer.dart';
import 'package:bbds_packer/file_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

void main() {
  js.context['filesDropped'] = (dynamic test) {
    if (test is! js.JsArray) {
      return;
    }
    List<DroppedFile> droppedFiles = [];
    for (final item in test as js.JsArray) {
      if (item is! js.JsObject) {
        continue;
      }
      var object = item as js.JsObject;
      var filename =
          object['filename'] is String ? object['filename'] as String : null;
      var bytes =
          object['bytes'] is Uint8List ? object['bytes'] as Uint8List : null;
      if (filename != null && bytes != null) {
        droppedFiles.add(DroppedFile(filename, bytes));
      }
    }
    filesDropped?.call(droppedFiles);
  };
  runApp(MyApp());
}

DroppedFilesCallback filesDropped;

typedef DroppedFilesCallback = void Function(Iterable<DroppedFile> files);

class DroppedFile {
  final String filename;
  final Uint8List bytes;

  DroppedFile(this.filename, this.bytes);

  @override
  String toString() => 'File: $filename ${bytes.length}';
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BBds Packer',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const MyHomePage(title: 'BeatBuddy DrumKit Packer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class WebFileIO extends FileIO {
  final Iterable<DroppedFile> files;

  WebFileIO(this.files);

  @override
  Uint8List load(String filename) {
    for (final file in files) {
      if (file.filename == filename) {
        return file.bytes;
      }
    }
    return null;
  }

  @override
  void save(String filename, Uint8List bytes) {
    js.context.callMethod(
      'saveAs',
      <dynamic>[
        html.Blob(
          <dynamic>[bytes],
        ),
        filename,
      ],
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  Iterable<DroppedFile> droppedFiles;
  bool _isPacking = false;
  String _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                js.context.callMethod(
                  'travel',
                  <dynamic>[
                    'https://github.com/luigi-rosso/bbds_packer',
                  ],
                );
              },
              child: const Text(
                'See details here.',
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _error != null
                ? Text(
                    _error,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  )
                : _isPacking
                    ? const Text(
                        'Packing...',
                        style: TextStyle(
                          fontSize: 20,
                        ),
                      )
                    : const Text(
                        'Drag and drop a folder containing your drumset '
                        'definition file and wav files. The drm file will be '
                        'generated and downloaded.',
                        style: TextStyle(
                          fontSize: 20,
                        ),
                      ),
            const SizedBox(height: 20),
            const Text(
              'No files are uploaded. All files dropped on this window are '
              'processed locally in your browser\'s memory to pack the drm'
              'file. If you have concerns, you can monitor the network panel '
              'to verify.',
              style: TextStyle(
                fontSize: 12,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    filesDropped = (files) async {
      setState(() {
        droppedFiles = files;
        _error = null;
        _isPacking = true;
      });

      await Future<bool>.delayed(
          const Duration(milliseconds: 20), () => _packFiles(files));

      setState(() {
        _isPacking = false;
      });
    };
    super.initState();
  }

  Future<bool> _packFiles(Iterable<DroppedFile> files) async {
    for (final file in files) {
      if (file.filename.endsWith('.yaml')) {
        String pathTo = '';
        String filename = file.filename;
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

        var yaml = const Utf8Decoder().convert(file.bytes);
        dynamic data = loadYaml(yaml);
        if (data is YamlMap) {
          var io = WebFileIO(files);
          var kit = Drumkit(data);
          await kit.loadSamples(io, pathTo);

          var packer = DrumkitPacker(kit);
          packer.write(io, '$outFilename');
          return true;
        }
        _error = 'Bad formatting in yaml file.';
        return false;
      }
    }
    _error = 'Failed to find valid yaml file.';
    return false;
  }
}
