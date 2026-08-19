import 'package:hive/hive.dart';

part 'face_info.g.dart';

/// Mirrors the HTML app's `face` object: `{cx, cy, faceH}`.
/// Captured once at capture-time and reused later for face-aware resize.
@HiveType(typeId: 0)
class FaceInfo extends HiveObject {
  FaceInfo({
    required this.cx,
    required this.cy,
    required this.faceHeightRatio,
  });

  /// Face center X, normalized 0..1 (mirror-corrected for front camera).
  @HiveField(0)
  final double cx;

  /// Face center Y, normalized 0..1.
  @HiveField(1)
  final double cy;

  /// Face bounding-box height / frame height, normalized 0..1.
  @HiveField(2)
  final double faceHeightRatio;

  FaceInfo copyWith({double? cx, double? cy, double? faceHeightRatio}) {
    return FaceInfo(
      cx: cx ?? this.cx,
      cy: cy ?? this.cy,
      faceHeightRatio: faceHeightRatio ?? this.faceHeightRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'cx': cx,
        'cy': cy,
        'faceHeightRatio': faceHeightRatio,
      };

  factory FaceInfo.fromJson(Map<String, dynamic> json) => FaceInfo(
        cx: (json['cx'] as num).toDouble(),
        cy: (json['cy'] as num).toDouble(),
        faceHeightRatio: (json['faceHeightRatio'] as num).toDouble(),
      );
}
