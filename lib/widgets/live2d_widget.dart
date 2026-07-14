import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirakira/services/live2d_service.dart';

class Live2DWidget extends StatefulWidget {
  final String modelPath;
  final double height;
  const Live2DWidget({super.key, this.modelPath = 'assets/live2d/Skeleton_Model/', this.height = 300});

  @override
  State<Live2DWidget> createState() => _Live2DWidgetState();
}

class _Live2DWidgetState extends State<Live2DWidget> with WidgetsbindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Live2DService.initialize();
      Live2DService.loadModel(widget.modelPath);
    });
  }

  @override
  void dispose() {
    Live2DService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (TargetPlatform.isAndroid) {
      return SizedBox(
        height: widget.height,
        child: AndroidView(
          viewType: 'platform_views/@google/live2d_android/Live2DSurfaceView',
          creationParamsCodec: const StandardMessageCodec(),
          onElement: (_) => {},
          onError: (e) => {},
        ),
      );
    }
    return Container(height: widget.height, alignment: Alignment.center, child: Column(children: [CircularProgressIndicator(color: Color(0xFFFFCD34D)), SizedBox(height: 16), Text('\u770b\u677f\u5a18\u8f7d\u8f93\u4e2d...', style: TextStyle(color: WhiteColors).withValues(alpha:0.3)))}));
  }
}
