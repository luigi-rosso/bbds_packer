import 'dart:io';
import 'dart:typed_data';

import 'package:bbds_packer/binary_writer.dart';
import 'package:bbds_packer/crc32.dart';
import 'package:bbds_packer/drum_kit.dart';
import 'package:bbds_packer/file_io.dart';

class DrumkitPacker {
  final Drumkit kit;
  final _crc = CRC32();

  DrumkitPacker(this.kit);

  static const int packedInstrumentByteSize = 468;
  static const int instrumentCount = 128;
  static const int wavBufferAlignment = 512;

  /// Hardcoded known offset of the sample buffer in the file.
  static const int wavOffset = 60416;

  /// How much 0 byte padding there is before the first sample data. This is in
  /// order to ensure that the first sample is in fact at wavOffset. I think the
  /// wav constant was chosen somewhat randomly to guarantee there was room to
  /// grow the whole header/contents of the file prior to any dynamically sized
  /// elements. The current value of [wavPadding] is what first the format we're
  /// currently writing. Future versions may have less padding if more data is
  /// written into previous sections of the file (and if they ever spill over
  /// this amount, then I guess the format will need to be changed).
  static const int wavPadding = 456;

  // Empty instrument is just a buffer full of zeros. Initialize all
  // instruments to empty.
  static final emptyInstrument = Uint8List(packedInstrumentByteSize);
  List<Uint8List> packedInstruments =
      List<Uint8List>.filled(instrumentCount, emptyInstrument);

  void _packInstruments() {
    // Pack instrument data.
    for (final instrument in kit.instruments) {
      if (instrument.samples.isEmpty) {
        continue;
      }
      var offsetData = _wavOffsets[instrument]!;

      final writer = BinaryWriter();
      writer.writeUint16(instrument.choke);
      writer.writeUint16(instrument.poly);
      writer.writeUint32(instrument.samples.length);
      writer.writeUint32(offsetData.size);
      writer.writeUint8(instrument.volume);
      writer.writeUint8(instrument.fillChoke);
      writer.writeUint8(instrument.fillChokeDelay);
      writer.writeUint8(instrument.percussion ? 0 : 1);
      // Some reserved data (possibly for future use).
      writer.writeUint32(0);

      int sampleOffset = offsetData.offset;
      for (final sample in instrument.samples) {
        writer.writeUint16(sample.wav.bitsPerSample); // bit depth
        writer.writeUint16(sample.wav.numChannels); // channels
        writer.writeUint32(sample.wav.sampleRate); // frequency
        writer.writeUint32(sample.previousVelocity); // lower bound velocity
        writer.writeUint32(sample.wav.numSamples); // sample count
        writer.writeUint32(0); // reserved
        writer.writeUint32(0); // reserved
        writer.writeUint32(sampleOffset); // offset into wav buffer
        sampleOffset += sample.wav.rawSamples.length;
      }
      // Pack remainder with empty sample data.
      for (int i = instrument.samples.length; i < Instrument.maxSamples; i++) {
        writer.writeUint16(0); // bit depth
        writer.writeUint16(0); // channels
        writer.writeUint32(0); // frequency
        writer.writeUint32(0); // lower bound velocity
        writer.writeUint32(0); // sample count
        writer.writeUint32(0); // reserved
        writer.writeUint32(0); // reserved
        writer.writeUint32(0); // offset into wav buffer
      }

      packedInstruments[instrument.midi] = writer.uint8Buffer;
    }

    packedInstruments.forEach(_crc.add);
  }

  final _wavOffsets = <Instrument, _InstrumentWavData>{};
  late Uint8List _wavBuffer;

  /// Returns true if at least one sample got packed into the wav buffer.
  bool _packWav() {
    var writer = BinaryWriter();
    var offset = wavOffset - wavPadding;
    var nextOffset = wavOffset;
    for (final instrument in kit.instruments) {
      nextOffset =
          (nextOffset / wavBufferAlignment).ceil() * wavBufferAlignment;
      var pad = nextOffset - offset;
      if (pad > 0) {
        writer.write(Uint8List(pad));
      }

      var data = _InstrumentWavData(nextOffset);
      _wavOffsets[instrument] = data;

      for (final sample in instrument.samples) {
        data.size += sample.wav.rawSamples.length;
        nextOffset += sample.wav.rawSamples.length;
        writer.write(sample.wav.rawSamples);
      }
      offset = nextOffset;
    }
    _wavBuffer = writer.uint8Buffer;
    _crc.add(_wavBuffer);
    // Wrote more than just the initial padding.
    return writer.size > wavPadding;
  }

