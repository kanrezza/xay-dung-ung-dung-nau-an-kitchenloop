import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/recipe_exceptions.dart';
import '../../data/video_compressor.dart';
import '../../data/video_repository.dart';
import '../../domain/video_chunks.dart';
import '../../models/recipe.dart';
import 'recipe_video_player.dart';

enum _Phase { idle, compressing, uploading, loading, playing }

/// Mục "Video hướng dẫn" trong màn chi tiết (spec 006): thêm/thay/xoá video, tiến độ, trình phát.
class RecipeVideoSection extends StatefulWidget {
  const RecipeVideoSection({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<RecipeVideoSection> createState() => _RecipeVideoSectionState();
}

class _RecipeVideoSectionState extends State<RecipeVideoSection> {
  _Phase _phase = _Phase.idle;
  int _done = 0;
  int _total = 0;
  File? _file;

  @override
  void didUpdateWidget(RecipeVideoSection old) {
    super.didUpdateWidget(old);
    // Video đổi (vừa thay/xoá): quay về trạng thái chờ phát.
    if (old.recipe.video?.id != widget.recipe.video?.id && _phase == _Phase.playing) {
      setState(() {
        _phase = _Phase.idle;
        _file = null;
      });
    }
  }

  void _say(String key, [List<String>? args]) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(key.tr(args: args))));

  void _progress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _done = done;
      _total = total;
    });
  }

  Future<void> _pickAndUpload() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              key: const Key('video_gallery'),
              leading: const Icon(Icons.video_library_outlined),
              title: Text('recipes.video_gallery'.tr()),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
          ListTile(
              key: const Key('video_camera'),
              leading: const Icon(Icons.videocam_outlined),
              title: Text('recipes.video_camera'.tr()),
              onTap: () => Navigator.pop(sheet, ImageSource.camera)),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickVideo(source: source, maxDuration: maxVideoDuration);
    if (picked == null || !mounted) return;
    final videos = context.read<VideoRepository>();
    final compressor = context.read<VideoCompressor>();
    setState(() => _phase = _Phase.compressing);
    try {
      final compressed = await compressor.compress(File(picked.path));
      if (!mounted) return;
      setState(() {
        _phase = _Phase.uploading;
        _done = 0;
        _total = 0;
      });
      await videos.upload(widget.recipe.id, compressed.file, durationMs: compressed.durationMs, onProgress: _progress);
      if (mounted) _say('recipes.video_added');
    } on VideoTooLargeException {
      if (mounted) _say('recipes.video_too_large', ['${maxVideoBytes ~/ 1000000}']);
    } on OfflineException {
      if (mounted) _say('recipes.video_offline');
    } catch (_) {
      if (mounted) _say('recipes.video_failed');
    } finally {
      if (mounted && _phase != _Phase.playing) setState(() => _phase = _Phase.idle);
    }
  }

  Future<void> _play(RecipeVideo video) async {
    setState(() {
      _phase = _Phase.loading;
      _done = 0;
      _total = video.chunkCount;
    });
    try {
      final file = await context.read<VideoRepository>().load(widget.recipe.id, video, onProgress: _progress);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.playing;
        _file = file;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      _say('recipes.video_load_failed');
    }
  }

  Future<void> _remove(RecipeVideo video) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('recipes.video_remove_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
          FilledButton(key: const Key('video_remove_confirm'), onPressed: () => Navigator.pop(d, true), child: Text('common.delete'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<VideoRepository>().remove(widget.recipe.id, video);
      if (mounted) _say('recipes.video_removed');
    } catch (_) {
      if (mounted) _say('recipes.video_failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final video = widget.recipe.video;
    final busy = _phase == _Phase.compressing || _phase == _Phase.uploading || _phase == _Phase.loading;
    Widget body;
    if (busy) {
      final label = switch (_phase) {
        _Phase.compressing => 'recipes.video_compressing'.tr(),
        _Phase.uploading => 'recipes.video_uploading'.tr(args: ['$_done', '$_total']),
        _ => 'recipes.video_loading'.tr(args: ['$_done', '$_total']),
      };
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          LinearProgressIndicator(
              key: const Key('video_progress'), value: _phase == _Phase.compressing || _total == 0 ? null : _done / _total),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ]),
      );
    } else if (_phase == _Phase.playing && _file != null) {
      body = RecipeVideoPlayer(key: ValueKey(video?.id), file: _file!);
    } else if (video != null) {
      body = InkWell(
        key: const Key('video_play'),
        onTap: () => _play(video),
        child: Container(
          height: 180,
          color: Colors.black87,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
            const SizedBox(height: 8),
            Text(
              [
                if (video.durationMs != null) '${(video.durationMs! / 1000).ceil()} s',
                '${(video.sizeBytes / 1048576).toStringAsFixed(1)} MB',
              ].join(' · '),
              style: const TextStyle(color: Colors.white70),
            ),
          ]),
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: OutlinedButton.icon(
          key: const Key('add_video'),
          onPressed: _pickAndUpload,
          icon: const Icon(Icons.video_call_outlined),
          label: Text('recipes.video_add'.tr()),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('recipes.video_title'.tr(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          if (video != null && !busy)
            PopupMenuButton<String>(
              key: const Key('video_menu'),
              onSelected: (v) => v == 'replace' ? _pickAndUpload() : _remove(video),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'replace', child: Text('recipes.video_replace'.tr())),
                PopupMenuItem(value: 'remove', child: Text('recipes.video_remove'.tr())),
              ],
            ),
        ]),
        const SizedBox(height: 8),
        Card(clipBehavior: Clip.antiAlias, child: body),
      ],
    );
  }
}
