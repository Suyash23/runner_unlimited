import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class Vertex {
  vm.Vector3 pos;
  vm.Vector2 uv;
  vm.Vector3 normal;
  double lightIntensity = 0.0;
  Vertex({required this.pos, required this.uv, required this.normal});
}

class Quad {
  List<Vertex> vertices;
  Quad(this.vertices);
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TubeGame(),
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'monospace'),
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
  ByteData? _textureBytes;
  int _textureWidth = 0;
  List<Quad> _tubeQuads = [];

  // Game State
  double _distance = 0;
  double _tubeRotationZ = 0;
  double _rollVel = 0;
  double _pitch = -0.15;
  double _pitchVel = 0;
  double _yaw = 0;
  double _yawVel = 0;
  bool _isGameOver = false;
  bool _hasGround = true;
  double _fallVel = 0;
  double _playerY = -_radius + 30;

  static const int _numSegments = 64;
  static const double _radius = 300;
  static const double _tubeLength = 12000;

  @override
  void initState() {
    super.initState();
    _generateTexture();
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
      _pitch = -0.15;
      _pitchVel = 0;
      _yaw = 0;
      _yawVel = 0;
      _isGameOver = false;
      _fallVel = 0;
      _playerY = -_radius + 30;
      _generateTube();
    });
  }

  bool _checkGround(double rotation) {
    final cycle = _distance % 3000;
    if (cycle > 2000) {
      final normRot = ((rotation % (2 * pi)) + (2 * pi)) % (2 * pi);
      if (normRot > 1.5 && normRot < 4.5) return false;
    }
    return true;
  }

  void _onTick(Duration elapsed) {
    if (_isGameOver) return;
    setState(() {
      _distance += 25;
      _tubeRotationZ += _rollVel;
      _pitch = (_pitch + _pitchVel).clamp(-0.4, 0.4);
      _yaw += _yawVel;

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

  void _generateTube() {
    _tubeQuads = [];
    final int numRings = (_tubeLength / 50).ceil();
    for (int i = 0; i < numRings; i++) {
      for (int j = 0; j < _numSegments; j++) {
        final double u1 = j / _numSegments;
        final double u2 = (j + 1) / _numSegments;
        final double v1 = i / numRings;
        final double v2 = (i + 1) / numRings;

        final double theta1 = u1 * 2 * pi;
        final double theta2 = u2 * 2 * pi;

        final p1 = vm.Vector3(cos(theta1) * _radius, sin(theta1) * _radius, i * -50.0);
        final p2 = vm.Vector3(cos(theta2) * _radius, sin(theta2) * _radius, i * -50.0);
        final p3 = vm.Vector3(cos(theta2) * _radius, sin(theta2) * _radius, (i + 1) * -50.0);
        final p4 = vm.Vector3(cos(theta1) * _radius, sin(theta1) * _radius, (i + 1) * -50.0);

        final n = (p1.normalized() * -1);

        _tubeQuads.add(Quad([
          Vertex(pos: p1, uv: vm.Vector2(u1 * 8, v1 * 20), normal: n),
          Vertex(pos: p2, uv: vm.Vector2(u2 * 8, v1 * 20), normal: n),
          Vertex(pos: p3, uv: vm.Vector2(u2 * 8, v2 * 20), normal: n),
          Vertex(pos: p4, uv: vm.Vector2(u1 * 8, v2 * 20), normal: n),
        ]));
      }
    }
  }

  Future<void> _generateTexture() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(1024, 1024);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF222222));
    final random = Random();
    for (int i = 0; i < 60; i++) {
      canvas.drawRect(Rect.fromLTWH(random.nextDouble() * size.width, 0, random.nextDouble() * 10, size.height), Paint()..color = Colors.white.withOpacity(random.nextDouble() * 0.15));
    }
    for (int i = 0; i < 200; i++) {
      canvas.drawRect(Rect.fromLTWH(0, random.nextDouble() * size.height, size.width, 2), Paint()..color = Colors.black.withOpacity(0.5));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    setState(() {
      _textureBytes = bytes;
      _textureWidth = image.width;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_textureBytes == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("GENERATING TEXTURE...", style: TextStyle(color: Colors.green))));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: TubePainter(
              textureBytes: _textureBytes!,
              textureWidth: _textureWidth,
              quads: _tubeQuads,
              scrollV: _distance / 1000,
              pitch: _pitch,
              yaw: _yaw,
              tubeRotationZ: _tubeRotationZ,
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
      bottom: 30, left: 20, right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            _buildControlButton('Q', () => _yawVel = 0.02, () => _yawVel = 0),
            const SizedBox(width: 10),
            _buildControlButton('E', () => _yawVel = -0.02, () => _yawVel = 0),
          ]),
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
    );
  }

  Widget _buildControlButton(String label, VoidCallback onPressed, VoidCallback onReleased) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: const TextStyle(color: Colors.green, fontSize: 18)),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 40, right: 20,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.green, fontSize: 16),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
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
  final ByteData textureBytes;
  final int textureWidth;
  final List<Quad> quads;
  final double scrollV;
  final double pitch;
  final double yaw;
  final double tubeRotationZ;

  TubePainter({
    required this.textureBytes,
    required this.textureWidth,
    required this.quads,
    required this.scrollV,
    required this.pitch,
    required this.yaw,
    required this.tubeRotationZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imageBuffer = Uint32List(size.width.toInt() * size.height.toInt());
    final zBuffer = List<double>.filled(imageBuffer.length, double.infinity);

    final projectionMatrix = vm.makePerspectiveMatrix(60 * (pi / 180), size.width / size.height, 1, 20000);

    final viewMatrix = vm.Matrix4.identity()
      ..translate(0.0, 0.0, -1400.0)
      ..rotateX(-pitch)
      ..rotateY(-yaw);

    final tubeModelMatrix = vm.Matrix4.identity()..rotateZ(tubeRotationZ);

    final lightDir = vm.Vector3(0.5, 0.5, 1.0).normalized();

    for (final quad in quads) {
      final transformedVertices = <(vm.Vector4, Vertex)>[];
      for (final vertex in quad.vertices) {
        final worldPos = tubeModelMatrix.transform(vm.Vector4(vertex.pos.x, vertex.pos.y, vertex.pos.z, 1.0));
        final transformedPos = viewMatrix.transform(worldPos);

        final transformedNormal = tubeModelMatrix.transform(vm.Vector4(vertex.normal.x, vertex.normal.y, vertex.normal.z, 0.0));
        vertex.lightIntensity = (transformedNormal.xyz.dot(lightDir) * 0.5 + 0.5).clamp(0.4, 1.0);

        transformedVertices.add((transformedPos, vertex));
      }

      final p1 = transformedVertices[0].$1;
      final p2 = transformedVertices[1].$1;
      final p3 = transformedVertices[2].$1;
      final normal = (p2.xyz - p1.xyz).cross(p3.xyz - p1.xyz);
      if (normal.dot(p1.xyz) >= 0) continue;

      final projected = <(vm.Vector4, Vertex)>[];
      for (final tv in transformedVertices) {
        final screenPos = projectionMatrix.transform(tv.$1);
        screenPos.x = (screenPos.x / screenPos.w + 1) * 0.5 * size.width;
        screenPos.y = (1 - (screenPos.y / screenPos.w + 1) * 0.5) * size.height;
        projected.add((screenPos, tv.$2));
      }
      _rasterizeTriangle(imageBuffer, zBuffer, size, projected[0], projected[1], projected[2]);
      _rasterizeTriangle(imageBuffer, zBuffer, size, projected[0], projected[2], projected[3]);
    }

    ui.decodeImageFromPixels(
      imageBuffer.buffer.asUint8List(),
      size.width.toInt(),
      size.height.toInt(),
      ui.PixelFormat.rgba8888,
      (result) {
        canvas.drawImage(result, Offset.zero, Paint());
      },
    );
  }

  void _rasterizeTriangle(Uint32List imageBuffer, List<double> zBuffer, Size size,
      (vm.Vector4, Vertex) p1, (vm.Vector4, Vertex) p2, (vm.Vector4, Vertex) p3) {

    var (v1, vert1) = p1;
    var (v2, vert2) = p2;
    var (v3, vert3) = p3;

    final xmin = max(0, min(v1.x, min(v2.x, v3.x))).toInt();
    final xmax = min(size.width-1, max(v1.x, max(v2.x, v3.x))).toInt();
    final ymin = max(0, min(v1.y, min(v2.y, v3.y))).toInt();
    final ymax = min(size.height-1, max(v1.y, max(v2.y, v3.y))).toInt();

    final double area = (v2.x - v1.x) * (v3.y - v1.y) - (v2.y - v1.y) * (v3.x - v1.x);
    if (area == 0) return;

    final texData = textureBytes.buffer.asUint32List();
    final int w = size.width.toInt();

    for (int y = ymin; y <= ymax; y++) {
      for (int x = xmin; x <= xmax; x++) {
        final double w1 = ((v2.y - v3.y) * (x - v3.x) + (v3.x - v2.x) * (y - v3.y)) / area;
        final double w2 = ((v3.y - v1.y) * (x - v1.x) + (v1.x - v3.x) * (y - v1.y)) / area;
        final double w3 = 1.0 - w1 - w2;

        if (w1 >= 0 && w2 >= 0 && w3 >= 0) {
          final double zInv = w1 / v1.w + w2 / v2.w + w3 / v3.w;
          final double z = 1.0 / zInv;
          final int bufferIndex = y * w + x;

          if (z < zBuffer[bufferIndex]) {
            zBuffer[bufferIndex] = z;

            final double u = (w1 * (vert1.uv.x / v1.w) + w2 * (vert2.uv.x / v2.w) + w3 * (vert3.uv.x / v3.w)) * z;
            final double v = (w1 * (vert1.uv.y / v1.w) + w2 * (vert2.uv.y / v2.w) + w3 * (vert3.uv.y / v3.w)) * z + scrollV;

            final int texX = (u * (textureWidth-1)).toInt() & (textureWidth-1);
            final int texY = (v * (textureWidth-1)).toInt() & (textureWidth-1);
            final int texColor = texData[texY * textureWidth + texX];

            final double light = (w1 * vert1.lightIntensity + w2 * vert2.lightIntensity + w3 * vert3.lightIntensity);
            final double fog = (z / 15000).clamp(0.0, 1.0);

            final int r = (((texColor >> 0) & 0xFF) * light).toInt();
            final int g = (((texColor >> 8) & 0xFF) * light).toInt();
            final int b = (((texColor >> 16) & 0xFF) * light).toInt();

            final int finalR = (r * (1-fog)).toInt();
            final int finalG = (g * (1-fog)).toInt();
            final int finalB = (b * (1-fog)).toInt();

            imageBuffer[bufferIndex] = (0xFF << 24) | (finalB << 16) | (finalG << 8) | finalR;
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TubePainter oldDelegate) => true;
}
