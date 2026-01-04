import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math';

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

  // DESIGN & GEOMETRY CONSTANTS
  static const int _ringsCount = 30;
  static const int _ringSegments = 16;
  static const double _radius = 300;
  static const double _ringSpacing = 350;
  static const double _farPlane = -(_ringsCount * _ringSpacing);
  static const _tubeColor = Color(0xFF00FF00);
  static const _playerColor = Color(0xFFFFFFFF);

  // GAME STATE
  double _distance = 0;
  double _tubeRotationZ = 0;
  double _rollVel = 0;
  double _pitch = 0.05 * pi;
  double _pitchVel = 0;
  double _yaw = 0;
  double _yawVel = 0;
  bool _isGameOver = false;
  bool _hasGround = true;
  double _fallVel = 0;
  double _playerY = -_radius + 40;

  // GEOMETRY
  List<List<vm.Vector3>> _rings = [];
  List<vm.Vector3> _playerSphere = [];

  @override
  void initState() {
    super.initState();
    _resetGame();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _distance = 0;
      _tubeRotationZ = 0;
      _rollVel = 0;
      _pitch = 0.05 * pi;
      _pitchVel = 0;
      _yaw = 0;
      _yawVel = 0;
      _isGameOver = false;
      _fallVel = 0;
      _playerY = -_radius + 40;
      _generateTubeRings();
      _generatePlayerSphere();
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

  void _generatePlayerSphere() {
      const double radius = 40.0;
      const int latitudeBands = 10;
      const int longitudeBands = 10;

      _playerSphere = [];

      for (int lat = 0; lat <= latitudeBands; lat++) {
          final double theta = lat * pi / latitudeBands;
          final double sinTheta = sin(theta);
          final double cosTheta = cos(theta);

          for (int long = 0; long <= longitudeBands; long++) {
              final double phi = long * 2 * pi / longitudeBands;
              final double sinPhi = sin(phi);
              final double cosPhi = cos(phi);

              final double x = cosPhi * sinTheta;
              final double y = cosTheta;
              final double z = sinPhi * sinTheta;

              _playerSphere.add(vm.Vector3(x, y, z) * radius);
          }
      }
  }

  void _onTick(Duration elapsed) {
    if (_isGameOver) return;
    setState(() {
      _distance += 25;
      _tubeRotationZ += _rollVel;
      _pitch = (_pitch + _pitchVel).clamp(0, pi * 0.2);
      _yaw += _yawVel;

      for (var ring in _rings) {
        for (var point in ring) {
          point.z += 25;
          if (point.z > 100) {
            point.z = _farPlane;
          }
        }
      }

      _hasGround = _checkGround(_tubeRotationZ);
      if (!_hasGround) {
        _fallVel -= 1.5;
        _playerY += _fallVel;
      }

      if (_playerY < -1000) {
        _isGameOver = true;
      }
    });
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
              tubeRotationZ: _tubeRotationZ,
              pitch: _pitch,
              yaw: _yaw,
              distance: _distance,
              playerSphere: _playerSphere,
              playerY: _playerY,
            ),
          ),
          _buildHud(),
          if (!_isGameOver) _buildControls(),
          if (_isGameOver) _buildGameOver(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            _buildControlButton('YAW L', () => _yawVel = 0.02, () => _yawVel = 0),
            const SizedBox(width: 10),
            _buildControlButton('YAW R', () => _yawVel = -0.02, () => _yawVel = 0),
          ]),
          Row(children: [
            _buildControlButton('ROLL L', () => _rollVel = 0.05, () => _rollVel = 0),
            const SizedBox(width: 10),
            Column(children: [
              _buildControlButton('PITCH UP', () => _pitchVel = 0.01, () => _pitchVel = 0),
              const SizedBox(height: 10),
              _buildControlButton('PITCH DOWN', () => _pitchVel = -0.01, () => _pitchVel = 0),
            ]),
            const SizedBox(width: 10),
            _buildControlButton('ROLL R', () => _rollVel = -0.05, () => _rollVel = 0),
          ],)
        ],
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
          color: _tubeColor.withOpacity(0.2),
          border: Border.all(color: _tubeColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(color: _tubeColor, fontSize: 18)),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 40,
      right: 20,
      child: DefaultTextStyle(
        style: const TextStyle(color: _tubeColor, fontSize: 16),
        child: Text(
          'DISTANCE: ${(_distance / 10).floor()}m\nSTATUS: ${_hasGround ? "STABLE" : "VOID DETECTED"}',
          textAlign: TextAlign.right,
        ),
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
            const Text('CRITICAL FAILURE', style: TextStyle(fontSize: 32, color: Colors.red, letterSpacing: 5)),
            const SizedBox(height: 20),
            Text('DISTANCE: ${(_distance / 10).floor()}m', style: const TextStyle(fontSize: 20, color: Colors.white)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _tubeColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: _resetGame,
              child: const Text('REBOOT SYSTEM', style: TextStyle(fontSize: 18, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

class TubePainter extends CustomPainter {
  final List<List<vm.Vector3>> rings;
  final double tubeRotationZ;
  final double pitch;
  final double yaw;
  final double distance;
  final List<vm.Vector3> playerSphere;
  final double playerY;

  TubePainter({
    required this.rings,
    required this.tubeRotationZ,
    required this.pitch,
    required this.yaw,
    required this.distance,
    required this.playerSphere,
    required this.playerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tubePaint = Paint()
      ..color = _TubeGameState._tubeColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final playerPaint = Paint()
      ..color = _TubeGameState._playerColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double fov = 75 * (pi / 180);
    final double near = 1;
    final double far = 20000;
    final double aspectRatio = size.width / size.height;

    final projectionMatrix = vm.makePerspectiveMatrix(fov, aspectRatio, near, far);

    final viewMatrix = vm.Matrix4.identity()
      ..translate(0.0, -_TubeGameState._radius + 150, -300.0)
      ..rotateX(pitch)
      ..rotateY(yaw);

    final tubeRotationMatrix = vm.Matrix4.identity()..rotateZ(tubeRotationZ);

    final List<List<Offset?>> projectedRings = [];
    final List<List<double>> ringDepths = [];

    for (final ring in rings) {
      final List<Offset?> projectedRing = [];
      final List<double> depths = [];
      for (final point in ring) {
        vm.Vector4 p = vm.Vector4(point.x, point.y, point.z, 1.0);
        p = tubeRotationMatrix * p;
        p = viewMatrix * p;

        depths.add(p.z.abs());

        p = projectionMatrix * p;

        if (p.w > 0) {
          p.x /= p.w;
          p.y /= p.w;
          projectedRing.add(Offset(
            (p.x + 1) * 0.5 * size.width,
            (1 - (p.y + 1) * 0.5) * size.height,
          ));
        } else {
          projectedRing.add(null);
        }
      }
      projectedRings.add(projectedRing);
      ringDepths.add(depths);
    }

    for (int i = 0; i < rings.length - 1; i++) {
      final double adjustedDistance = distance + rings[i].first.z.abs();
      final bool isHoleZone = (adjustedDistance % 3000) > 2000;

      for (int j = 0; j < _TubeGameState._ringSegments; j++) {
        final double angle = j * (2 * pi / _TubeGameState._ringSegments);
        final double normalizedAngle = ((angle - tubeRotationZ) % (2 * pi) + (2 * pi)) % (2 * pi);

        if (isHoleZone && normalizedAngle > 1.5 && normalizedAngle < 4.5) {
          continue; // Skip drawing this segment
        }

        final double fogFactor = (ringDepths[i][j] - 2000) / (15000 - 2000);
        final double opacity = 1.0 - fogFactor.clamp(0.0, 1.0);
        if (opacity <= 0) continue;

        final paint = tubePaint..color = _TubeGameState._tubeColor.withOpacity(opacity);

        final p1 = projectedRings[i][j];
        final p2 = projectedRings[i + 1][j];
        if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paint);

        final p3 = projectedRings[i][j];
        final p4 = projectedRings[i][(j + 1) % _TubeGameState._ringSegments];
        if (p3 != null && p4 != null) canvas.drawLine(p3, p4, paint);
      }
    }

    final List<Offset?> projectedSphere = [];
    for (final point in playerSphere) {
      vm.Vector4 p = vm.Vector4(point.x, point.y + playerY, point.z, 1.0);
      p = viewMatrix * p;
      p = projectionMatrix * p;

      if (p.w > 0) {
        p.x /= p.w;
        p.y /= p.w;
        projectedSphere.add(Offset(
          (p.x + 1) * 0.5 * size.width,
          (1 - (p.y + 1) * 0.5) * size.height,
        ));
      } else {
        projectedSphere.add(null);
      }
    }

    const int latitudeBands = 10;
    const int longitudeBands = 10;
    for (int lat = 0; lat < latitudeBands; lat++) {
        for (int long = 0; long < longitudeBands; long++) {
            final int first = (lat * (longitudeBands + 1)) + long;
            final int second = first + longitudeBands + 1;

            final p1 = projectedSphere[first];
            final p2 = projectedSphere[first + 1];
            if (p1 != null && p2 != null) canvas.drawLine(p1, p2, playerPaint);

            final p3 = projectedSphere[first];
            final p4 = projectedSphere[second];
            if (p3 != null && p4 != null) canvas.drawLine(p3, p4, playerPaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant TubePainter oldDelegate) => true;
}
