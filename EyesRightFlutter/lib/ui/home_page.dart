import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../models/eye_models.dart';
import '../pipeline/eye_pipeline.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();
  EyePipeline? _pipeline;
  OverlayMode _mode = OverlayMode.ahAhAh;
  Uint8List? _sourceBytes;
  Uint8List? _resultBytes;
  String _status = '正在加载模型…';
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initPipeline();
  }

  Future<void> _initPipeline() async {
    try {
      final pipeline = await EyePipeline.create();
      if (!mounted) {
        await pipeline.dispose();
        return;
      }
      setState(() {
        _pipeline = pipeline;
        _ready = true;
        _status = '选一张猫/狗正脸照片开始（完全本地处理）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '模型加载失败：$e';
        _ready = false;
      });
    }
  }

  @override
  void dispose() {
    _pipeline?.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (!_ready || _busy) return;
    final file = await _picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _sourceBytes = bytes;
      _resultBytes = null;
      _status = '已选图，点「开始贴眼」';
    });
  }

  Future<void> _process() async {
    final pipeline = _pipeline;
    final source = _sourceBytes;
    if (pipeline == null || source == null || _busy) return;

    setState(() {
      _busy = true;
      _status = '检测中…';
      _resultBytes = null;
    });

    try {
      final result = await pipeline.processBytes(source, _mode);
      if (!mounted) return;
      setState(() {
        _resultBytes = result;
        _status = '完成 · ${_mode.label}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e is PipelineException ? e.message : '处理失败：$e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final bytes = _resultBytes;
    if (bytes == null || _busy) return;
    try {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        setState(() => _status = '需要相册写入权限才能保存');
        return;
      }
      await Gal.putImageBytes(bytes, name: 'eyes_right_${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      setState(() => _status = '已保存到相册');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到相册')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Eyes Right'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _status,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              SegmentedButton<OverlayMode>(
                segments: [
                  for (final mode in OverlayMode.values)
                    ButtonSegment(value: mode, label: Text(mode.label)),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _panel('原图', _sourceBytes)),
                    const SizedBox(width: 12),
                    Expanded(child: _panel('结果', _resultBytes)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: (!_ready || _busy) ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('相册'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: (!_ready || _busy) ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                  FilledButton.icon(
                    onPressed: (!_ready || _busy || _sourceBytes == null) ? null : _process,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: const Text('开始贴眼'),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_resultBytes == null || _busy) ? null : _save,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '完全本地运行，不会上传照片',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(String title, Uint8List? bytes) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: bytes == null
                  ? const Center(
                      child: Text(
                        '暂无',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
