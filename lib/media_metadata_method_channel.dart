import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_metadata_platform_interface.dart';

/// An implementation of [MediaMetadataPlatform] that uses method channels.
class MethodChannelMediaMetadata extends MediaMetadataPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_metadata');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
