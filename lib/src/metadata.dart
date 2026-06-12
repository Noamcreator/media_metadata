import 'dart:typed_data';

/// Holds all metadata extracted from a media file.
class Metadata {
  final String? title;
  final Duration? duration;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final int? year;
  final String? genre;
  final Uint8List? imageData;
  final BigInt? fileSize;

  const Metadata({
    this.title,
    this.duration,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.year,
    this.genre,
    this.imageData,
    this.fileSize,
  });

  /// Creates a [Metadata] instance from a raw map returned by the platform channel.
  factory Metadata.fromMap(Map<dynamic, dynamic> map) {
    return Metadata(
      title: map['title'] as String?,
      duration: map['duration'] != null
          ? Duration(milliseconds: (map['duration'] as num).toInt())
          : null,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      albumArtist: map['albumArtist'] as String?,
      trackNumber: _parseInt(map['trackNumber']),
      trackTotal: _parseInt(map['trackTotal']),
      discNumber: _parseInt(map['discNumber']),
      discTotal: _parseInt(map['discTotal']),
      year: _parseInt(map['year']),
      genre: map['genre'] as String?,
      imageData: map['imageData'] != null
          ? Uint8List.fromList(List<int>.from(map['imageData'] as List))
          : null,
      fileSize: map['fileSize'] != null
          ? BigInt.from((map['fileSize'] as num).toInt())
          : null,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Converts this [Metadata] instance to a map.
  Map<String, dynamic> toMap() => {
        'title': title,
        'duration': duration?.inMilliseconds,
        'artist': artist,
        'album': album,
        'albumArtist': albumArtist,
        'trackNumber': trackNumber,
        'trackTotal': trackTotal,
        'discNumber': discNumber,
        'discTotal': discTotal,
        'year': year,
        'genre': genre,
        'imageData': imageData,
        'fileSize': fileSize?.toInt(),
      };

  @override
  String toString() => 'Metadata('
      'title: $title, '
      'artist: $artist, '
      'album: $album, '
      'duration: $duration, '
      'year: $year, '
      'genre: $genre, '
      'trackNumber: $trackNumber/$trackTotal, '
      'discNumber: $discNumber/$discTotal, '
      'albumArtist: $albumArtist, '
      'fileSize: $fileSize, '
      'hasImage: ${imageData != null}'
      ')';
}
