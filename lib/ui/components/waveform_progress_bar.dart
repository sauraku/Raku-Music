import 'package:flutter/material.dart';

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
  List<double>? _cachedSamples;
  double? _cachedWidth;
  List<double>? _lastWaveformData;

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

  List<double> _calculateSamples(double width) {
    final double step = widget.barWidth + widget.barGap;
    final int visibleBars = (width / step).floor();
    
    if (visibleBars <= 0) return [];

    final List<double> samples = [];
    final int sampleCount = widget.waveformData.length;
    if (sampleCount == 0) return [];

    final double stepSize = sampleCount / visibleBars.toDouble();

    for (int i = 0; i < visibleBars; i++) {
      double maxSample = 0;
      final int start = (i * stepSize).floor();
      final int end = ((i + 1) * stepSize).floor();
      for (int j = start; j < end && j < sampleCount; j++) {
        if (widget.waveformData[j].abs() > maxSample) {
          maxSample = widget.waveformData[j].abs();
        }
      }
      samples.add(maxSample);
    }
    return samples;
  }

  @override
  Widget build(BuildContext context) {
    double progressPercent = 0.0;
    if (widget.total.inMilliseconds > 0) {
      progressPercent = widget.progress.inMilliseconds / widget.total.inMilliseconds;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        
        if (width != _cachedWidth || widget.waveformData != _lastWaveformData) {
          _cachedWidth = width;
          _lastWaveformData = widget.waveformData;
          _cachedSamples = _calculateSamples(width);
        }

        return RepaintBoundary(
          child: GestureDetector(
            onTapDown: _onTapDown,
            onHorizontalDragUpdate: _onDragUpdate,
            child: CustomPaint(
              size: Size(width, 100),
              painter: WaveformPainter(
                samples: _cachedSamples!,
                progress: progressPercent,
                barWidth: widget.barWidth,
                barGap: widget.barGap,
                playedColor: widget.color ?? Theme.of(context).colorScheme.primary,
                unplayedColor: (widget.color ?? Theme.of(context).colorScheme.onSurface).withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final double barWidth;
  final double barGap;

  WaveformPainter({
    required this.samples,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.barWidth,
    required this.barGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final paintUnplayed = Paint()..color = unplayedColor;
    final paintPlayed = Paint()..color = playedColor;

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;
    final double step = barWidth + barGap;

    void drawBars(Paint paint) {
      for (int i = 0; i < samples.length; i++) {
        final double x = i * step;
        final double barHeight = samples[i] * height;
        final double top = centerY - barHeight / 2;
        canvas.drawRect(Rect.fromLTWH(x, top, barWidth, barHeight), paint);
      }
    }

    // Draw the unplayed part first
    drawBars(paintUnplayed);

    // Draw the played part on top, clipped
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width * progress, height));
    drawBars(paintPlayed);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return progress != oldDelegate.progress ||
           samples != oldDelegate.samples ||
           playedColor != oldDelegate.playedColor ||
           unplayedColor != oldDelegate.unplayedColor;
  }
}
