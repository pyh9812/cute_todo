import 'dart:js_interop';
import 'package:web/web.dart' as web;

class NotificationHelper {
  static Future<bool> requestPermission() async {
    try {
      final res = await web.Notification.requestPermission().toDart;
      return res.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static bool get hasPermission {
    try {
      return web.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void showNotification(String title, String body) {
    try {
      if (web.Notification.permission == 'granted') {
        web.Notification(
          title,
          web.NotificationOptions(
            body: body,
            icon: 'favicon.png',
          ),
        );
      }
    } catch (_) {}
  }

  static void playAlarmSound() {
    try {
      final audioContext = web.AudioContext();
      final now = audioContext.currentTime;

      // Note 1: E5 (659.25 Hz)
      final osc1 = audioContext.createOscillator();
      final gain1 = audioContext.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(659.25, now);
      gain1.gain.setValueAtTime(0.3, now);
      gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
      osc1.connect(gain1);
      gain1.connect(audioContext.destination);
      osc1.start(now);
      osc1.stop(now + 0.3);

      // Note 2: G#5 (830.61 Hz)
      final osc2 = audioContext.createOscillator();
      final gain2 = audioContext.createGain();
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(830.61, now + 0.15);
      gain2.gain.setValueAtTime(0.3, now + 0.15);
      gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
      osc2.connect(gain2);
      gain2.connect(audioContext.destination);
      osc2.start(now + 0.15);
      osc2.stop(now + 0.5);

      // Note 3: B5 (987.77 Hz)
      final osc3 = audioContext.createOscillator();
      final gain3 = audioContext.createGain();
      osc3.type = 'sine';
      osc3.frequency.setValueAtTime(987.77, now + 0.3);
      gain3.gain.setValueAtTime(0.35, now + 0.3);
      gain3.gain.exponentialRampToValueAtTime(0.001, now + 0.8);
      osc3.connect(gain3);
      gain3.connect(audioContext.destination);
      osc3.start(now + 0.3);
      osc3.stop(now + 0.8);
    } catch (_) {}
  }
}
