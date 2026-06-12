library;

export 'src/metadata.dart';
export 'src/media_metadata_platform_interface.dart';
export 'src/media_metadata_method_channel.dart';

import 'src/media_metadata_platform_interface.dart';
import 'src/metadata.dart';

/// Main entry-point for the media_metadata plugin.
///
/// Usage:
/// ```dart
/// final metadata = await MediaMetadata.read('/path/to/file.mp3');
/// print(metadata?.title);
/// ```
class MediaMetadata {
  MediaMetadata._();

  /// Supported file extensions.
  static const List<String> supportedExtensions = [
    'mp3', 'mp4', 'mkv', '3gp', '3gpp',
    'mov', 'aac',
  ];

  /// Reads the metadata from the file at [filePath].
  ///
  /// Returns `null` if the file is unreadable or unsupported.
  /// Throws [ArgumentError] if [filePath] is empty.
  static Future<Metadata?> read(String filePath) async {
    if (filePath.trim().isEmpty) {
      throw ArgumentError('filePath must not be empty');
    }
    return MediaMetadataPlatform.instance.readMetadata(filePath);
  }

  /// Writes the metadata to the file at [filePath].
  ///
  /// Returns `true` if the write succeeded. On unsupported platforms or when
  /// tags cannot be written, this returns `false`.
  /// Throws [ArgumentError] if [filePath] is empty.
  static Future<bool> write(String filePath, Metadata metadata) async {
    if (filePath.trim().isEmpty) {
      throw ArgumentError('filePath must not be empty');
    }
    return MediaMetadataPlatform.instance.writeMetadata(filePath, metadata);
  }

  /// Returns `true` if the file extension of [filePath] is supported.
  static bool isSupported(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }
}
