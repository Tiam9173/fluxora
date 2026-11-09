import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<Rect?> showAppIconCrop(BuildContext context, ui.Image image) {
  return showDialog<Rect>(
    context: context,
    builder: (_) => _AppIconCropDialog(image: image),
  );
}

class _AppIconCropDialog extends StatefulWidget {
  const _AppIconCropDialog({required this.image});

  final ui.Image image;

  @override
  State<_AppIconCropDialog> createState() => _AppIconCropDialogState();
}

class _AppIconCropDialogState extends State<_AppIconCropDialog> {
  late final ui.Image _image = widget.image.clone();
  double _zoom = 1;
  Offset? _center;

  double get _width => _image.width.toDouble();
  double get _height => _image.height.toDouble();

  @override
  void dispose() {
    _image.dispose();
    super.dispose();
  }

  Rect get _crop {
    final edge = math.min(_width, _height) / _zoom;
    final center = _center ?? Offset(_width / 2, _height / 2);
    return Rect.fromLTWH(
      (center.dx - edge / 2).clamp(0.0, _width - edge),
      (center.dy - edge / 2).clamp(0.0, _height - edge),
      edge,
      edge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final crop = _crop;
    return AlertDialog(
      title: Text(chinese ? '裁剪图标' : 'Crop icon'),
      scrollable: true,
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Builder(
                builder: (context) => GestureDetector(
                  onPanUpdate: (event) => setState(() {
                    _center =
                        _crop.center -
                        event.delta * (_crop.width / context.size!.width);
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(painter: _CropPreview(_image, crop)),
                  ),
                ),
              ),
            ),
            _adjustment(
              chinese ? '缩放' : 'Zoom',
              (_zoom - 1) / 3,
              (value) => setState(() {
                _center = crop.center;
                _zoom = 1 + value * 3;
              }),
            ),
            if (_width - crop.width > 0)
              _adjustment(
                chinese ? '水平位置' : 'Horizontal position',
                crop.left / (_width - crop.width),
                (value) => setState(() {
                  _center = Offset(
                    value * (_width - crop.width) + crop.width / 2,
                    crop.center.dy,
                  );
                }),
              ),
            if (_height - crop.height > 0)
              _adjustment(
                chinese ? '垂直位置' : 'Vertical position',
                crop.top / (_height - crop.height),
                (value) => setState(() {
                  _center = Offset(
                    crop.center.dx,
                    value * (_height - crop.height) + crop.height / 2,
                  );
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(crop),
          child: Text(chinese ? '保存' : 'Save'),
        ),
      ],
    );
  }

  Widget _adjustment(String label, double value, ValueChanged<double> change) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: Semantics(
            label: label,
            child: Slider(value: value.clamp(0.0, 1.0), onChanged: change),
          ),
        ),
      ],
    );
  }
}

class _CropPreview extends CustomPainter {
  const _CropPreview(this.image, this.crop);

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      crop,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CropPreview oldDelegate) =>
      image != oldDelegate.image || crop != oldDelegate.crop;
}
