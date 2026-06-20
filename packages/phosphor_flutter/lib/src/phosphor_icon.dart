import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(
    Object icon, {
    Key? key,
    double? size,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
    Color? color,
    List<Shadow>? shadows,
    String? semanticLabel,
    TextDirection? textDirection,
    this.duotoneSecondaryOpacity = 0.20,
    this.duotoneSecondaryColor,
  })  : _icon = icon,
        _size = size,
        _fill = fill,
        _weight = weight,
        _grade = grade,
        _opticalSize = opticalSize,
        _color = color,
        _shadows = shadows,
        _semanticLabel = semanticLabel,
        _textDirection = textDirection,
        super(key: key);

  final Object _icon;
  final double? _size;
  final double? _fill;
  final double? _weight;
  final double? _grade;
  final double? _opticalSize;
  final Color? _color;
  final List<Shadow>? _shadows;
  final String? _semanticLabel;
  final TextDirection? _textDirection;
  final double duotoneSecondaryOpacity;
  final Color? duotoneSecondaryColor;

  @override
  Widget build(BuildContext context) {
    if (_icon is PhosphorDuotoneIconData) {
      final duotoneIcon = _icon as PhosphorDuotoneIconData;
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: duotoneSecondaryOpacity,
            child: Icon(
              duotoneIcon.secondary,
              size: _size,
              fill: _fill,
              weight: _weight,
              grade: _grade,
              opticalSize: _opticalSize,
              color: duotoneSecondaryColor ?? _color,
              shadows: _shadows,
              semanticLabel: _semanticLabel,
              textDirection: _textDirection,
            ),
          ),
          Icon(
            duotoneIcon.primary,
            key: key,
            size: _size,
            fill: _fill,
            weight: _weight,
            grade: _grade,
            opticalSize: _opticalSize,
            color: _color,
            shadows: _shadows,
            semanticLabel: _semanticLabel,
            textDirection: _textDirection,
          ),
        ],
      );
    }
    return Icon(
      _icon as IconData,
      key: key,
      size: _size,
      fill: _fill,
      weight: _weight,
      grade: _grade,
      opticalSize: _opticalSize,
      color: _color,
      shadows: _shadows,
      semanticLabel: _semanticLabel,
      textDirection: _textDirection,
    );
  }
}
