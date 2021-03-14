import 'dart:typed_data';
import 'package:bbds_packer/binary_reader.dart';

class WavChunk {
  String id;
  int size;
  int end;

  factory WavChunk(BinaryReader reader) {
    var id = reader.readStringBytes(4);
    var size = reader.readUint32();
    return WavChunk._(id, size, reader.position + size);
  }

  WavChunk._(this.id, this.size, this.end);
}

class Wav {
  late int numChannels;
  late int sampleRate;
  late int byteRate;
  late int blockAlign;
  late int bitsPerSample;
  late Uint8List rawSamples;

  int get numSamples => (rawSamples.length / (bitsPerSample / 8)).ceil();

  bool load(Uint8List bytes) {
    var reader = BinaryReader.fromList(
      bytes,
      endian: Endian.little,
    );
    var chunk = WavChunk(reader);
    if (chunk.id != 'RIFF') {
      return false;
    }
    var format = reader.readStringBytes(4);
    if (format != 'WAVE') {
      return false;
    }
    // Now just continuously read remaining chunks.
    bool gotFormat = false, gotData = false;
    while (reader.remainingBytes > 8) {
      var subChunk = WavChunk(reader);
      switch (subChunk.id) {
        case 'fmt ':
          if (!_readFormat(subChunk, reader)) {
            return false;
          }
          gotFormat = true;
          break;
        case 'data':
          if (!_readData(subChunk, reader)) {
            return false;
          }
          gotData = true;
          break;
      }
      reader.readIndex = subChunk.end;
    }
    reader.readIndex = chunk.end;

    if (gotFormat && gotData) {
      return true;
    }
    return false;
  }

  bool _readFormat(WavChunk chunk, BinaryReader reader) {
    var audioFormat = reader.readUint16();
    if (audioFormat != 1) {
      // Format isn't PCM.
      return false;
    }
    numChannels = reader.readUint16();
    if (numChannels != 1 && numChannels != 2) {
      // Only support mono/stereo
      return false;
    }
    sampleRate = reader.readUint32();
    byteRate = reader.readUint32();
    blockAlign = reader.readUint16();
    bitsPerSample = reader.readUint16();
    return true;
  }

  bool _readData(WavChunk chunk, BinaryReader reader) {
    rawSamples = reader.read(chunk.size);
    return true;
  }
}
