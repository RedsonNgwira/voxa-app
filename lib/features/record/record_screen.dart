import 'dart:io';
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
import '../../core/me_provider.dart';

class RecordScreen extends StatefulWidget {
  final String? preselectedCircleId;
  final String? promptId;
  final String? promptText;
  final String? initialMood;
  const RecordScreen({super.key, this.preselectedCircleId, this.promptId, this.promptText, this.initialMood});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with TickerProviderStateMixin {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _uploading = false;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final List<double> _waveform = [];
  late AnimationController _pulseController;
  late AnimationController _successController;
  String? _topic;
  String? _circleId;
  String? _error;
  String? _mood;
  String _clipType = 'voice'; // 'voice' or 'ambient'
  String? _locationName;
  List<Map<String, dynamic>> _circles = [];

  static const _topics = ['General', 'Music', 'Comedy', 'Story', 'Thought', 'Question', 'Rant', 'Other'];
  static const _moods = ['calm', 'hype', 'sad', 'angry', 'playful', 'thoughtful', 'vulnerable'];

  int get _maxSeconds {
    final me = MeProvider.of(context);
    return (me?['isEmbers'] as bool? ?? false) ? 300 : 180;
  }

  @override
  void initState() {
    super.initState();
    _circleId = widget.preselectedCircleId;
    _mood = widget.initialMood;
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _successController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCircles());
  }

