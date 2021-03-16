import 'package:bbds_packer/file_io.dart';
import 'package:bbds_packer/wav.dart';
import 'package:yaml/yaml.dart';

class DrumkitError extends Error {
  String message;
  DrumkitError(this.message);
}

class Drumkit {
  String name = 'Unnamed';
  int volume = 100;
  final List<Instrument> instruments = [];
  final midiInstrument = <int, Instrument>{};

  Drumkit(YamlMap data) {
    dynamic nameValue = data['name'];
    if (nameValue is String) {
      name = nameValue;
    }
    dynamic volumeValue = data['volume'];
    if (volumeValue is int) {
      volume = volumeValue;
    }
    dynamic instrumentList = data['instruments'];
    if (instrumentList is YamlList) {
      for (final instrumentData in instrumentList) {
        if (instrumentData is YamlMap) {
          var instrument = Instrument(instrumentData);
          instruments.add(instrument);
          if (midiInstrument.containsKey(instrument.midi)) {
            throw DrumkitError(
                'Multiple instruments with midi id ${instrument.midi}');
          }
          midiInstrument[instrument.midi] = instrument;
        }
      }
    }
    instruments.sort((a, b) => a.midi.compareTo(b.midi));
  }

  Future<bool> loadSamples(FileIO io, String basePath) async {
    for (final instrument in instruments) {
      if (!await instrument.loadSamples(io, basePath)) {
        return false;
      }
    }
    return true;
  }
}

class Instrument {
  String name = 'Unnamed';
  int midi = 0;
  int choke = 0;
  int poly = 0;
  bool percussion = true;
  int volume = 100;
  int fillChoke = 0;
  int fillChokeDelay = 0;
  static const int maxSamples = 16;

  final List<Sample> samples = [];

  Instrument(YamlMap data) {
    dynamic nameValue = data['name'];
    if (nameValue is String) {
      name = nameValue;
    }
    dynamic midiValue = data['midi'];
    if (midiValue is int) {
      midi = midiValue;
    }
    dynamic chokeValue = data['choke'];
    if (chokeValue is int) {
      choke = chokeValue;
    }
    dynamic polyValue = data['poly'];
    if (polyValue is int) {
      poly = polyValue;
    }
    dynamic percussionValue = data['percussion'];
    if (percussionValue is bool) {
      percussion = percussionValue;
    }
    dynamic volumeValue = data['volume'];
    if (volumeValue is int) {
      // TODO: check if this range is right
      volume = volumeValue.clamp(1, 100).toInt();
    }
    dynamic fillChokeValue = data['fillChoke'];
    if (fillChokeValue is int) {
      fillChoke = fillChokeValue;
    }
    dynamic fillDelayValue = data['fillChokeDelay'];
    if (fillDelayValue is int) {
      fillChokeDelay = fillDelayValue.clamp(0, 2);
    } else if (fillDelayValue is String) {
      switch (fillDelayValue) {
        case '1/4':
        case '1/4th':
          fillChokeDelay = 0;
          break;
        case '1/8':
        case '1/8th':
          fillChokeDelay = 1;
          break;
        case '1/16':
        case '1/16th':
          fillChokeDelay = 2;
          break;
      }
    }

    dynamic samplesData = data['samples'];
    if (samplesData is YamlMap) {
      for (final sampleData in samplesData.entries) {
        int v;
        if (sampleData.key is int) {
          v = sampleData.key as int;
        } else {
          continue;
        }
        if (sampleData.value is String) {
          samples.add(Sample(sampleData.value as String, v));
        } else if (sampleData.value is YamlList) {
          for (final value in sampleData.value) {
            if (value is String) {
              samples.add(Sample(value, v));
            }
          }
          continue;
        } else {
          continue;
        }
      }
    }
    if (samples.length > Instrument.maxSamples) {
      throw DrumkitError('Instrument $name has ${samplesData.length} '
          'samples. Max samples per instrument is ${Instrument.maxSamples}.');
    }
    samples.sort((a, b) => a.velocity.compareTo(b.velocity));
    var previousVelocity2 = 0;
    var previousVelocity = 0;
    for (final sample in samples) {
      if (previousVelocity == sample.velocity) {
        sample.previousVelocity = previousVelocity2;
      } else {
        sample.previousVelocity = previousVelocity;
        previousVelocity2 = previousVelocity;
        previousVelocity = sample.velocity;
      }
    }
  }

  Future<bool> loadSamples(FileIO io, String basePath) async {
    for (final sample in samples) {
      if (!await sample.load(io, basePath)) {
        return false;
      }
    }
    return true;
  }
}

class Sample {
  final String filename;
  final int velocity;
  late int previousVelocity;
  late Wav wav;

  Sample(this.filename, this.velocity);

  @override
  String toString() {
    return '$previousVelocity-$velocity -> $filename';
  }

  Future<bool> load(FileIO io, String basePath) async {
    final bytes = io.load('$basePath$filename');
    if (bytes == null) {
      print('Wav not found: $filename');
      return false;
    }
    var w = Wav();
    if (w.load(bytes)) {
      wav = w;
      return true;
    }
    return false;
  }
}
