import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class WaveformProgressBar extends StatefulWidget {
  final List<double> waveformData;
  final Duration total;
  final Duration progress;
  final Function(Duration) onSeek;
  final double barWidth;
  final double barGap;
  final Color? color;

  const WaveformProgressBar({
    super.key,
    required this.waveformData,
    required this.total,
    required this.progress,
    required this.onSeek,
    this.barWidth = 3.0,
    this.barGap = 2.0,
    this.color,
  });

  @override
  State<WaveformProgressBar> createState() => _WaveformProgressBarState();
}

class _WaveformProgressBarState extends State<WaveformProgressBar> {
  void _onDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final position = details.localPosition.dx / box.size.width;
    final seekPosition = widget.total * position;
    widget.onSeek(seekPosition);
  }

  void _onTapDown(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final position = details.localPosition.dx / box.size.width;
    final seekPosition = widget.total * position;
    widget.onSeek(seekPosition);
  }

  @override
  Widget build(BuildContext context) {
    double progressPercent = 0.0;
    if (widget.total.inMilliseconds > 0) {
      progressPercent = widget.progress.inMilliseconds / widget.total.inMilliseconds;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onHorizontalDragUpdate: _onDragUpdate,
      child: CustomPaint(
        size: const Size(double.infinity, 100),
        painter: WaveformPainter(
          waveformData: widget.waveformData,
          progress: progressPercent,
          barWidth: widget.barWidth,
          barGap: widget.barGap,
          playedColor: widget.color ?? Theme.of(context).colorScheme.primary,
          unplayedColor: (widget.color ?? Theme.of(context).colorScheme.onSurface).withOpacity(0.3),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double barWidth;
  final double barGap;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.barWidth,
    required this.barGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paintUnplayed = Paint()..color = unplayedColor;
    final paintPlayed = Paint()..color = playedColor;

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;

    // Draw the unplayed part first
    _drawWaveform(canvas, size, paintUnplayed, 1.0);

    // Draw the played part on top, clipped
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width * progress, height));
    _drawWaveform(canvas, size, paintPlayed, 1.0);
    canvas.restore();
  }

  void _drawWaveform(Canvas canvas, Size size, Paint paint, double scale) {
    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;
    final double step = barWidth + barGap;
    final int visibleBars = (width / step).floor();

    // Downsample the waveform data to fit the number of visible bars
    final List<double> samples = [];
    final int sampleCount = waveformData.length;
    if (sampleCount == 0) return;

    final double stepSize = sampleCount / visibleBars.toDouble();

    for (int i = 0; i < visibleBars; i++) {
      double maxSample = 0;
      final int start = (i * stepSize).floor();
      final int end = ((i + 1) * stepSize).floor();
      for (int j = start; j < end && j < sampleCount; j++) {
        if (waveformData[j].abs() > maxSample) {
          maxSample = waveformData[j].abs();
        }
      }
      samples.add(maxSample);
    }

    for (int i = 0; i < samples.length; i++) {
      final double x = i * step;
      final double barHeight = samples[i] * height * scale;
      final double top = centerY - barHeight / 2;
      canvas.drawRect(Rect.fromLTWH(x, top, barWidth, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return progress != oldDelegate.progress ||
           waveformData != oldDelegate.waveformData ||
           playedColor != oldDelegate.playedColor ||
           unplayedColor != oldDelegate.unplayedColor;
  }
}
