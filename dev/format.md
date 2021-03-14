59904+12+8+36 pre wav buffer
# header
## size
should be exactly 12 bytes
## contents
- 4 bytes: BBds
- 1 byte: DRM_VERSION (1)
- 1 byte: DRM_REVISION (1)
- 2 bytes (ushort): DRM_BUILD (0x1700) 
- update CRC with 8 prev bytes
- 4 bytes (uint): CRC

# instrument buffers  
instrument metadata (volume, velocity, etc)
## size
should be exactly 20 + 16 * 28 = 468 for a filled instrument
128 * 468 = 59904
## contents
for each instrument (0-127):
- 2 byte (ushort): chokeGroup
- 2 byte (ushort): polyphony
- 4 byte (uint): num velocity samples
- 4 byte (uint): wav buffer size of samples (excludes padding?)
- 1 byte: volume (0-152? find out)
- 1 byte: fillChoke
- 1 byte: fillChokeDelay
- 1 byte: non percussion (0 == percussion 1 == percussion?)
- 4 bytes: reserved

16x: for each sample (max 16, all are filled)
- 2 byte (ushort): bit depth (8/16/24)
- 2 byte (ushort): channel count (1/2)
- 4 byte (uint): sample rate
- 4 byte (uint): lower (previous) velocity value
- 4 byte (uint): number of samples
- 4 byte: reserved
- 4 byte: reserved
- 4 byte (uint): offset into wav buffer (includes padding)

# metadata info buffer
A simple struct indicating the size and offset (relative to the start of the file) of the metadata chunk.
## size
8 bytes
## contents
- 4 bytes (uint): offset
- 4 bytes (uint): size
# extension header buffer
## size
36
## contents

# samples (wav buffer) 
Includes tightly packed sample data. Each sample referenced in the instrument buffer will have an index into the first byte of the sample data in this buffer.

## Offset
This is always located at 60416 bytes into the file.

# Alignment
Individual instrument buffers are 512 byte aligned, but their voice/velocity samples are tightly packed.

# metadata buffer
Metadata containing names and filenames of samples and instruments.

# extension volume buffer
A buffer containing volumes

# Creation Order:
Order of buffer creation so CRC is correct
- wav
- instrument
- metadata
    - metadata info buffer created here
- extension
- header