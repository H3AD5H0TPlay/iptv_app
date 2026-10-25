import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:iptv_app/models/channel_model.dart';

class PlayerScreen extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;
  final ValueChanged<String>? onChannelError;

  PlayerScreen({
    super.key,
    required Channel channel,
    List<Channel>? channels,
    int? initialIndex,
    VoidCallback? onError,
    this.onChannelError,
  })  : channels = channels ?? [channel],
        initialIndex = initialIndex ?? 0;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;
  late int currentIndex;

  bool hasError = false;
  bool isBuffering = true;
  bool isPlaying = false;
  bool hasStartedPlaying = false;
  bool showChannelDrawer = false;
  bool showOverlay = true;
  BoxFit videoFit = BoxFit.contain;

  Timer? _connectionTimeout;
  Timer? _overlayHideTimer;

  late final StreamSubscription<String> errorSubscription;
  late final StreamSubscription<bool> bufferingSubscription;
  late final StreamSubscription<bool> playingSubscription;

  Channel get currentChannel => widget.channels[currentIndex];

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex.clamp(0, widget.channels.length - 1);
    player = Player();
    controller = VideoController(player);

    // Listen for Errors
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
          widget.onChannelError?.call(currentChannel.streamUrl);
          _connectionTimeout?.cancel();
        }
      }
    });

    // Listen for Buffering State
    bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          isBuffering = buffering;
          if (buffering && !hasError) hasError = false;
        });
      }
    });

    // Listen for Playing State
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

    _openCurrentChannel();
    _resetOverlayTimer();
  }

  void _resetOverlayTimer() {
    _overlayHideTimer?.cancel();
    if (!showOverlay) {
      setState(() {
        showOverlay = true;
      });
    }
    _overlayHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && isPlaying && !showChannelDrawer && !hasError) {
        setState(() {
          showOverlay = false;
        });
      }
    });
  }

  void _openCurrentChannel() {
    _connectionTimeout?.cancel();
    setState(() {
      hasError = false;
      isBuffering = true;
      isPlaying = false;
      hasStartedPlaying = false;
    });

    _connectionTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !hasStartedPlaying) {
        setState(() {
          hasError = true;
          isBuffering = false;
        });
        widget.onChannelError?.call(currentChannel.streamUrl);
      }
    });

    final Map<String, String> headers = {
      'User-Agent': currentChannel.userAgent ??
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    };
    if (currentChannel.referrer != null && currentChannel.referrer!.isNotEmpty) {
      headers['Referer'] = currentChannel.referrer!;
    }

    player.open(
      Media(
        currentChannel.streamUrl,
        httpHeaders: headers,
      ),
    );
  }

  void _switchChannel(int newIndex) {
    if (widget.channels.isEmpty) return;
    final wrapped = (newIndex % widget.channels.length + widget.channels.length) %
        widget.channels.length;
    if (wrapped == currentIndex && !hasError) return;
    setState(() {
      currentIndex = wrapped;
    });
    _resetOverlayTimer();
    _openCurrentChannel();
  }

  @override
  void dispose() {
    _connectionTimeout?.cancel();
    _overlayHideTimer?.cancel();
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
    final ch = currentChannel;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (showChannelDrawer) {
            setState(() => showChannelDrawer = false);
          } else {
            Navigator.of(context).maybePop();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _switchChannel(currentIndex - 1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _switchChannel(currentIndex + 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _switchChannel(currentIndex - 1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _switchChannel(currentIndex + 1),
        const SingleActivator(LogicalKeyboardKey.keyG): () {
          setState(() => showChannelDrawer = !showChannelDrawer);
        },
      },
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          onHover: (_) => _resetOverlayTimer(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _resetOverlayTimer,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // 1. VIDEO LAYER
                  if (!hasError)
                    Positioned.fill(
                      child: Video(
                        controller: controller,
                        fit: videoFit,
                      ),
                    ),

                  // 2. LOADING / BUFFERING OVERLAY
                  if (!hasError && (isBuffering || !hasStartedPlaying))
                    IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: hasStartedPlaying ? 0.35 : 0.85),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE50914),
                                  strokeWidth: 4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                hasStartedPlaying
                                    ? 'Buffering stream...'
                                    : 'Tuning in to ${ch.name}...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${ch.countryFlag} ${ch.country}  •  ${ch.category}${ch.quality != null ? "  •  ${ch.quality}" : ""}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 3. ERROR LAYER (10-Foot Smart TV Style)
                  if (hasError)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [Color(0xFF1F1114), Color(0xFF0A0B0E)],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 560),
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15171E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sensors_off_rounded,
                                color: Color(0xFFE50914),
                                size: 76,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Signal Unavailable',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${ch.countryFlag} ${ch.name}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'This broadcast stream is currently offline or geo-restricted in your region.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60, fontSize: 16),
                              ),
                              const SizedBox(height: 30),
                              Wrap(
                                spacing: 14,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.arrow_back, size: 22),
                                    label: const Text('Back to Guide', style: TextStyle(fontSize: 17)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white30),
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _openCurrentChannel,
                                    icon: const Icon(Icons.refresh, size: 22),
                                    label: const Text('Retry', style: TextStyle(fontSize: 17)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white12,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                    ),
                                  ),
                                  if (widget.channels.length > 1)
                                    FilledButton.icon(
                                      onPressed: () => _switchChannel(currentIndex + 1),
                                      icon: const Icon(Icons.skip_next_rounded, size: 24),
                                      label: const Text('Next Channel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFE50914),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 4. TOP SMART-TV OSD BAR
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    top: (showOverlay || hasError || !hasStartedPlaying || showChannelDrawer) ? 0 : -110,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Back Button
                          FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded, size: 22),
                            label: const Text(
                              'Guide',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Live Red Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.white, size: 9),
                                SizedBox(width: 6),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Channel Name + Metadata
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ch.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${ch.countryFlag} ${ch.country}  •  ${ch.category}${ch.quality != null ? "  •  ${ch.quality}" : ""}  •  CH ${currentIndex + 1}/${widget.channels.length}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Prev / Next Channel Surf Buttons
                          if (widget.channels.length > 1) ...[
                            IconButton.filledTonal(
                              tooltip: 'Previous Channel (Up Arrow)',
                              onPressed: () => _switchChannel(currentIndex - 1),
                              icon: const Icon(Icons.skip_previous_rounded, size: 26),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.14),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Next Channel (Down Arrow)',
                              onPressed: () => _switchChannel(currentIndex + 1),
                              icon: const Icon(Icons.skip_next_rounded, size: 26),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.14),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],

                          // Aspect Ratio Button
                          FilledButton.tonalIcon(
                            onPressed: () {
                              setState(() {
                                videoFit = videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
                              });
                            },
                            icon: Icon(
                              videoFit == BoxFit.contain ? Icons.aspect_ratio_rounded : Icons.crop_free_rounded,
                              size: 20,
                            ),
                            label: Text(
                              videoFit == BoxFit.contain ? '16:9 Fit' : 'Zoom Fill',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Quick Channel Drawer Toggle
                          if (widget.channels.length > 1)
                            FilledButton.tonalIcon(
                              onPressed: () {
                                setState(() {
                                  showChannelDrawer = !showChannelDrawer;
                                });
                              },
                              icon: const Icon(Icons.live_tv_rounded, size: 20),
                              label: const Text(
                                'Channels',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: showChannelDrawer
                                    ? const Color(0xFFE50914)
                                    : Colors.white.withValues(alpha: 0.14),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 5. QUICK CHANNEL DRAWER (Right side overlay)
                  if (showChannelDrawer)
                    Positioned(
                      top: 76,
                      bottom: 20,
                      right: 20,
                      width: 360,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12141C).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.playlist_play_rounded, color: Color(0xFFE50914), size: 26),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Quick Surf (${widget.channels.length})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white70),
                                    onPressed: () => setState(() => showChannelDrawer = false),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.white12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.channels.length,
                                itemBuilder: (context, idx) {
                                  final item = widget.channels[idx];
                                  final isCurrent = idx == currentIndex;
                                  return ListTile(
                                    selected: isCurrent,
                                    selectedTileColor: const Color(0xFFE50914).withValues(alpha: 0.22),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: isCurrent ? const Color(0xFFE50914) : Colors.white38,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    title: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${item.countryFlag} ${item.category}${item.quality != null ? " • ${item.quality}" : ""}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                                    ),
                                    trailing: isCurrent
                                        ? const Icon(Icons.equalizer_rounded, color: Color(0xFFE50914))
                                        : null,
                                    onTap: () => _switchChannel(idx),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
