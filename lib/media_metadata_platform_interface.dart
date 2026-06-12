import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_metadata_method_channel.dart';

abstract class MediaMetadataPlatform extends PlatformInterface {
  /// Constructs a MediaMetadataPlatform.
  MediaMetadataPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaMetadataPlatform _instance = MethodChannelMediaMetadata();

  /// The default instance of [MediaMetadataPlatform] to use.
  ///
  /// Defaults to [MethodChannelMediaMetadata].
  static MediaMetadataPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediaMetadataPlatform] when
  /// they register themselves.
  static set instance(MediaMetadataPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
