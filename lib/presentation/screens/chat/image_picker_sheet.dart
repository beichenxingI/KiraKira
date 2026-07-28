import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 应用内相册选择器：从底部弹出的网格，全程不离开 App，
/// 避免跳转系统相册 Activity 导致 InAppWebView 的 PlatformView 命中区域失效。
///
/// 用法：
///   final files = await showImagePickerSheet(context, maxSelection: 9);
///   files 为选中图片的原始字节 + 建议文件名，可能为 null（取消）。
class PickedImage {
  final Uint8List bytes;
  final String name;
  PickedImage(this.bytes, this.name);
}

Future<List<PickedImage>?> showImagePickerSheet(
  BuildContext context, {
  int maxSelection = 9,
}) {
  return showModalBottomSheet<List<PickedImage>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ImagePickerSheet(maxSelection: maxSelection),
  );
}

class _ImagePickerSheet extends StatefulWidget {
  final int maxSelection;
  const _ImagePickerSheet({required this.maxSelection});

  @override
  State<_ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends State<_ImagePickerSheet> {
  List<AssetEntity> _assets = [];
  final Set<AssetEntity> _selected = {};
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      if (mounted) setState(() { _denied = true; _loading = false; });
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      if (mounted) setState(() { _loading = false; });
      return;
    }
    final recent = albums.first;
    final count = await recent.assetCountAsync;
    final assets = await recent.getAssetListRange(
      start: 0,
      end: count < 200 ? count : 200,
    );
    if (mounted) setState(() { _assets = assets; _loading = false; });
  }

  Future<void> _confirm() async {
    final result = <PickedImage>[];
    for (final asset in _selected) {
      final bytes = await asset.originBytes;
      if (bytes == null) continue;
      final name = await asset.titleAsync;
      result.add(PickedImage(
        bytes,
        name.isNotEmpty ? name : '${asset.id}.jpg',
      ));
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenH * 0.7,
      child: Column(
        children: [
          // 顶部拖动条 + 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消',
                      style: TextStyle(color: Colors.white70)),
                ),
                const Spacer(),
                Text(
                  _selected.isEmpty ? '选择图片' : '已选 ${_selected.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selected.isEmpty ? null : _confirm,
                  child: Text(
                    '完成',
                    style: TextStyle(
                      color: _selected.isEmpty
                          ? Colors.white30
                          : const Color(0xFF7C4DFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有相册访问权限',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('去设置开启'),
            ),
          ],
        ),
      );
    }
    if (_assets.isEmpty) {
      return const Center(
        child: Text('相册里没有图片',
            style: TextStyle(color: Colors.white70)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final isSelected = _selected.contains(asset);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selected.remove(asset);
              } else if (_selected.length < widget.maxSelection) {
                _selected.add(asset);
              }
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: asset.thumbnailDataWithSize(
                  const ThumbnailSize.square(200),
                ),
                builder: (context, snapshot) {
                  if (snapshot.data == null) {
                    return Container(color: Colors.white10);
                  }
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                },
              ),
              if (isSelected)
                Container(
                  color: Colors.black45,
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.check_circle,
                          color: Color(0xFF7C4DFF), size: 22),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}