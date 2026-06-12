import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_metadata/media_metadata.dart';

void main() {
  runApp(const MediaMetadataExampleApp());
}

class MediaMetadataExampleApp extends StatelessWidget {
  const MediaMetadataExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Metadata Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Metadata? _metadata;
  String? _filePath;
  bool _loading = false;
  String? _error;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: MediaMetadata.supportedExtensions,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() {
          _error = 'Could not get file path.';
        });
        return;
      }

      setState(() {
        _loading = true;
        _error = null;
        _metadata = null;
        _filePath = null;
      });

      final metadata = await MediaMetadata.read(path);

      setState(() {
        _filePath = path;
        _metadata = metadata;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Ouvre un formulaire complet pour éditer l'intégralité des métadonnées (y compris l'image)
  Future<void> _editMetadata() async {
    if (_metadata == null || _filePath == null) return;

    // Initialisation des contrôleurs avec les valeurs actuelles
    final titleCtrl = TextEditingController(text: _metadata!.title ?? '');
    final artistCtrl = TextEditingController(text: _metadata!.artist ?? '');
    final albumCtrl = TextEditingController(text: _metadata!.album ?? '');
    final albumArtistCtrl = TextEditingController(text: _metadata!.albumArtist ?? '');
    final genreCtrl = TextEditingController(text: _metadata!.genre ?? '');
    final yearCtrl = TextEditingController(text: _metadata!.year?.toString() ?? '');
    final trackNumCtrl = TextEditingController(text: _metadata!.trackNumber?.toString() ?? '');
    final trackTotalCtrl = TextEditingController(text: _metadata!.trackTotal?.toString() ?? '');
    final discNumCtrl = TextEditingController(text: _metadata!.discNumber?.toString() ?? '');
    final discTotalCtrl = TextEditingController(text: _metadata!.discTotal?.toString() ?? '');

    // Variable locale pour stocker temporairement la nouvelle image sélectionnée dans le dialogue
    Uint8List? newArtworkData = _metadata!.imageData;

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder( // Utilisation de StatefulBuilder pour mettre à jour l'aperçu de l'image en direct dans le popup
        builder: (context, setDialogState) {
          
          Future<void> pickNewArtwork() async {
            final imgResult = await FilePicker.pickFiles(
              type: FileType.image,
            );
            if (imgResult != null && imgResult.files.single.path != null) {
              final file = File(imgResult.files.single.path!);
              final bytes = await file.readAsBytes();
              setDialogState(() {
                newArtworkData = bytes;
              });
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_note, size: 28),
                SizedBox(width: 8),
                Text('Edit All Metadata'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DialogSectionTitle(title: 'Artwork / Cover'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: newArtworkData != null
                              ? Image.memory(newArtworkData!, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported, size: 32),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: pickNewArtwork,
                          icon: const Icon(Icons.photo),
                          label: const Text('Change Image'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _DialogSectionTitle(title: 'Main Tags'),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title))),
                    TextField(controller: artistCtrl, decoration: const InputDecoration(labelText: 'Artist', prefixIcon: Icon(Icons.person))),
                    TextField(controller: albumCtrl, decoration: const InputDecoration(labelText: 'Album', prefixIcon: Icon(Icons.album))),
                    TextField(controller: albumArtistCtrl, decoration: const InputDecoration(labelText: 'Album Artist', prefixIcon: Icon(Icons.recent_actors))),
                    TextField(controller: genreCtrl, decoration: const InputDecoration(labelText: 'Genre', prefixIcon: Icon(Icons.style))),
                    TextField(
                      controller: yearCtrl,
                      decoration: const InputDecoration(labelText: 'Year', prefixIcon: Icon(Icons.calendar_today)),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const _DialogSectionTitle(title: 'Track & Disc info'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: trackNumCtrl,
                            decoration: const InputDecoration(labelText: 'Track #'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: trackTotalCtrl,
                            decoration: const InputDecoration(labelText: 'Track Total'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discNumCtrl,
                            decoration: const InputDecoration(labelText: 'Disc #'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: discTotalCtrl,
                            decoration: const InputDecoration(labelText: 'Disc Total'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSave == true) {
      setState(() {
        _loading = true;
      });

      try {
        // Construction du nouvel objet Metadata propre avec la nouvelle image
        final newMetadata = Metadata(
          title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
          artist: artistCtrl.text.trim().isEmpty ? null : artistCtrl.text.trim(),
          album: albumCtrl.text.trim().isEmpty ? null : albumCtrl.text.trim(),
          albumArtist: albumArtistCtrl.text.trim().isEmpty ? null : albumArtistCtrl.text.trim(),
          genre: genreCtrl.text.trim().isEmpty ? null : genreCtrl.text.trim(),
          year: int.tryParse(yearCtrl.text),
          trackNumber: int.tryParse(trackNumCtrl.text),
          trackTotal: int.tryParse(trackTotalCtrl.text),
          discNumber: int.tryParse(discNumCtrl.text),
          discTotal: int.tryParse(discTotalCtrl.text),
          imageData: newArtworkData, // On injecte l'image (ancienne, modifiée ou nulle)
        );

        final success = await MediaMetadata.write(_filePath!, newMetadata);

        if (success) {
          // Relecture instantanée pour mettre à jour l'interface graphique
          final refreshedMetadata = await MediaMetadata.read(_filePath!);
          setState(() {
            _metadata = refreshedMetadata;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metadata written successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } 
        else {
          setState(() {
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to write metadata. Platform or format not supported.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _metadata = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Metadata'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _metadata != null
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_note),
                  iconSize: 28,
                  tooltip: 'Edit all metadata',
                  onPressed: _editMetadata,
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _metadata == null
              ? _buildEmpty(context)
              : _buildResult(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFile,
        icon: const Icon(Icons.folder_open),
        label: const Text('Pick file'),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.audio_file,
            size: 60,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Pick a media file to read its metadata',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Supported: ${MediaMetadata.supportedExtensions.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final m = _metadata!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ArtworkCard(imageData: m.imageData),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  title: 'File',
                  padding: const EdgeInsets.all(12),
                  children: [
                    _Row('Path', _filePath ?? '—'),
                    _Row(
                      'Size',
                      m.fileSize != null ? _formatSize(m.fileSize!) : '—',
                    ),
                  ],
                ),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoCard(
            title: 'Tags',
            children: [
              _Row('Title', m.title),
              _Row('Artist', m.artist),
              _Row('Album', m.album),
              _Row('Album Artist', m.albumArtist),
              _Row('Genre', m.genre),
              _Row('Year', m.year?.toString()),
            ],
          ),
          const SizedBox(height: 8),
          _InfoCard(
            title: 'Track / Disc',
            children: [
              _Row(
                'Track',
                _formatFraction(m.trackNumber, m.trackTotal),
              ),
              _Row(
                'Disc',
                _formatFraction(m.discNumber, m.discTotal),
              ),
              _Row(
                'Duration',
                m.duration != null ? _formatDuration(m.duration!) : null,
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _formatSize(BigInt bytes) {
    final mb = bytes.toDouble() / (1024 * 1024);
    if (mb < 1) return '${(bytes.toDouble() / 1024).toStringAsFixed(1)} KB';
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String? _formatFraction(int? num, int? total) {
    if (num == null) return null;
    if (total == null) return num.toString();
    return '$num / $total';
  }
}

// ─── Sub-Widgets de l'interface graphique ───────────────────────────────────

class _DialogSectionTitle extends StatelessWidget {
  final String title;
  const _DialogSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  final Uint8List? imageData;
  const _ArtworkCard({this.imageData});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 100,
        width: 100,
        child: imageData != null
            ? Image.memory(imageData!, fit: BoxFit.cover)
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _InfoCard({
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}