import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:iptv_app/models/channel_model.dart';
import 'dart:async';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final VoidCallback? onError;

  const PlayerScreen({super.key, required this.channel, this.onError});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool hasError = false;
  bool isBuffering = true;
  bool isPlaying = false;
  Timer? _connectionTimeout;
  
  late final StreamSubscription errorSubscription;
  late final StreamSubscription bufferingSubscription;
  late final StreamSubscription playingSubscription;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    // 1. Connection Timeout: If no real playback happens in 20s, it's dead.
    _connectionTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !isPlaying) {
        setState(() {
          hasError = true;
          isBuffering = false;
        });
        widget.onError?.call();
      }
    });

    // 2. Listen for Errors
    errorSubscription = player.stream.error.listen((event) {
      debugPrint('Stream error detected: $event');
      if (mounted) {
        final errorMsg = event.toString().toLowerCase();
        // If it fails to open, it's ALWAYS fatal even if player reported "playing"
        bool isFatal = errorMsg.contains('failed to open') || 
                       errorMsg.contains('cannot open') ||
                       (!isPlaying && !isBuffering);

        if (isFatal) {
          setState(() {
            hasError = true;
            isBuffering = false;
            isPlaying = false;
          });
          widget.onError?.call();
          _connectionTimeout?.cancel();
        }
      }
    });

    // 3. Listen for Buffering State
    bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          isBuffering = buffering;
          if (buffering && !hasError) hasError = false;
        });
      }
    });

    // 4. Listen for Playing State
    playingSubscription = player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          isPlaying = playing;
          if (playing) {
            // We don't hide the loading screen IMMEDIATELY on "playing" signal
            // because HLS streams often signal "playing" before the first segment arrives.
            _connectionTimeout?.cancel();
          }
        });
      }
    });

    // 5. Open Stream
    player.open(
      Media(
        widget.channel.streamUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          'Referer': 'https://www.google.com/',
        },
      ),
    );
  }

  @override
  void dispose() {
    _connectionTimeout?.cancel();
    errorSubscription.cancel();
    bufferingSubscription.cancel();
    playingSubscription.cancel();
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
              // 1. VIDEO LAYER
              if (!hasError)
                Positioned.fill(
                  child: isLandscape
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 50),
                          child: Video(controller: controller, fit: BoxFit.cover),
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

              // 2. LOADING LAYER (Persistent until we have a steady play state)
              // We keep it visible if it's buffering OR if we don't have a stable playing signal yet
              if (!hasError && (isBuffering || !isPlaying))
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text('Connecting to stream...', 
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                        SizedBox(height: 8),
                        Text('Please wait, this might take a moment', 
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              // 3. ERROR LAYER
              if (hasError)
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
                        const SizedBox(height: 20),
                        const Text(
                          'Stream Offline',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text('Unable to load ${widget.channel.name}', 
                          style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'The server might be down, or the content is geo-blocked in your region.',
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
                ),
            ],
          ),
        );
      },
    );
  }
}
