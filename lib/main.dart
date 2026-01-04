
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TubeGame(),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'monospace',
      ),
    );
  }
}

class TubeGame extends StatefulWidget {
  const TubeGame({super.key});

  @override
  State<TubeGame> createState() => _TubeGameState();
}

class _TubeGameState extends State<TubeGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // Game State
  double _distance = 0;
  bool _isGameOver = false;
  final vm.Vector3 _playerPos = vm.Vector3(0, -270.0, 0);
  double _fallVel = 0;
  bool _hasGround = true;

  // Camera & Controls State
  double _tubeRotationZ = 0;
  double _pitch = -0.15;
  double _yaw = 0;

  double _rollVel = 0;
  double _pitchVel = 0;
  double _yawVel = 0;

  // Tube Geometry
  static const double _radius = 300;
  static const double _ringSpacing = 250;
  static const int _ringsCount = 60;
  static const int _ringSegments = 32;
  static const double _farPlane = -_ringsCount * _ringSpacing;

  List<List<vm.Vector3>> _rings = [];

  @override
  void initState() {
    super.initState();
    _generateTubeRings();
    _ticker = createTicker(_onTick)..start();
  }

  void _generateTubeRings() {
    _rings = [];
    for (int i = 0; i < _ringsCount; i++) {
      final List<vm.Vector3> ring = [];
      for (int j = 0; j < _ringSegments; j++) {
        final double angle = j * (2 * pi / _ringSegments);
        final double x = cos(angle) * _radius;
        final double y = sin(angle) * _radius;
        final double z = -(i * _ringSpacing);
        ring.add(vm.Vector3(x, y, z));
      }
      _rings.add(ring);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_isGameOver) return;

    setState(() {
      // Update camera and tube rotation based on velocities
      _tubeRotationZ += _rollVel;
      _pitch = (_pitch + _pitchVel).clamp(-0.4, 0.4);
      _yaw += _yawVel;

      // Move the rings
      for (final ring in _rings) {
        for (final point in ring) {
          point.z += 25; // Speed
        }
      }

      // Recycle rings
      _rings.where((ring) => ring.first.z > 100).forEach((ring) {
        for (final point in ring) {
          point.z = _farPlane;
        }
      });

      _distance += 25;

      _hasGround = _checkGround(_tubeRotationZ);

      if (!_hasGround) {
        _fallVel -= 1.5;
        _playerPos.y += _fallVel;
      }

      if (_playerPos.y < -2000) {
        _isGameOver = true;
      }
    });
  }

  bool _checkGround(double rotation) {
    final cycle = _distance % 3000;
    if (cycle > 2000) {
      final normRot = ((rotation % (pi * 2)) + (pi * 2)) % (pi * 2);
      if (normRot > 1.5 && normRot < 4.5) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: TubePainter(
              rings: _rings,
              pitch: _pitch,
              yaw: _yaw,
              tubeRotationZ: _tubeRotationZ,
              playerPos: _playerPos,
            ),
          ),
          // The HUD will go here
          _buildHud(),
          // The Game Over screen will go here
          // CONTROLS
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // YAW (Q/E)
                Row(children: [
                   _buildControlButton('Q', () => _yawVel = 0.015, () => _yawVel = 0),
                   const SizedBox(width: 10),
                  _buildControlButton('E', () => _yawVel = -0.015, () => _yawVel = 0),
                ]),
                // PITCH (W/S) & ROLL (A/D)
                Row(children: [
                  _buildControlButton('A', () => _rollVel = 0.05, () => _rollVel = 0),
                  const SizedBox(width: 10),
                  Column(children: [
                    _buildControlButton('W', () => _pitchVel = 0.01, () => _pitchVel = 0),
                    const SizedBox(height: 10),
                    _buildControlButton('S', () => _pitchVel = -0.01, () => _pitchVel = 0),
                  ]),
                  const SizedBox(width: 10),
                  _buildControlButton('D', () => _rollVel = -0.05, () => _rollVel = 0),
                ],)
              ],
            ),
          ),
          if (_isGameOver) _buildGameOver(),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CRITICAL FAILURE',
              style: TextStyle(fontSize: 32, color: Colors.red, letterSpacing: 5),
            ),
            const SizedBox(height: 20),
            Text(
              'DISTANCE: ${(_distance / 10).floor()}m',
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: _resetGame,
              child: const Text(
                'REBOOT SYSTEM',
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      _distance = 0;
      _playerPos.setValues(0, -270.0, 0);
      _fallVel = 0;
      _tubeRotationZ = 0;
      _pitch = -0.15;
      _yaw = 0;
      _rollVel = 0;
      _pitchVel = 0;
      _yawVel = 0;
      _generateTubeRings();
    });
  }

  Widget _buildHud() {
    return Positioned(
      top: 40,
      right: 20,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
        child: Text(
          'DISTANCE: ${(_distance / 10).floor()}m\nSTATUS: ${_hasGround ? "STABLE" : "VOID DETECTED"}',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  Widget _buildControlButton(String label, VoidCallback onPressed, VoidCallback onReleased) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.2),
          border: Border.all(color: Colors.greenAccent),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(color: Colors.greenAccent, fontSize: 18)),
      ),
    );
  }
}

