import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Trình phát video hướng dẫn: chạm để dừng/tiếp, thanh tua, thời gian.
class RecipeVideoPlayer extends StatefulWidget {
  const RecipeVideoPlayer({super.key, required this.file});

  final File file;

  @override
  State<RecipeVideoPlayer> createState() => _RecipeVideoPlayerState();
}

class _RecipeVideoPlayerState extends State<RecipeVideoPlayer> {
  late final VideoPlayerController _controller = VideoPlayerController.file(widget.file);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    }
    final v = _controller.value;
    // Video dọc (quay điện thoại) không chiếm quá cao.
    final ratio = v.aspectRatio < 0.8 ? 0.8 : v.aspectRatio;
    return Column(
      children: [
        GestureDetector(
          key: const Key('video_toggle'),
          onTap: () => v.isPlaying ? _controller.pause() : _controller.play(),
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                    color: Colors.black, child: Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_controller)))),
                if (!v.isPlaying)
                  const CircleAvatar(
                      radius: 30, backgroundColor: Colors.black54, child: Icon(Icons.play_arrow, color: Colors.white, size: 36)),
              ],
            ),
          ),
        ),
        VideoProgressIndicator(_controller, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 6)),
        Row(
          children: [
            IconButton(
              icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => v.isPlaying ? _controller.pause() : _controller.play(),
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: () => _controller.seekTo(Duration.zero).then((_) => _controller.play()),
            ),
            const Spacer(),
            Text('${_fmt(v.position)} / ${_fmt(v.duration)}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );
  }
}
