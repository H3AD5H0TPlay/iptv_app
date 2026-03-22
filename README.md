# 📺 StreamEast

StreamEast is a high-performance, cinematic IPTV application built with Flutter. It offers a seamless experience for streaming live television from multiple regions, featuring a modern "Netflix-style" interface and a robust video engine.

## 🚀 Key Features

*   **Multi-Region Support**: Automatically fetches and parses live channel playlists from Japan and Korea using the official `iptv-org` repositories.
*   **Cinematic UI**: A dark-themed, responsive interface designed for a premium viewing experience, featuring a hero banner and categorized horizontal scrolling.
*   **High-Performance Playback**: Powered by the `media_kit` C++ engine, supporting hardware decoding for ultra-smooth `.m3u8` (HLS) streaming.
*   **Intelligent Search**: Real-time filtering allows you to find your favorite channels or categories instantly as you type.
*   **Favorites System**: Save your go-to channels with a single tap. Favorites are persisted locally and displayed in a dedicated "Your Favorites" row at the top of the home screen.
*   **Adaptive Player**: 
    *   **True Fullscreen**: Automatically hides system UI and scales video to fill the screen in landscape mode.
    *   **Resilient Loading**: Built-in error handling detects dead streams and provides a clean "Stream Offline" interface.
    *   **Intuitive Controls**: Native-feeling playback controls including seek bar, time display, and volume management.
*   **Performance Optimized**: Designed to be lightweight and responsive, with efficient memory management and stream cleanup.

## 🛠️ Built With

*   **Flutter**: The world's most advanced UI toolkit.
*   **Media Kit**: For high-performance cross-platform video decoding.
*   **HTTP**: For real-time M3U playlist fetching.
*   **Shared Preferences**: For persistent local storage of user favorites.

## 📱 Getting Started

### Prerequisites
*   Flutter SDK (v3.0+)
*   Android Studio / VS Code
*   A physical device or emulator (Android 5.0+ or Windows 10+)

### Installation
1.  Clone this repository.
2.  Run `flutter pub get` to download dependencies.
3.  Execute `flutter run` (ensure a device is connected).

---
*Created with ❤️ for the ultimate streaming experience.*
