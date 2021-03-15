# BeatBuddy Drum Kit Packer
A tool for packing BeatBuddy drum kits from a simple markup text definition files. 

## Why
BBManager was a little too tedious and error prone.
- Lack of drag and drop. Needing to manually enter each sample/velocity file made me wish I could just do it in a text file. 
- Failed to process WAV files with extra chunks. The method used to find the data chunk can cause false positives (resulting in bad sound data in the drumkit). I ran into the infamous 'empty sound' drum kit issue with any kit I tried to make.

## Online Version
Just drag and drop a folder containing your yaml file and samples to: https://luigi-rosso.github.io/bbds_packer

## CLI Version
These are for Mac but if someone wants to PR windows ones, they should be similar.

### Get Dart
Get dart if you don't have it. Easiest option is homebrew on Mac but you can download it from https://dart.dev/get-dart
```
brew install dart
```
### Write your YML markup file
This is the definition file that provides the packer with all the metadata about your drumkit, including velocities and paths to sample/wav files. See the [provided example](assets/circle_sample_kit.yaml) or scroll below to see it inline.

### Run the packer
This will generate a corresponding assets/circle_sample_kit.drm:

```dev/run.sh --file assets/circle_sample_kit.yaml```

## Markup Example
```
name: Circle Sample Kit
volume: 100
instruments:
  - name: Kick
    midi: 36
    choke: 3
    poly: 3
    percussion: true
    volume: 90
    fillChoke: 3
    fillChokeDelay: 1/8
    samples:
      20: circle_free_samples/BILLY KICK V8 - A.wav
      80: circle_free_samples/PILLOW KICK V5 - A.wav
      127: circle_free_samples/Z - DEVIL KICK.wav
  - name: Snare
    midi: 38
    choke: 3
    poly: 3
    percussion: true
    volume: 0.9
    fillChoke: 3
    fillChokeDelay: 1/4
    samples:
        22: circle_free_samples/BRONZE SNARE V8 - A.wav
        80: circle_free_samples/PUFF SNARE V5 - A.wav
        127: circle_free_samples/SIZZLE SNARE MED - A.wav

```