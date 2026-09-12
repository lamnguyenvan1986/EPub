import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  
  const AudioVisualizer({super.key, required this.isPlaying});

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _animations = List.generate(5, (_) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Interval(
            0.0,
            1.0,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) => Padding(
        key: Key('padding_$index'),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedBuilder(
          key: Key('builder_$index'),
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              width: 6,
              height: 30 * _animations[index].value,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        ),
      )),
    );
  }
}
