import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/cloudinary_service.dart';
import '../../core/me_provider.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _uploading = false;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final List<double> _waveform = [];
  late AnimationController _pulseController;
  String? _topic;
  String? _error;

  static const _topics = ['General', 'Music', 'Comedy', 'News', 'Tech', 'Sports', 'Education', 'Other'];

  int get _maxSeconds {
    final me = MeProvider.of(context);
    return (me?['isEmbers'] as bool? ?? false) ? 300 : 180; // 5min Embers, 3min standard
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _error = 'Microphone permission denied');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voxa_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() {
        _waveform.add(normalized);
        if (_waveform.length % 10 == 0) _elapsed += const Duration(milliseconds: 100) * 10;
        // Enforce duration limit (spec 7.6: 3min standard, 5min Embers)
        if (_elapsed.inSeconds >= _maxSeconds) _stopRecording();
      });
    });
    setState(() { _isRecording = true; _filePath = path; _elapsed = Duration.zero; _waveform.clear(); });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _upload() async {
    if (_filePath == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      // Upload directly to Cloudinary (spec 11.1)
      final cloudinary = await CloudinaryService.uploadAudio(_filePath!, GraphQLProvider.of(context).value);

      // Normalize waveform to 48 values (spec 11.1)
      final waveformData = _normalizeWaveform(_waveform, 48);

      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(kCreateClip),
        variables: {
          'audioUrl': cloudinary['url'],
          'cloudinaryPublicId': cloudinary['publicId'],
          'waveformData': waveformData,
          'durationSeconds': _elapsed.inSeconds,
          'category': _topic ?? 'General',
          'mood': null,
        },
      ));
      if (!mounted) return;
      if (result.hasException) {
        setState(() { _error = 'Post failed. Try again.'; _uploading = false; });
        return;
      }
      context.go('/');
    } catch (e) {
      setState(() { _error = 'Upload failed: $e'; _uploading = false; });
    }
  }

  List<double> _normalizeWaveform(List<double> raw, int targetCount) {
    if (raw.isEmpty) return List.filled(targetCount, 0.0);
    final step = raw.length / targetCount;
    return List.generate(targetCount, (i) => raw[(i * step).floor().clamp(0, raw.length - 1)]);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/')),
        title: const Text('Record'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Timer
              Text(
                _fmt(_elapsed),
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w200, letterSpacing: 4, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 32),
              // Waveform visualizer
              SizedBox(
                height: 80,
                child: _waveform.isEmpty
                    ? Center(child: Text(_isRecording ? '' : 'Tap to record', style: const TextStyle(color: AppTheme.textMuted)))
                    : CustomPaint(
                        size: Size(MediaQuery.of(context).size.width - 48, 80),
                        painter: _LiveWaveformPainter(_waveform),
                      ),
              ),
              const Spacer(),
              // Topic selector
              if (!_isRecording && _filePath != null) ...[
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _topics.map((t) => GestureDetector(
                    onTap: () => setState(() => _topic = _topic == t ? null : t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _topic == t ? AppTheme.accent : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _topic == t ? AppTheme.accent : AppTheme.border),
                      ),
                      child: Text(t, style: TextStyle(color: _topic == t ? Colors.white : AppTheme.textMuted, fontSize: 13)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 32),
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
              ],
              // Record button
              if (_filePath == null || _isRecording)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : AppTheme.accent,
                        boxShadow: _isRecording ? [
                          BoxShadow(color: Colors.red.withOpacity(0.3 + 0.3 * _pulseController.value), blurRadius: 20 + 20 * _pulseController.value, spreadRadius: 4),
                        ] : [],
                      ),
                      child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() { _filePath = null; _waveform.clear(); _elapsed = Duration.zero; }),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Redo'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMuted, side: const BorderSide(color: AppTheme.border)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                      label: Text(_uploading ? 'Posting...' : 'Post'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  final List<double> waveform;
  _LiveWaveformPainter(this.waveform);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.accent..strokeCap = StrokeCap.round..strokeWidth = 2.5;
    final count = waveform.length.clamp(1, 80);
    final recent = waveform.length > 80 ? waveform.sublist(waveform.length - 80) : waveform;
    final barWidth = size.width / count;
    for (int i = 0; i < recent.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final h = recent[i] * size.height;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter old) => true;
}
