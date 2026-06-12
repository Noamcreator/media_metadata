import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'media_metadata_platform_interface.dart';
import 'metadata.dart';

/// An implementation of [MediaMetadataPlatform] that uses a method channel.
class MethodChannelMediaMetadata extends MediaMetadataPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('media_metadata');

  @override
  Future<Metadata?> readMetadata(String filePath) async {
    try {
      final result = await methodChannel.invokeMethod<Map>(
        'readMetadata',
        {'filePath': filePath},
      );
      if (result == null) return null;
      return Metadata.fromMap(result);
    } on PlatformException catch (e) {
      debugPrint('[media_metadata] PlatformException: ${e.message}');
      return null;
    }
  }

  @override
  Future<bool> writeMetadata(String filePath, Metadata metadata) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'writeMetadata',
        {
          'filePath': filePath,
          'metadata': metadata.toMap(),
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[media_metadata] PlatformException: ${e.message}');
      return false;
    }
  }
}
