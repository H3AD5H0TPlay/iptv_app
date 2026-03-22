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
  bool isBuffering = true;
  late final StreamSubscription errorSubscription;
  late final StreamSubscription bufferingSubscription;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    // 1. Listen for Errors
    errorSubscription = player.stream.error.listen((event) {
      if (mounted) {
        setState(() {
          hasError = true;
          isBuffering = false;
        });
      }
    });

    // 2. Listen for Buffering State to show/hide loading spinner
    bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          isBuffering = buffering;
        });
      }
    });

    // 3. Open Stream with custom headers to bypass security/spoof browser
    player.open(
      Media(
        widget.channel.streamUrl,
        http_headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          'Referer': 'https://www.google.com/',
        },
      ),
    );
  }

  @override
  void dispose() {
    errorSubscription.cancel();
    bufferingSubscription.cancel();
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

        if (isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
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
          body: Stack(
            children: [
              // The Video Layer
              if (!hasError)
                Positioned.fill(
                  child: isLandscape
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 50),
                          child: Video(
                            controller: controller,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Video(controller: controller),
                            ),
                          ),
                        ),
                ),

              // The Loading/Buffering Spinner
              if (isBuffering && !hasError)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text('Connecting to stream...',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),

              // The Error Screen
              if (hasError)
                Center(
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
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'This may be due to geo-blocking or a temporary server outage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
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
                ),
            ],
          ),
        );
      },
    );
  }
}
