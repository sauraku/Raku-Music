import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppConfig {
  static Future<Directory> getAppConfigDirectory() async {
    // For Linux, we want to store in ~/.local/share/raku_music
    // path_provider's getApplicationSupportDirectory usually maps to:
    // Linux: /home/user/.local/share/com.sauraku.raku_music (or similar based on app ID)
    // Android: /data/user/0/com.sauraku.raku_music/files
    
    // However, the user specifically asked for ~/.local for application information.
    // Standard XDG Base Directory specification says user data should go to $XDG_DATA_HOME,
    // which defaults to $HOME/.local/share.
    
    if (Platform.isLinux) {
      final String? home = Platform.environment['HOME'];
      if (home != null) {
        // Segregate dev and prod environments
        // kDebugMode is true when running with 'flutter run'
        // kReleaseMode is true when running the installed app (built with --release)
        const String appName = kDebugMode ? 'raku_music_dev' : 'raku_music';
        
        final Directory localDir = Directory(p.join(home, '.local', 'share', appName));
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        return localDir;
      }
    }
    
    // Fallback for other platforms or if HOME is not set on Linux
    return await getApplicationSupportDirectory();
  }
}
