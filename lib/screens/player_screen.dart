import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:iptv_app/models/channel_model.dart';
import 'dart:async';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool hasError = false;
  late final StreamSubscription errorSubscription;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    // Set up error listener
    errorSubscription = player.stream.error.listen((event) {
      debugPrint('Player error: $event');
      if (mounted) {
        setState(() {
          hasError = true;
        });
      }
    });

    player.open(Media(widget.channel.streamUrl));
  }

  @override
  void dispose() {
    // Cancel the error subscription
    errorSubscription.cancel();
    // Reset system UI when leaving the player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        // Manage System UI based on orientation
        if (isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          // Hide AppBar in landscape unless there's an error
          appBar: (isLandscape && !hasError)
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
          backgroundColor: Colors.black,
          body: hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 80),
                      const SizedBox(height: 20),
                      const Text(
                        'Stream Offline',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Unable to load ${widget.channel.name}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : isLandscape
                  ? Padding(
                      padding: const EdgeInsets.only(
                          bottom: 50), // Lift the controls significantly
                      child: Video(
                        controller: controller,
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        fit: BoxFit.cover, // Fill the entire screen
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom:
                                    40), // Lift the controls up from the bottom of the video area
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Video(
                                controller: controller,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}