class TubePainter extends CustomPainter {
  final List<List<vm.Vector3>> rings;
  final double pitch;
  final double yaw;
  final double tubeRotationZ;
  final vm.Vector3 playerPos;

  TubePainter({
    required this.rings,
    required this.pitch,
    required this.yaw,
    required this.tubeRotationZ,
    required this.playerPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double fov = 60 * (pi / 180);
    final double near = 1;
    final double far = 20000;
    final double aspectRatio = size.width / size.height;

    final projectionMatrix = vm.makePerspectiveMatrix(fov, aspectRatio, near, far);

    final viewMatrix = vm.Matrix4.identity()
      ..rotateX(-pitch)
      ..rotateY(-yaw);

    final tubeRotationMatrix = vm.Matrix4.identity()..rotateZ(tubeRotationZ);

    for (final ring in rings) {
      final List<Offset?> projectedPoints = [];

      for (int i = 0; i < ring.length; i++) {
        vm.Vector4 p = vm.Vector4(ring[i].x, ring[i].y, ring[i].z, 1.0);

        p = tubeRotationMatrix * p;
        p = viewMatrix * p;

        final double zDepth = p.z;

        p = projectionMatrix * p;

        if (p.w > 0) {
          p.x /= p.w;
          p.y /= p.w;

          // Don't draw points behind the camera or too far
          if (zDepth > -near || zDepth < -10000) {
             projectedPoints.add(null);
             continue;
          }

          final screenX = (p.x + 1) * 0.5 * size.width;
          final screenY = (1 - (p.y + 1) * 0.5) * size.height;

          // Fog Calculation
          final double fogFactor = (zDepth.abs() - 2000) / (15000 - 2000);
          final double opacity = 1.0 - fogFactor.clamp(0.0, 1.0);

          if (opacity > 0) {
             paint.color = Colors.greenAccent.withOpacity(opacity);
             projectedPoints.add(Offset(screenX, screenY));
          } else {
             projectedPoints.add(null);
          }
        } else {
          projectedPoints.add(null);
        }
      }

      for (int i = 0; i < projectedPoints.length; i++) {
        final p1 = projectedPoints[i];
        final p2 = projectedPoints[(i + 1) % projectedPoints.length];
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }

    // Draw Player
    vm.Vector4 playerP = vm.Vector4(playerPos.x, playerPos.y, playerPos.z, 1.0);
    playerP = viewMatrix * playerP;

    final double playerDepth = playerP.z.abs();

    playerP = projectionMatrix * playerP;

    if (playerP.w > 0) {
      playerP.x /= playerP.w;
      playerP.y /= playerP.w;
      final screenX = (playerP.x + 1) * 0.5 * size.width;
      final screenY = (1 - (playerP.y + 1) * 0.5) * size.height;

      final double perspectiveScale = 1 - (playerDepth / 15000).clamp(0.0, 1.0);
      final double playerSize = 30 * perspectiveScale;

      final playerPaint = Paint()..color = Colors.greenAccent;
      if (playerSize > 1) {
        canvas.drawCircle(Offset(screenX, screenY), playerSize, playerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TubePainter oldDelegate) => true;
}
