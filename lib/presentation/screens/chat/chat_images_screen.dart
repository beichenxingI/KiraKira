import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/widgets/chat/image_generation_dialog.dart';
import 'package:kirakira/presentation/screens/chat/image_picker_sheet.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:kirakira/data/models/chat.dart';

/// 会话图片界面：图片统一存于 chat_images/{chatId}/，与 WebView 完全隔离。
/// 文件名前缀区分来源：user_ = 用户发送，ai_ = AI生成。
class ChatImagesScreen extends ConsumerStatefulWidget {
  final String chatId;

  /// 可选发送回调：由聊天页传入。为 null 时相册页不显示"发送"选项。
  final Future<void> Function(File file)? onSend;

  const ChatImagesScreen({super.key, required this.chatId, this.onSend});

  static Future<Directory> imagesDir(String chatId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'chat_images', chatId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  ConsumerState<ChatImagesScreen> createState() => _ChatImagesScreenState();
}

class _ChatImagesScreenState extends ConsumerState<ChatImagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<File> _userImages = [];
  List<File> _aiImages = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dir = await ChatImagesScreen.imagesDir(widget.chatId);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final ext = p.extension(f.path).toLowerCase();
          return ['.png', '.jpg', '.jpeg', '.webp'].contains(ext);
        })
        .toList()
      ..sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
    final user = <File>[];
    final ai = <File>[];
    for (final f in files) {
      final name = p.basename(f.path);
      if (name.startsWith('ai_')) {
        ai.add(f);
      } else {
        // 无前缀的历史图片也归到用户发送
        user.add(f);
      }
    }
    if (mounted) {
      setState(() {
        _userImages = user;
        _aiImages = ai;
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = ref.read(activeChatProvider);
      final lastAi = state.messages.lastWhere(
        (m) => m.role != MessageRole.user,
        orElse: () => state.messages.isNotEmpty
            ? state.messages.last
            : throw Exception('没有消息'),
      );
      final result = await ImageGenerationDialog.show(
        context,
        basePrompt: lastAi.content,
        characterName: state.character?.name,
        mode: ImageGenMode.lastMessage,
      );
      if (result != null && result.images.isNotEmpty) {
        final dir = await ChatImagesScreen.imagesDir(widget.chatId);
        for (final bytes in result.images) {
          final name = 'ai_${const Uuid().v4()}.${result.format}';
          await File(p.join(dir.path, name)).writeAsBytes(bytes);
        }
        await _load();
        if (mounted) {
          _tab.animateTo(1); // 生成后跳到AI子页
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已生成 ${result.images.length} 张图片')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await showImagePickerSheet(context, maxSelection: 9);
    if (picked == null || picked.isEmpty) return;
    final dir = await ChatImagesScreen.imagesDir(widget.chatId);
    for (final img in picked) {
      var ext = p.extension(img.name);
      if (ext.isEmpty) ext = '.jpg';
      final name = 'user_${const Uuid().v4()}$ext';
      await File(p.join(dir.path, name)).writeAsBytes(img.bytes);
    }
    await _load();
    if (mounted) _tab.animateTo(0); // 添加后跳到用户子页
  }

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除图片'),
        content: const Text('确定删除这张图片吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await f.delete();
      } catch (_) {}
      await _load();
    }
  }

  /// 点击图片弹出操作菜单：发送到聊天 / 查看大图 / 删除。
  /// 菜单在纯 Flutter 相册页内弹出，不涉及 WebView。
  void _showImageActions(File f) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onSend != null)
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('发送到聊天'),
                onTap: () async {
                  Navigator.pop(ctx); // 关菜单
                  await widget.onSend!(f);
                  if (mounted) Navigator.pop(context); // 关相册页，回到聊天
                },
              ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('查看大图'),
              onTap: () {
                Navigator.pop(ctx);
                _viewFull(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(ctx);
                _delete(f);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewFull(File f) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(
          child: InteractiveViewer(child: Image.file(f)),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会话图片'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '用户发送'),
            Tab(text: 'AI生成'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildGrid(_userImages, '还没有图片，点右下角从相册添加'),
                _buildGrid(_aiImages, '还没有生成图片，点右下角生成'),
              ],
            ),
    );
  }

  Widget _buildFab() {
    // 根据当前子页显示不同的操作按钮
    return AnimatedBuilder(
      animation: _tab,
      builder: (context, _) {
        if (_tab.index == 0) {
          return FloatingActionButton.extended(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('从相册添加'),
          );
        }
        return FloatingActionButton.extended(
          onPressed: _busy ? null : _generate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: const Text('生成图片'),
        );
      },
    );
  }

  Widget _buildGrid(List<File> images, String emptyHint) {
    if (images.isEmpty) {
      return Center(child: Text(emptyHint));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) {
        final f = images[i];
        return GestureDetector(
          onTap: () => _showImageActions(f),
          onLongPress: () => _delete(f),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(f, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}