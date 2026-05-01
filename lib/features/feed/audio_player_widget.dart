import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final List<double>? waveform;
  final int? duration;

  const AudioPlayerWidget({super.key, required this.url, this.waveform, this.duration});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _loading = false;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player.playerStateStream.listen((_) { if (mounted) setState(() {}); });
    _posSub = _player.positionStream
        .where((_) => _player.playing) // only update while playing
        .listen((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.idle) {
      setState(() => _loading = true);
      await _player.setUrl(widget.url);
      setState(() => _loading = false);
    }
    await _player.play();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final position = _player.position;
    final total = _player.duration ?? Duration(seconds: widget.duration ?? 0);
    final progress = total.inMilliseconds > 0 ? position.inMilliseconds / total.inMilliseconds : 0.0;
    final isPlaying = _player.playing;

    return Row(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
            child: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform / progress bar
              LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onTapDown: (d) async {
                    final ratio = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    if (total.inMilliseconds > 0) {
                      await _player.seek(Duration(milliseconds: (total.inMilliseconds * ratio).round()));
                    }
                  },
                  child: _WaveformBar(waveform: widget.waveform, progress: progress),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(position), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
                  Text(_fmt(total), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaveformBar extends StatelessWidget {
  final List<double>? waveform;
  final double progress;

  const _WaveformBar({this.waveform, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: CustomPaint(painter: _WaveformPainter(waveform: waveform, progress: progress)),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double>? waveform;
  final double progress;

  _WaveformPainter({this.waveform, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bars = waveform ?? List.generate(40, (i) => 0.3 + 0.4 * ((i * 7) % 10) / 10);
    final count = bars.length;
    final barWidth = (size.width / count) * 0.6;
    final gap = (size.width / count) * 0.4;
    final playedPaint = Paint()..color = AppTheme.accent;
    final unplayedPaint = Paint()..color = AppTheme.border;

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final barHeight = (bars[i].clamp(0.0, 1.0)) * size.height;
      final top = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, x / size.width < progress ? playedPaint : unplayedPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}
