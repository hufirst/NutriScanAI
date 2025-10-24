import 'dart:io';
import 'package:flutter/material.dart';

/// 전체 화면 이미지 뷰어
/// - 핀치 줌으로 확대/축소
/// - 탭으로 닫기
/// - 아래로 스와이프하면 닫기
/// - Android 뒤로가기 버튼으로 닫기
class FullscreenImageViewer extends StatefulWidget {
  final String imagePath;

  const FullscreenImageViewer({
    super.key,
    required this.imagePath,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  double _verticalDragDistance = 0;
  double _opacity = 1.0;
  bool _isInteracting = false; // InteractiveViewer 사용 중 여부
  DateTime? _lastInteractionEnd; // 마지막 인터랙션 종료 시간

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _closeViewer() {
    Navigator.of(context).pop();
  }

  /// 현재 줌 스케일 확인 (부동소수점 오차 고려)
  bool get _isZoomedOut {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    return scale >= 0.95 && scale <= 1.05; // 1.0에 가까우면 줌아웃 상태로 간주
  }

  /// 더블탭으로 줌 리셋
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  /// 최근에 인터랙션이 끝났는지 확인 (100ms 이내)
  bool get _recentlyInteracted {
    if (_lastInteractionEnd == null) return false;
    final elapsed = DateTime.now().difference(_lastInteractionEnd!);
    return elapsed.inMilliseconds < 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_opacity),
      body: GestureDetector(
        // 탭으로 닫기 - InteractiveViewer 인터랙션 직후가 아닐 때만
        onTap: () {
          if (_isZoomedOut && !_isInteracting && !_recentlyInteracted) {
            _closeViewer();
          }
        },
        // 더블탭으로 줌 리셋
        onDoubleTap: () {
          if (!_isZoomedOut) {
            setState(() {
              _resetZoom();
            });
          }
        },
        // 수직 드래그로 닫기
        onVerticalDragStart: (details) {
          // 줌아웃 상태이고 InteractiveViewer 인터랙션 중이 아닐 때만
          if (_isZoomedOut && !_isInteracting) {
            setState(() {
              _verticalDragDistance = 0;
            });
          }
        },
        onVerticalDragUpdate: (details) {
          // 줌아웃 상태이고 InteractiveViewer 인터랙션 중이 아닐 때만
          if (_isZoomedOut && !_isInteracting) {
            setState(() {
              _verticalDragDistance += details.delta.dy;
              // 드래그 거리에 따라 투명도 조절
              _opacity = (1.0 - (_verticalDragDistance.abs() / 300)).clamp(0.0, 1.0);
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_isZoomedOut && !_isInteracting) {
            // 충분히 드래그했으면 닫기
            if (_verticalDragDistance.abs() > 100) {
              _closeViewer();
            } else {
              // 원래 위치로 복귀
              setState(() {
                _verticalDragDistance = 0;
                _opacity = 1.0;
              });
            }
          }
        },
        child: Stack(
          children: [
            // 이미지 뷰어 (핀치 줌 지원)
            Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                // 인터랙션 시작
                onInteractionStart: (details) {
                  setState(() {
                    _isInteracting = true;
                  });
                },
                // 인터랙션 업데이트
                onInteractionUpdate: (details) {
                  setState(() {
                    _isInteracting = true;
                  });
                },
                // 인터랙션 종료
                onInteractionEnd: (details) {
                  setState(() {
                    _isInteracting = false;
                    _lastInteractionEnd = DateTime.now();
                  });
                },
                child: Transform.translate(
                  offset: Offset(0, _verticalDragDistance),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // 상단 안내 텍스트 (3초 후 사라짐)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '핀치로 확대/축소 • 더블탭으로 리셋 • 탭/스와이프로 닫기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
