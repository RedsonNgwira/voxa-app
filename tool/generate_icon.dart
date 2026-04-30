// tool/generate_icon.dart
// Run with: dart run tool/generate_icon.dart
// Generates assets/icon/app_icon.png (1024x1024)

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

// Pure Dart PNG generation — no Flutter UI needed
void main() async {
  const size = 1024;
  final pixels = Uint32List(size * size);

  // Background: #0E0B08
  const bg = 0xFF080B0E; // ABGR for little-endian
  for (int i = 0; i < pixels.length; i++) pixels[i] = bg;

  // Draw rounded rect background (slightly lighter)
  const radius = 200;
  const bgCard = 0xFF12100D;
  _fillRoundedRect(pixels, size, 0, 0, size, size, radius, bgCard);

  // Ember orange: #E8622A → ABGR = 0xFF2A62E8
  const ember = 0xFF2A62E8;
  const emberDim = 0xFF183EA0;

  // Draw "V" shape using thick lines
  // V left stroke: from (200, 180) to (512, 780)
  _drawThickLine(pixels, size, 200, 180, 512, 780, 52, ember);
  // V right stroke: from (824, 180) to (512, 780)
  _drawThickLine(pixels, size, 824, 180, 512, 780, 52, ember);

  // Draw waveform bars beneath the V (centered, 7 bars)
  const barY = 820;
  const barW = 28;
  const barSpacing = 48;
  const totalBars = 9;
  const startX = (size - (totalBars * barSpacing)) ~/ 2 + 10;
  final heights = [20, 40, 70, 100, 130, 100, 70, 40, 20];
  for (int i = 0; i < totalBars; i++) {
    final x = startX + i * barSpacing;
    final h = heights[i];
    final color = i == 4 ? ember : emberDim;
    _fillRect(pixels, size, x, barY - h, barW, h, color);
  }

  // Encode as PNG
  final png = _encodePng(pixels, size, size);
  final file = File('assets/icon/app_icon.png');
  await file.writeAsBytes(png);
  print('Icon generated: ${file.path} (${size}x${size})');
}

void _fillRoundedRect(Uint32List pixels, int w, int x, int y, int rw, int rh, int r, int color) {
  for (int py = y; py < y + rh; py++) {
    for (int px = x; px < x + rw; px++) {
      if (_inRoundedRect(px - x, py - y, rw, rh, r)) {
        pixels[py * w + px] = color;
      }
    }
  }
}

bool _inRoundedRect(int x, int y, int w, int h, int r) {
  if (x < 0 || y < 0 || x >= w || y >= h) return false;
  if (x < r && y < r) return _dist(x, y, r, r) <= r;
  if (x >= w - r && y < r) return _dist(x, y, w - r - 1, r) <= r;
  if (x < r && y >= h - r) return _dist(x, y, r, h - r - 1) <= r;
  if (x >= w - r && y >= h - r) return _dist(x, y, w - r - 1, h - r - 1) <= r;
  return true;
}

double _dist(int x, int y, int cx, int cy) =>
    math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy).toDouble());

void _drawThickLine(Uint32List pixels, int w, int x0, int y0, int x1, int y1, int thickness, int color) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  final len = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / len;
  final ny = dx / len;
  final half = thickness ~/ 2;
  for (int t = -half; t <= half; t++) {
    final ox = (nx * t).round();
    final oy = (ny * t).round();
    _drawLine(pixels, w, x0 + ox, y0 + oy, x1 + ox, y1 + oy, color);
  }
}

void _drawLine(Uint32List pixels, int w, int x0, int y0, int x1, int y1, int color) {
  int dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
  int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  int err = dx - dy;
  while (true) {
    if (x0 >= 0 && x0 < w && y0 >= 0 && y0 < w) pixels[y0 * w + x0] = color;
    if (x0 == x1 && y0 == y1) break;
    int e2 = 2 * err;
    if (e2 > -dy) { err -= dy; x0 += sx; }
    if (e2 < dx) { err += dx; y0 += sy; }
  }
}

void _fillRect(Uint32List pixels, int w, int x, int y, int rw, int rh, int color) {
  for (int py = y; py < y + rh; py++) {
    for (int px = x; px < x + rw; px++) {
      if (px >= 0 && px < w && py >= 0 && py < w) pixels[py * w + px] = color;
    }
  }
}

// Minimal PNG encoder
Uint8List _encodePng(Uint32List pixels, int width, int height) {
  // Convert ABGR to RGBA rows
  final rows = <Uint8List>[];
  for (int y = 0; y < height; y++) {
    final row = Uint8List(width * 4);
    for (int x = 0; x < width; x++) {
      final p = pixels[y * width + x];
      row[x * 4 + 0] = (p >> 16) & 0xFF; // R
      row[x * 4 + 1] = (p >> 8) & 0xFF;  // G
      row[x * 4 + 2] = p & 0xFF;          // B
      row[x * 4 + 3] = (p >> 24) & 0xFF; // A
    }
    rows.add(row);
  }

  final data = BytesBuilder();
  // PNG signature
  data.add([137, 80, 78, 71, 13, 10, 26, 10]);
  // IHDR
  _writeChunk(data, 'IHDR', _ihdr(width, height));
  // IDAT
  final raw = BytesBuilder();
  for (final row in rows) {
    raw.addByte(0); // filter type none
    raw.add(row);
  }
  final compressed = zlib.encode(raw.toBytes());
  _writeChunk(data, 'IDAT', compressed);
  // IEND
  _writeChunk(data, 'IEND', []);
  return data.toBytes();
}

Uint8List _ihdr(int w, int h) {
  final b = ByteData(13);
  b.setUint32(0, w); b.setUint32(4, h);
  b.setUint8(8, 8); b.setUint8(9, 2); // 8-bit RGB... wait need RGBA
  b.setUint8(9, 6); // RGBA
  return b.buffer.asUint8List();
}

void _writeChunk(BytesBuilder out, String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);
  final crcData = [...typeBytes, ...data];
  final crc = ByteData(4)..setUint32(0, _crc32(crcData));
  out.add(crc.buffer.asUint8List());
}

final zlib = _Zlib();

class _Zlib {
  List<int> encode(List<int> data) {
    // Use dart:io ZLibEncoder
    return ZLibEncoder().convert(data);
  }
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
