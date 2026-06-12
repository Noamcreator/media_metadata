# media_metadata

A Flutter plugin to read metadata from media files on **Android**, **iOS**, **macOS**, **Windows**, and **Linux**.

## Supported formats

| Extension | Audio | Video |
|-----------|-------|-------|
| `.mp3`    | ✅    |       |
| `.mp4`    |       | ✅    |
| `.mkv`    |       | ✅    |
| `.3gp` / `.3gpp` | | ✅ |
| `.mov`    |       | ✅    |
| `.aac`    | ✅    |       |

## Fields returned

| Field         | Type         | Description                          |
|---------------|--------------|--------------------------------------|
| `title`       | `String?`    | Title tag                            |
| `duration`    | `Duration?`  | Total duration                       |
| `artist`      | `String?`    | Primary artist                       |
| `album`       | `String?`    | Album name                           |
| `albumArtist` | `String?`    | Album artist                         |
| `trackNumber` | `int?`       | Track number                         |
| `trackTotal`  | `int?`       | Total tracks on the album            |
| `discNumber`  | `int?`       | Disc number                          |
| `discTotal`   | `int?`       | Total discs                          |
| `year`        | `int?`       | Release year                         |
| `genre`       | `String?`    | Genre                                |
| `imageData`   | `Uint8List?` | Embedded artwork as raw image bytes  |
| `fileSize`    | `BigInt?`    | File size in bytes                   |

## Usage

```dart
import 'package:media_metadata/media_metadata.dart';

// Read metadata from a file path
final metadata = await MediaMetadata.read('/storage/emulated/0/Music/song.mp3');

if (metadata != null) {
  print(metadata.title);       // "Bohemian Rhapsody"
  print(metadata.artist);      // "Queen"
  print(metadata.album);       // "A Night at the Opera"
  print(metadata.duration);    // Duration(minutes: 5, seconds: 55)
  print(metadata.year);        // 1975
  print(metadata.trackNumber); // 11
  
  // Display the album art
  if (metadata.imageData != null) {
    Image.memory(metadata.imageData!);
  }
}

// Write metadata back to a file
final success = await MediaMetadata.write(
  '/storage/emulated/0/Pictures/photo.jpg',
  Metadata(title: 'Vacation', artist: 'Unknown', year: 2024),
);
if (success) {
  print('Metadata written successfully');
}

// Check if a file is supported before reading
if (MediaMetadata.isSupported('/path/to/file.mp3')) {
  // supported
}
```

## Write support

The `MediaMetadata.write` API is now available. It writes the metadata fields supported by the current platform and returns `true` when the operation succeeds.

Supported platforms:

- Android: image metadata via `ExifInterface` for `.jpg`, `.jpeg`, `.png`, `.webp`, `.heic`
- Windows: file metadata via the Shell Property Store
- Linux: audio metadata via TagLib when available
- iOS / macOS: currently not supported; the API returns `false`

## Setup

### Android

Add the following permissions to your `AndroidManifest.xml`:

```xml
<!-- Android < 13 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

Request the permission at runtime using `permission_handler` or another package.

The plugin uses Android's built-in `MediaMetadataRetriever` — **no extra dependencies required** beyond `androidx.exifinterface` (added automatically by the plugin's `build.gradle`).

### iOS / macOS

No additional setup needed. Uses `AVFoundation` and `ImageIO` (both system frameworks).

### Windows

Uses the Windows Shell Property Store (`IPropertyStore`) and Media Foundation. Requires Windows 10 or later. No extra SDKs needed — links against `propsys`, `mfplat`, `mfreadwrite`, `shlwapi`, and `windowscodecs`.

### Linux

Uses **TagLib** for metadata extraction. Install the development package:

```bash
sudo apt install libtag1-dev   # Debian/Ubuntu
sudo dnf install taglib-devel  # Fedora
```

The plugin will compile without TagLib but will only return file sizes in that case.

## Platform notes

| Platform | Library used         | Album art |
|----------|---------------------|-----------|
| Android  | `MediaMetadataRetriever` + `ExifInterface` | ✅ |
| iOS      | `AVFoundation` + `ImageIO` | ✅ |
| macOS    | `AVFoundation` + `ImageIO` | ✅ |
| Windows  | Shell Property Store + WIC | ✅ (thumbnail) |
| Linux    | TagLib              | ✅ (ID3v2 only) |
