import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// An imported sherpa-onnx TTS model entry
class TtsModelEntry {
  final String name;
  final String modelType; // 'vits' / 'kokoro' / 'matcha'
  final String modelPath;
  final String tokens;
  final String? lexicon;
  final String? voices; // kokoro voices.bin
  final String? vocoder; // matcha vocoder
  final String? dictDir;
  final String? dataDir; // espeak-ng-data
  final String? ruleFsts;
  final String? ruleFars;
  final int sampleRate;
  final int numSpeakers;
  final DateTime importedAt;

  const TtsModelEntry({
    required this.name,
    required this.modelType,
    required this.modelPath,
    required this.tokens,
    this.lexicon,
    this.voices,
    this.vocoder,
    this.dictDir,
    this.dataDir,
    this.ruleFsts,
    this.ruleFars,
    this.sampleRate = 16000,
    this.numSpeakers = 1,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'modelType': modelType,
        'modelPath': modelPath,
        'tokens': tokens,
        if (lexicon != null) 'lexicon': lexicon,
        if (voices != null) 'voices': voices,
        if (vocoder != null) 'vocoder': vocoder,
        if (dictDir != null) 'dictDir': dictDir,
        if (dataDir != null) 'dataDir': dataDir,
        if (ruleFsts != null) 'ruleFsts': ruleFsts,
        if (ruleFars != null) 'ruleFars': ruleFars,
        'sampleRate': sampleRate,
        'numSpeakers': numSpeakers,
        'importedAt': importedAt.toIso8601String(),
      };

  factory TtsModelEntry.fromJson(Map<String, dynamic> json) => TtsModelEntry(
        name: json['name'] as String,
        modelType: json['modelType'] as String,
        modelPath: json['modelPath'] as String,
        tokens: json['tokens'] as String,
        lexicon: json['lexicon'] as String?,
        voices: json['voices'] as String?,
        vocoder: json['vocoder'] as String?,
        dictDir: json['dictDir'] as String?,
        dataDir: json['dataDir'] as String?,
        ruleFsts: json['ruleFsts'] as String?,
        ruleFars: json['ruleFars'] as String?,
        sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 16000,
        numSpeakers: (json['numSpeakers'] as num?)?.toInt() ?? 1,
        importedAt:
            DateTime.tryParse(json['importedAt'] as String? ?? '') ??
                DateTime.now(),
      );

  /// Model directory (the directory containing modelPath)
  Directory? get directory {
    final dir = Directory(p.dirname(modelPath));
    return dir.existsSync() ? dir : null;
  }

  /// Model file size in bytes
  int get modelSizeBytes {
    final f = File(modelPath);
    return f.existsSync() ? f.lengthSync() : 0;
  }
}

/// sherpa-onnx TTS model import/manifest/deletion service.
///
/// The models directory convention follows STT: `<docDir>/KiraKira/models/tts/`,
/// with the manifest persisted to manifest.json inside that directory.
class TtsModelService {
  TtsModelService._();
  static final TtsModelService instance = TtsModelService._();

  static const _modelsSubDir = 'KiraKira/models/tts';
  static const _manifestName = 'manifest.json';

