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
  static const int _ringSegments = 16;
  static const double _ringSpacing = 350;
  final _random = Random();
  late double _outerRadius;
  late double _innerRadius;
  late int _tubeLength;
  late double _farPlane;
  static final _tubeColor = Colors.grey[700]!;
  static const _playerColor = Colors.greenAccent;

  // GAME STATE
  double _distance = 0;
  double _tubeRotationZ = 0;
  double _rollVel = 0;
  late double _pitch;
  double _pitchVel = 0;
  double _yaw = 0;
  double _yawVel = 0;
  bool _isGameOver = false;
  bool _hasGround = true;
  double _fallVel = 0;
  late double _playerY;
  double _playerZ = 0;

  // GEOMETRY
  List<List<vm.Vector3>> _outerRings = [];
  List<List<vm.Vector3>> _innerRings = [];
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
      _tubeLength = 20 + _random.nextInt(21);
      _outerRadius = 250 + _random.nextDouble() * 150;
      _innerRadius = _outerRadius - 50;
      _farPlane = -(_tubeLength * _ringSpacing);

      _distance = 0;
      _tubeRotationZ = 0;
      _rollVel = 0;
      _pitch = 8 * (pi / 180);
      _pitchVel = 0;
      _yaw = 0;
      _yawVel = 0;
      _isGameOver = false;
      _fallVel = 0;
      _playerY = -_innerRadius + 40;
      _playerZ = -(_tubeLength * _ringSpacing * 0.1);
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
    _outerRings = [];
    _innerRings = [];
    for (int i = 0; i < _tubeLength; i++) {
      final List<vm.Vector3> outerRing = [];
      final List<vm.Vector3> innerRing = [];
      for (int j = 0; j < _ringSegments; j++) {
        final double angle = j * (2 * pi / _ringSegments);
        final double z = -(i * _ringSpacing);

        // Outer ring
        final double ox = cos(angle) * _outerRadius;
        final double oy = sin(angle) * _outerRadius;
        outerRing.add(vm.Vector3(ox, oy, z));

        // Inner ring
        final double ix = cos(angle) * _innerRadius;
        final double iy = sin(angle) * _innerRadius;
        innerRing.add(vm.Vector3(ix, iy, z));
      }
      _outerRings.add(outerRing);
      _innerRings.add(innerRing);
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

      for (var rings in [_outerRings, _innerRings]) {
        for (var ring in rings) {
          for (var point in ring) {
            point.z += 25;
            if (point.z > 100) {
            point.z = _farPlane;
            }
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
              outerRings: _outerRings,
              innerRings: _innerRings,
              tubeRotationZ: _tubeRotationZ,
              pitch: _pitch,
              yaw: _yaw,
              distance: _distance,
              playerSphere: _playerSphere,
              playerY: _playerY,
              playerZ: _playerZ,
              outerRadius: _outerRadius,
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
        child: Text(label, style: TextStyle(color: _tubeColor, fontSize: 18)),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 40,
      right: 20,
      child: DefaultTextStyle(
        style: TextStyle(color: _tubeColor, fontSize: 16),
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
  final List<List<vm.Vector3>> outerRings;
  final List<List<vm.Vector3>> innerRings;
  final double tubeRotationZ;
  final double pitch;
  final double yaw;
  final double distance;
  final List<vm.Vector3> playerSphere;
  final double playerY;
  final double playerZ;
  final double outerRadius;

  TubePainter({
    required this.outerRings,
    required this.innerRings,
    required this.tubeRotationZ,
    required this.pitch,
    required this.yaw,
    required this.distance,
    required this.playerSphere,
    required this.playerY,
    required this.playerZ,
    required this.outerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tubePaint = Paint()..style = PaintingStyle.fill;
    final playerPaint = Paint()
      ..color = _TubeGameState._playerColor
      ..style = PaintingStyle.fill;

    final double fov = 75 * (pi / 180);
    final double near = 1;
    final double far = 20000;
    final double aspectRatio = size.width / size.height;

    final projectionMatrix = vm.makePerspectiveMatrix(fov, aspectRatio, near, far);
    final viewMatrix = vm.Matrix4.identity()
      ..translate(0.0, -this.outerRadius + 150, -300.0)
      ..rotateX(pitch)
      ..rotateY(yaw);
    final tubeRotationMatrix = vm.Matrix4.identity()..rotateZ(tubeRotationZ);

    final List<_ProjectedPolygon> polygons = [];

    // --- 3D Projection and Polygon Creation ---
    Offset? project(vm.Vector3 p3d) {
      vm.Vector4 p4d = vm.Vector4(p3d.x, p3d.y, p3d.z, 1.0);
      p4d = tubeRotationMatrix * p4d;
      p4d = viewMatrix * p4d;
      final zDepth = p4d.z;
      p4d = projectionMatrix * p4d;

      if (p4d.w > 0) {
        p4d.x /= p4d.w;
        p4d.y /= p4d.w;
        return Offset(
          (p4d.x + 1) * 0.5 * size.width,
          (1 - (p4d.y + 1) * 0.5) * size.height,
        );
      }
      return null;
    }

    // --- Tube Polygons ---
    for (int i = 0; i < outerRings.length - 1; i++) {
      for (int j = 0; j < _TubeGameState._ringSegments; j++) {
        final int nextJ = (j + 1) % _TubeGameState._ringSegments;

        // Points for the quad
        final p1 = outerRings[i][j];
        final p2 = outerRings[i+1][j];
        final p3 = outerRings[i+1][nextJ];
        final p4 = outerRings[i][nextJ];

        final ip1 = innerRings[i][j];
        final ip2 = innerRings[i+1][j];
        final ip3 = innerRings[i+1][nextJ];
        final ip4 = innerRings[i][nextJ];

        // --- Backface Culling (Simple version) ---
        vm.Vector3 v1 = p2 - p1;
        vm.Vector3 v2 = p4 - p1;
        vm.Vector3 normal = v1.cross(v2).normalized();
        vm.Vector3 toCamera = (vm.Vector3(0,0,0) - (p1+p2+p3+p4)/4).normalized();
        if (normal.dot(toCamera) < 0) continue;

        // Project points
        final projP1 = project(p1);
        final projP2 = project(p2);
        final projP3 = project(p3);
        final projP4 = project(p4);

        final projIp1 = project(ip1);
        final projIp2 = project(ip2);
        final projIp3 = project(ip3);
        final projIp4 = project(ip4);

        if (projP1 != null && projP2 != null && projP3 != null && projP4 != null) {
          final zDepth = (p1.z + p2.z + p3.z + p4.z) / 4;
          polygons.add(_ProjectedPolygon(
            points: [projP1, projP2, projP3, projP4],
            zDepth: zDepth,
            color: _TubeGameState._tubeColor,
          ));
        }

        if (projIp1 != null && projIp2 != null && projIp3 != null && projIp4 != null) {
            // Backface culling for inner walls
            v1 = ip2 - ip1;
            v2 = ip4 - ip1;
            normal = v2.cross(v1).normalized();
            toCamera = (vm.Vector3(0,0,0) - (ip1+ip2+ip3+ip4)/4).normalized();
            if (normal.dot(toCamera) < 0) continue;

            final zDepth = (ip1.z + ip2.z + ip3.z + ip4.z) / 4;
            polygons.add(_ProjectedPolygon(
                points: [projIp1, projIp2, projIp3, projIp4],
                zDepth: zDepth,
                color: _TubeGameState._tubeColor.withOpacity(0.7),
            ));
        }
      }
    }

    // --- Front face of the tube ---
    for (int j = 0; j < _TubeGameState._ringSegments; j++) {
        final int nextJ = (j + 1) % _TubeGameState._ringSegments;
        final p1 = outerRings[0][j];
        final p2 = innerRings[0][j];
        final p3 = innerRings[0][nextJ];
        final p4 = outerRings[0][nextJ];

        final projP1 = project(p1);
        final projP2 = project(p2);
        final projP3 = project(p3);
        final projP4 = project(p4);

        if (projP1 != null && projP2 != null && projP3 != null && projP4 != null) {
            polygons.add(_ProjectedPolygon(
                points: [projP1, projP2, projP3, projP4],
                zDepth: p1.z,
                color: _TubeGameState._tubeColor.withOpacity(0.85),
            ));
        }
    }

    // --- Player Sphere Polygons (Simplified) ---
    // (A full sphere implementation is complex, so we'll draw a filled circle)
    final playerCenter3D = vm.Vector3(0, playerY, playerZ);
    final projPlayerCenter = project(playerCenter3D);
    if(projPlayerCenter != null){
         polygons.add(_ProjectedPolygon(
            points: [projPlayerCenter], // Special case for circle
            zDepth: playerCenter3D.z,
            color: _TubeGameState._playerColor,
        ));
    }


    // --- Painter's Algorithm (Sort and Draw) ---
    polygons.sort((a, b) => b.zDepth.compareTo(a.zDepth));

    for (final poly in polygons) {
        if(poly.points.length == 1){ // Draw sphere as circle
            canvas.drawCircle(poly.points.first, 40.0, playerPaint);
        } else {
            final path = Path()..addPolygon(poly.points, true);
            tubePaint.color = poly.color;
            canvas.drawPath(path, tubePaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant TubePainter oldDelegate) => true;
}

class _ProjectedPolygon {
  final List<Offset> points;
  final double zDepth;
  final Color color;

  _ProjectedPolygon({
    required this.points,
    required this.zDepth,
    required this.color,
  });
}
