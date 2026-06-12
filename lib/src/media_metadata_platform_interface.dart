import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'metadata.dart';
import 'media_metadata_method_channel.dart';

/// The interface that implementations of media_metadata must implement.
abstract class MediaMetadataPlatform extends PlatformInterface {
  MediaMetadataPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaMetadataPlatform _instance = MethodChannelMediaMetadata();

  /// The default instance of [MediaMetadataPlatform] to use.
  static MediaMetadataPlatform get instance => _instance;

  static set instance(MediaMetadataPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Reads metadata from the file at [filePath].
  ///
  /// Returns a [Metadata] object, or `null` if the file cannot be read.
  Future<Metadata?> readMetadata(String filePath) {
    throw UnimplementedError('readMetadata() has not been implemented.');
  }

  /// Writes metadata to the file at [filePath].
  ///
  /// Returns `true` if the write succeeded.
  Future<bool> writeMetadata(String filePath, Metadata metadata) {
    throw UnimplementedError('writeMetadata() has not been implemented.');
  }
}
