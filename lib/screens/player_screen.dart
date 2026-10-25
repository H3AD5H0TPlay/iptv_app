import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:iptv_app/models/channel_model.dart';

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
  bool hasStartedPlaying = false;
  BoxFit videoFit = BoxFit.contain;
  Timer? _connectionTimeout;

  late final StreamSubscription<String> errorSubscription;
  late final StreamSubscription<bool> bufferingSubscription;
  late final StreamSubscription<bool> playingSubscription;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    // 1. Connection Timeout: If no real playback happens in 20s, it's dead.
    _connectionTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !hasStartedPlaying) {
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
        final errorMsg = event.toLowerCase();
        final bool isFatal = errorMsg.contains('failed to open') ||
            errorMsg.contains('cannot open') ||
            (!hasStartedPlaying && !isBuffering);

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
            hasStartedPlaying = true;
            _connectionTimeout?.cancel();
          }
        });
      }
    });

    // 5. Open Stream with custom or fallback HTTP headers
    final Map<String, String> headers = {
      'User-Agent': widget.channel.userAgent ??
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    };
    if (widget.channel.referrer != null && widget.channel.referrer!.isNotEmpty) {
      headers['Referer'] = widget.channel.referrer!;
    }

    player.open(
      Media(
        widget.channel.streamUrl,
        httpHeaders: headers,
      ),
    );
  }

  @override
  void dispose() {
    _connectionTimeout?.cancel();
    errorSubscription.cancel();
    bufferingSubscription.cancel();
    playingSubscription.cancel();
    if (!_isDesktop) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            if (!_isDesktop) {
              if (isLandscape) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              } else {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              }
            }

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: (!_isDesktop && isLandscape && !hasError)
                  ? null
                  : AppBar(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      elevation: 0,
                      leading: IconButton(
                        tooltip: 'Back (Esc)',
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      title: Text(
                        '${widget.channel.name} (${widget.channel.country})',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      actions: [
                        IconButton(
                          tooltip: videoFit == BoxFit.contain ? 'Fill Screen' : 'Fit Aspect Ratio',
                          icon: Icon(
                            videoFit == BoxFit.contain ? Icons.aspect_ratio : Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              videoFit = videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
                            });
                          },
                        ),
                      ],
                    ),
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // 1. VIDEO LAYER
                  if (!hasError)
                    Positioned.fill(
                      child: (_isDesktop || isLandscape)
                          ? Video(controller: controller, fit: videoFit)
                          : Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Video(controller: controller, fit: videoFit),
                              ),
                            ),
                    ),

                  // 2. LOADING LAYER (Non-blocking and only shown before initial play or while buffering)
                  if (!hasError && (isBuffering || !hasStartedPlaying))
                    IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: hasStartedPlaying ? 0.35 : 0.85),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 20),
                              Text(
                                hasStartedPlaying
                                    ? 'Buffering...'
                                    : 'Connecting to ${widget.channel.name}...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!hasStartedPlaying) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Please wait, this might take a moment',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),
      ),
    );
  }
}