  /// Sort of a header for the metadata, marks the offset and size of the
  /// metadata in the file.
  late Uint8List _metadataInfoBuffer;

  /// The actual metadata.
  late Uint8List _metadataBuffer;

  int get wavSize => _wavBuffer.length - wavPadding;
  int get metadataOffset => wavOffset + wavSize;

  void _packMetadata() {
    int metadataSize;

    var writer = BinaryWriter();
    writer.writeQtString(kit.name);
    for (final instrument in kit.instruments) {
      if (instrument.samples.isNotEmpty) {
        writer.writeQtString(instrument.name);
      }
    }
    for (final instrument in kit.instruments) {
      if (instrument.samples.isNotEmpty) {
        for (final sample in instrument.samples) {
          writer.writeQtString(sample.filename);
        }
      }
    }

    // We don't write any of our empty instruments, seems to be a helper for
    // when re-editing the drumkit, but we don't really need that if our source
    // of truth is a markup file.
    writer.writeUint32(0);
    metadataSize = writer.size;

    _metadataBuffer = writer.uint8Buffer;

    var infoWriter = BinaryWriter();
    infoWriter.writeUint32(metadataOffset);
    infoWriter.writeUint32(metadataSize);
    _metadataInfoBuffer = infoWriter.uint8Buffer;

    _crc.add(_metadataInfoBuffer);
    _crc.add(_metadataBuffer);
  }

  late Uint8List _extensionHeaderBuffer;
  late Uint8List _extensionVolumeBuffer;

  void _packExtension() {
    var volgWriter = BinaryWriter();
    volgWriter.writeString('volg', explicitLength: false);
    volgWriter.write(Uint8List(3));
    volgWriter.writeUint8(kit.volume);

    var exthWriter = BinaryWriter();
    exthWriter.writeString('exth', explicitLength: false);
    var volumeOffset = metadataOffset + _metadataBuffer.length;

    exthWriter.writeUint32(volumeOffset);
    exthWriter.writeUint32(8); // volg + 3 empty bytes + volume byte

    // 3 reserved offset/sizes
    exthWriter.writeUint32(0);
    exthWriter.writeUint32(0);

    exthWriter.writeUint32(0);
    exthWriter.writeUint32(0);

    exthWriter.writeUint32(0);
    exthWriter.writeUint32(0);

    _extensionHeaderBuffer = exthWriter.uint8Buffer;
    _extensionVolumeBuffer = volgWriter.uint8Buffer;

    _crc.add(_extensionHeaderBuffer);
    _crc.add(_extensionVolumeBuffer);
  }

  void write(FileIO io, String filename) {
    if (!_packWav()) {
      throw DrumkitError('Drumkit must contain at least one valid sample.');
    }
    _packInstruments();
    _packMetadata();
    _packExtension();
    final writer = BinaryWriter(alignment: 524288);
    writer.writeString('BBds', explicitLength: false);
    writer.writeUint8(1);
    writer.writeUint8(1);
    writer.writeUint16(0x1700);
    _crc.add(writer.uint8Buffer);
    writer.writeUint32(_crc.value);
    packedInstruments.forEach(writer.write);
    writer.write(_metadataInfoBuffer);
    writer.write(_extensionHeaderBuffer);
    writer.write(_wavBuffer);
    writer.write(_metadataBuffer);
    writer.write(_extensionVolumeBuffer);
    io.save(filename, writer.uint8Buffer);
  }
}

class _InstrumentWavData {
  int size = 0;
  final int offset;

  _InstrumentWavData(this.offset);
}

extension QtStyleStringWriter on BinaryWriter {
  void writeQtString(String string) {
    var stringWriter = BinaryWriter(endian: Endian.big);
    stringWriter.writeUint32(string.length * 2);
    string.codeUnits.forEach(stringWriter.writeUint16);
    write(stringWriter.uint8Buffer);
  }
}
