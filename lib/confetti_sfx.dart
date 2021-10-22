import 'package:flutter/material.dart';
import 'sendbird_sfx.dart';
import 'package:confetti/confetti.dart';

// SendbirdSFX subclass specific for detecting
// and triggering animations for a confetti effect
class ConfettiSFX extends SendbirdSFX {
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 10));

  ConfettiSFX({
    required String metaKey,
    required List<String> caselessKeywords,
    Function(String)? debugCallback,
  }) : super(
          metaKey: metaKey,
          caselessKeywords: caselessKeywords,
          debugCallback: debugCallback,
        );

  @override
  ui() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality
            .explosive, // don't specify a direction, blast randomly
        shouldLoop: false, // start again as soon as the animation is finished
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple
        ], // manually specify the colors to be used
        // createParticlePath: drawStar, // define a custom shape/path.
      ),
    );
  }

  @override
  play() {
    _confettiController.play();
  }

  @override
  stop() {
    _confettiController.stop();
  }

  @override
  dispose() {
    _confettiController.dispose();
  }
}