  /// Get the models directory (create it if missing)
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _modelsSubDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Load the model manifest
  Future<List<TtsModelEntry>> loadManifest() async {
    try {
      final dir = await getModelsDirectory();
      final manifestFile = File(p.join(dir.path, _manifestName));
      if (!await manifestFile.exists()) return [];
      final json = jsonDecode(await manifestFile.readAsString()) as List;
      return json
          .whereType<Map<String, dynamic>>()
          .map(TtsModelEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save the model manifest
  Future<void> _saveManifest(List<TtsModelEntry> entries) async {
    final dir = await getModelsDirectory();
    final manifestFile = File(p.join(dir.path, _manifestName));
    final json = entries.map((e) => e.toJson()).toList();
    await manifestFile.writeAsString(jsonEncode(json), flush: true);
  }

  /// Import a model: pick a tar.bz2 via FilePicker, extract, scan, and write the manifest.
  /// Returns the model name, or null if selection was cancelled.
  Future<String?> importModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: '选择 sherpa-onnx TTS 模型包.tar.bz2）',
    );
    if (result == null || result.files.single.path == null) return null;

    final archivePath = result.files.single.path!;
    
    // Validate file extension
    if (!archivePath.toLowerCase().endsWith('.tar.bz2')) {
      throw Exception('仅支持 .tar.bz2 格式的模型包');
    }
    final baseName = p.basenameWithoutExtension(archivePath);
    // xxx.tar.bz2 becomes xxx
    final modelName =
        baseName.toLowerCase().endsWith('.tar') ? baseName.substring(0, baseName.length - 4) : baseName;

    final dir = await getModelsDirectory();
    final modelDir = Directory(p.join(dir.path, modelName));
    if (await modelDir.exists()) {
      throw Exception('模型 "$modelName" 已存在，请先删除或改名');
    }
    await modelDir.create(recursive: true);

    try {
      final bytes = await File(archivePath).readAsBytes();
      final tarBytes = BZip2Decoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(tarBytes);

      // Tar archives often contain a top-level directory (xxx/...); normalize by extracting everything under modelDir
      String? modelPath;
      String? tokensPath;
      String? lexiconPath;
      String? voicesPath;
      String? vocoderPath;
      String? dictDir;
      String? dataDir;
      String? ruleFsts;
      String? ruleFars;

      for (final file in archive.files) {
        if (!file.isFile) continue;
        final rel = file.name;
        // Strip the top-level directory prefix
        final parts = p.split(rel);
        final inner = parts.length > 1 ? p.joinAll(parts.sublist(1)) : rel;
        final fileName = p.basename(inner);
        final destPath = p.join(modelDir.path, inner);
        final outFile = File(destPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);

        if (fileName.endsWith('.onnx')) {
          // Matcha acoustic model is named model-steps-*.onnx; the vocoder is vocos/hifigan
          final lower = fileName.toLowerCase();
          if (lower.contains('vocos') || lower.contains('hifigan')) {
            vocoderPath ??= destPath;
          } else {
            modelPath ??= destPath;
          }
        }
        if (fileName == 'tokens.txt') tokensPath = destPath;
        if (fileName.startsWith('lexicon')) lexiconPath ??= destPath;
        if (fileName == 'voices.bin') voicesPath = destPath;
        if (fileName == 'rule.far') ruleFars = destPath;
        if (fileName.endsWith('.fst')) ruleFsts ??= destPath;
        if (fileName == 'espeak-ng-data' || inner.startsWith('espeak-ng-data')) {
          dataDir = p.join(modelDir.path, 'espeak-ng-data');
        }
        if (p.basename(p.dirname(inner)) == 'dict' || inner.contains('/dict/')) {
          dictDir = p.join(modelDir.path, 'dict');
        }
      }

   // Detect ncnn format
   final hasNcnn = modelDir
       .listSync()
       .any((f) => f.path.endsWith('.ncnn.param'));
   if (hasNcnn && modelPath == null) {
     throw Exception(
       '检测到 ncnn 格式模型包，当前版本仅支持 onnx 格式。\n'
       '请从以下地址下载 onnx 模型：\n'
       'https://github.com/k2-fsa/sherpa-onnx/releases\n'
       '选择文件名包含 "onnx" 的模型包（如 vits-piper-zh_CN）'
     );
   }
   
   if (modelPath == null || tokensPath == null) {
     throw Exception('模型包不完整：缺少 .onnx 模型或 tokens.txt');
   }

      // Infer model type: voices.bin means kokoro, vocoder means matcha, otherwise vits
      String modelType = 'vits';
      if (voicesPath != null) {
        modelType = 'kokoro';
      } else if (vocoderPath != null) {
        modelType = 'matcha';
      }

      // Read model metadata (numSpeakers/sampleRate)
      int numSpeakers = 1;
      int sampleRate = 16000;
      
      // Try to read the .onnx.json config file
      final jsonFile = File(p.join(modelDir.path, '$modelName.onnx.json'));
      if (await jsonFile.exists()) {
        try {
          final jsonContent = await jsonFile.readAsString();
          final meta = jsonDecode(jsonContent) as Map<String, dynamic>;
          numSpeakers = (meta['num_speakers'] as int?) ?? 1;
          sampleRate = (meta['sample_rate'] as int?) ?? 16000;
        } catch (e) {
          // JSON parsing failed; keep default values
        }
      }

      final entry = TtsModelEntry(
        name: modelName,
        modelType: modelType,
        modelPath: modelPath,
        tokens: tokensPath,
        lexicon: lexiconPath,
        voices: voicesPath,
        vocoder: vocoderPath,
        dictDir: dictDir,
        dataDir: dataDir,
        ruleFsts: ruleFsts,
        ruleFars: ruleFars,
        numSpeakers: numSpeakers,
        sampleRate: sampleRate, 
        importedAt: DateTime.now(),
      );

      final manifest = await loadManifest();
      manifest.removeWhere((e) => e.name == modelName);
      manifest.add(entry);
      await _saveManifest(manifest);
      return modelName;
    } catch (e) {
      // On import failure, remove the partially extracted directory
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// Delete a model (directory and manifest entry)
  Future<void> deleteModel(String modelName) async {
    final manifest = await loadManifest();
    final entry = manifest.firstWhere(
      (e) => e.name == modelName,
      orElse: () => throw Exception('模型 "$modelName" 不存在'),
    );
    final dir = Directory(p.dirname(entry.modelPath));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    manifest.removeWhere((e) => e.name == modelName);
    await _saveManifest(manifest);
  }

  /// Clean up temporary WAV files (tts_*.wav)
  Future<int> clearTempWavFiles() async {
    final tmpDir = await getTemporaryDirectory();
    var count = 0;
    if (!await tmpDir.exists()) return 0;
    await for (final f in tmpDir.list()) {
      if (f is File &&
          p.basename(f.path).startsWith('tts_') &&
          f.path.endsWith('.wav')) {
        await f.delete().catchError((_) => f);
        count++;
      }
    }
    return count;
  }
}
