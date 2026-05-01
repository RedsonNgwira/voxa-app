import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/cloudinary_service.dart';
import '../../core/services.dart';

class VoiceBioScreen extends StatefulWidget {
  final String? token;
  const VoiceBioScreen({super.key, this.token});

  @override
  State<VoiceBioScreen> createState() => _VoiceBioScreenState();
}

class _VoiceBioScreenState extends State<VoiceBioScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _uploading = false;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final List<double> _waveform = [];
  String? _error;

  static const _maxSeconds = 60; // spec 7.3: 60s max

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _error = 'Microphone permission denied');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voxa_bio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() {
        _waveform.add(normalized);
        _elapsed += const Duration(milliseconds: 100);
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

  Future<void> _save() async {
    if (_filePath == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      // Use token-specific client if provided (fixes token timing after registration)
      final client = widget.token != null
          ? GraphQLService.clientNotifier(widget.token).value
          : GraphQLProvider.of(context).value;
      final cloudinary = await CloudinaryService.uploadAudio(_filePath!, client);
      final waveformData = _normalizeWaveform(_waveform, 48);
      final result = await client.mutate(MutationOptions(
        document: gql(kSaveVoiceBio),
        variables: {'audioUrl': cloudinary['url'], 'waveformData': waveformData},
      ));
      if (!mounted) return;
      if (result.hasException) {
        setState(() { _error = 'Save failed. Try again.'; _uploading = false; });
        return;
      }
      // Go back if came from profile, otherwise go to feed
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      setState(() { _error = 'Failed: $e'; _uploading = false; });
    }
  }

  Future<void> _togglePreview() async {
    if (_filePath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.setFilePath(_filePath!);
      await _player.play();
      setState(() => _isPlaying = true);
      _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      ).then((_) { if (mounted) setState(() => _isPlaying = false); });
    }
  }

  List<double> _normalizeWaveform(List<double> raw, int n) {
    if (raw.isEmpty) return List.filled(n, 0.0);
    final step = raw.length / n;
    return List.generate(n, (i) => raw[(i * step).floor().clamp(0, raw.length - 1)]);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/');
          },
        ),
        title: const Text('Voice Bio'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text('Introduce yourself', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('60 seconds. Just talk.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const Spacer(),
              // Timer
              Text(_fmt(_elapsed), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200, letterSpacing: 4, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 8),
              // Progress bar
              LinearProgressIndicator(
                value: _elapsed.inSeconds / _maxSeconds,
                backgroundColor: AppTheme.surface,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
              const SizedBox(height: 32),
              // Record button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : (_filePath == null ? _startRecording : null),
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isRecording
                          ? [Colors.red, Colors.red.shade800]
                          : [AppTheme.accent, const Color(0xFFC0431A)],
                    ),
                    boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
                  ),
                  child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 16),
              if (_filePath != null && !_isRecording)
                GestureDetector(
                  onTap: _togglePreview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(_isPlaying ? 'Playing...' : 'Preview', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  _isRecording ? 'Recording...' : 'Tap to record',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const Spacer(),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
              ],
              if (_filePath != null && !_isRecording) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() { _filePath = null; _waveform.clear(); _elapsed = Duration.zero; }),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMuted, side: const BorderSide(color: AppTheme.border)),
                        child: const Text('Record again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _uploading ? null : _save,
                        child: _uploading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Sounds good'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