  Future<void> _loadCircles() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(document: gql(kMyCircles), fetchPolicy: FetchPolicy.networkOnly));
    if (!mounted || result.hasException) return;
    setState(() => _circles = (result.data!['myCircles'] as List).cast<Map<String, dynamic>>());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _error = 'Microphone permission is required to record.');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/voxa_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    setState(() { _isRecording = true; _filePath = path; _elapsed = Duration.zero; _waveform.clear(); _error = null; });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _togglePreview() async {
    if (_filePath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        if (_player.processingState == ProcessingState.idle ||
            _player.processingState == ProcessingState.completed) {
          await _player.setFilePath(_filePath!);
        }
        await _player.seek(Duration.zero);
        await _player.play();
        setState(() => _isPlaying = true);
        _player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed,
        ).then((_) { if (mounted) setState(() => _isPlaying = false); });
      } catch (e) {
        setState(() => _error = 'Could not play recording.');
      }
    }
  }

  Future<void> _upload() async {
    if (_filePath == null) return;
    // Stop player first — Android locks the file while playing
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    setState(() { _uploading = true; _error = null; });
    try {
      // Upload directly to Cloudinary
      final cloudinary = await CloudinaryService.uploadAudio(_filePath!, GraphQLProvider.of(context).value);

      // Normalize waveform to 48 values
      final waveformData = _normalizeWaveform(_waveform, 48);

      final client = GraphQLProvider.of(context).value;
      final result = await client.mutate(MutationOptions(
        document: gql(kCreateClipExtended),
        variables: {
          'audioUrl': cloudinary['url'],
          'cloudinaryPublicId': cloudinary['publicId'],
          'waveformData': waveformData,
          'durationSeconds': _elapsed.inSeconds > 0 ? _elapsed.inSeconds : 1,
          'category': _topic ?? 'General',
          'mood': _mood,
          'circleId': _circleId,
          'clipType': _clipType,
          'promptId': widget.promptId,
          'locationName': _clipType == 'ambient' ? _locationName : null,
        },
      ));
      if (!mounted) return;
      if (result.hasException) {
        final msg = result.exception?.graphqlErrors.firstOrNull?.message ?? 'Post failed';
        setState(() { _error = msg; _uploading = false; });
        return;
      }

      // Success — clean up local file
      try { File(_filePath!).deleteSync(); } catch (_) {}
      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) context.go('/');
    } on CloudinaryUploadException catch (e) {
      if (mounted) setState(() { _error = e.message; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Upload failed: $e'; _uploading = false; });
    }
  }

  void _resetRecording() {
    _player.stop();
    setState(() {
      _filePath = null;
      _waveform.clear();
      _elapsed = Duration.zero;
      _isPlaying = false;
      _error = null;
    });
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
    final hasRecording = _filePath != null && !_isRecording;
    final progress = _maxSeconds > 0 ? _elapsed.inSeconds / _maxSeconds : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            if (_filePath != null || _isRecording) {
              final discard = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Discard recording?'),
                  content: const Text('Your recording will be lost.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Keep')),
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Discard', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (discard != true) return;
            }
            if (mounted) context.go('/');
          },
        ),
        title: const Text('Record'),
        actions: [
          if (hasRecording && !_uploading)
            TextButton(
              onPressed: _upload,
              child: const Text('Post', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Prompt banner (when recording a prompt response)
              if (widget.promptText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.gold.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Responding to prompt',
                              style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(widget.promptText!,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Timer
              Text(
                _fmt(_elapsed),
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w200, letterSpacing: 4, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 8),

              // Time remaining indicator
              if (_isRecording || hasRecording)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.8 ? Colors.redAccent : AppTheme.accent,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              if (_isRecording)
                Text(
                  '${_maxSeconds - _elapsed.inSeconds}s remaining',
                  style: TextStyle(
                    color: progress > 0.8 ? Colors.redAccent : AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 24),

              // Waveform visualizer
              SizedBox(
                height: 80,
                child: _waveform.isEmpty
                    ? Center(child: Text(
                        _isRecording ? '' : (hasRecording ? 'Tap play to preview' : 'Tap the button to start'),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ))
                    : CustomPaint(
                        size: Size(MediaQuery.of(context).size.width - 48, 80),
                        painter: _LiveWaveformPainter(_waveform, _isPlaying),
                      ),
              ),

              const Spacer(flex: 2),

              // Clip type toggle (voice vs ambient) — shown after recording
              if (hasRecording && widget.promptId == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ClipTypeChip(
                      icon: Icons.mic_rounded,
                      label: 'Voice',
                      active: _clipType == 'voice',
                      onTap: () => setState(() => _clipType = 'voice'),
                    ),
                    const SizedBox(width: 12),
                    _ClipTypeChip(
                      icon: Icons.nature_people_rounded,
                      label: 'Ambient',
                      active: _clipType == 'ambient',
                      onTap: () => setState(() => _clipType = 'ambient'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Location name (ambient only)
              if (hasRecording && _clipType == 'ambient') ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Where is this sound? (e.g. "rainy cafe in Tokyo")',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: Icon(Icons.place_rounded, color: AppTheme.textDim, size: 18),
                    ),
                    onChanged: (v) => _locationName = v.isEmpty ? null : v,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Topic selector (after recording)
              if (hasRecording) ...[
                Wrap(
                  spacing: 8, runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _topics.map((t) => GestureDetector(
                    onTap: () => setState(() => _topic = _topic == t ? null : t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _topic == t ? AppTheme.accent : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _topic == t ? AppTheme.accent : AppTheme.border,
                          width: _topic == t ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(t, style: TextStyle(
                        color: _topic == t ? Colors.white : AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: _topic == t ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Mood selector (after recording)
              if (hasRecording) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Mood (optional)', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                  ),
                ),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _moods.map((m) => GestureDetector(
                    onTap: () => setState(() => _mood = _mood == m ? null : m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _mood == m ? AppTheme.gold.withOpacity(0.15) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _mood == m ? AppTheme.gold : AppTheme.border,
                          width: _mood == m ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(m[0].toUpperCase() + m.substring(1), style: TextStyle(
                        color: _mood == m ? AppTheme.gold : AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: _mood == m ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Circle selector
              if (hasRecording && _circles.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _circleId,
                    decoration: const InputDecoration(
                      hintText: 'Post to a circle (optional)',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    dropdownColor: AppTheme.surface,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Public post')),
                      ..._circles.map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      )),
                    ],
                    onChanged: (v) => setState(() => _circleId = v),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Controls
              if (!hasRecording)
                // Record button
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isRecording
                              ? [Colors.red, Colors.red.shade800]
                              : [AppTheme.accent, const Color(0xFFC0431A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? Colors.red : AppTheme.accent)
                                .withOpacity(0.3 + (_isRecording ? 0.3 * _pulseController.value : 0)),
                            blurRadius: 20 + (_isRecording ? 20 * _pulseController.value : 0),
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white, size: 36,
                      ),
                    ),
                  ),
                )
              else
                // Preview + Post controls
                SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(
                        icon: Icons.refresh_rounded,
                        label: 'Redo',
                        onTap: _resetRecording,
                        outlined: true,
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _togglePreview,
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.surface,
                            border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppTheme.accent, size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ControlButton(
                        icon: _uploading ? null : Icons.send_rounded,
                        label: _uploading ? 'Posting...' : 'Post',
                        onTap: _uploading ? null : _upload,
                        filled: true,
                        loading: _uploading,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool filled;
  final bool loading;

  const _ControlButton({
    this.icon,
    required this.label,
    this.onTap,
    this.outlined = false,
    this.filled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textMuted,
        side: const BorderSide(color: AppTheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final bool isPlaying;
  _LiveWaveformPainter(this.waveform, this.isPlaying);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isPlaying ? AppTheme.accent : AppTheme.accent.withOpacity(0.7)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
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

class _ClipTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ClipTypeChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? AppTheme.accent : AppTheme.border,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? AppTheme.accent : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? AppTheme.accent : AppTheme.textMuted,
            )),
          ],
        ),
      ),
    );
  }
}
