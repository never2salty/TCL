package tv.dumbtv.home;

import android.accessibilityservice.AccessibilityService;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;

import java.io.File;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The remote's app and menu buttons. Google TV's home screen handled them, so with it disabled
 * they did nothing. {@link Guard} filters every key; a key with a {@code key.<code>} line in
 * home.conf is taken here and opens its target, every other key passes through untouched.
 *
 * Targets: settings, wifi, inputs, saver, home, favorite (focused app to the front), or app packages separated by commas (the
 * first one installed opens). Every key press is logged under {@link #TAG}, which is how
 * {@code tcl.sh tasten} learns the codes of this remote.
 */
final class Keys {
    static final String TAG = "TclHomeKey";

    /**
     * Every key of the remote passes through here before the TV sees it, so this must answer at
     * once: a slow answer made volume lag and jump two steps. The mapping is a cached copy,
     * re-read from home.conf on a background thread, never on the key's own path.
     */
    private static volatile Map<Integer, String> map = Collections.emptyMap();
    private static final ExecutorService io = Executors.newSingleThreadExecutor();
    private static volatile long readAt;
    private static final long REREAD_MS = 3000;

    private Keys() {}

    /** True when the key was taken. Both the press and the release are taken, so nothing leaks. */
    static boolean handle(AccessibilityService s, KeyEvent e) {
        int code = e.getKeyCode();
        // Keys the TV handles itself are never touched: no lookup, no log, no delay.
        if (passThrough(code)) return false;
        if (e.getAction() == KeyEvent.ACTION_DOWN && e.getRepeatCount() == 0) {
            Log.i(TAG, "key " + code + " " + KeyEvent.keyCodeToString(code));
            reload(s);
        }
        String target = map.get(code);
        if (target == null) return false;
        if (e.getAction() == KeyEvent.ACTION_UP) run(s, target);
        return true;
    }

    private static boolean passThrough(int code) {
        switch (code) {
            case KeyEvent.KEYCODE_VOLUME_UP:
            case KeyEvent.KEYCODE_VOLUME_DOWN:
            case KeyEvent.KEYCODE_VOLUME_MUTE:
            case KeyEvent.KEYCODE_MUTE:
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_HOME:
            case KeyEvent.KEYCODE_POWER:
            case KeyEvent.KEYCODE_CHANNEL_UP:
            case KeyEvent.KEYCODE_CHANNEL_DOWN:
                return true;
            default:
                return code >= KeyEvent.KEYCODE_0 && code <= KeyEvent.KEYCODE_9;
        }
    }

    /** Re-reads the key.* lines in the background, at most every few seconds. */
    static void reload(Context c) {
        long now = System.currentTimeMillis();
        if (now - readAt < REREAD_MS) return;
        readAt = now;
        final Context app = c.getApplicationContext();
        io.execute(() -> {
            // Read the files directly: Config belongs to the main thread.
            Map<String, String> lines = new HashMap<>();
            File own = app.getExternalFilesDir(null);
            if (own != null && new File(own, Config.FILE).isFile()) lines.putAll(Config.parse(new File(own, Config.FILE)));
            File[] media = app.getExternalMediaDirs();
            if (media != null && media.length > 0 && media[0] != null && new File(media[0], Config.FILE).isFile()) {
                lines.putAll(Config.parse(new File(media[0], Config.FILE)));
            }
            Map<Integer, String> next = new HashMap<>();
            for (Map.Entry<String, String> en : lines.entrySet()) {
                if (!en.getKey().startsWith("key.")) continue;
                String target = en.getValue().trim();
                if (target.isEmpty()) continue;
                try {
                    next.put(Integer.parseInt(en.getKey().substring(4)), target);
                } catch (NumberFormatException ignored) {
                    // not a key line
                }
            }
            map = next;
        });
    }

    static void run(Context c, String target) {
        switch (target) {
            case "settings":
                start(c, settings(c));
                return;
            case "wifi":
                start(c, new Intent(Settings.ACTION_WIFI_SETTINGS));
                return;
            case "inputs":
            case "saver":
            case "home":
                start(c, new Intent(c, Home.class).putExtra(Home.EXTRA_OPEN, target)
                        .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP));
                return;
            case "favorite":
            case "favorit":
                if (Home.current != null) Home.current.favoriteFocused();
                return;
            default:
                PackageManager pm = c.getPackageManager();
                for (String pkg : target.split(",")) {
                    pkg = pkg.trim();
                    Intent i = pm.getLeanbackLaunchIntentForPackage(pkg);
                    if (i == null) i = pm.getLaunchIntentForPackage(pkg);
                    if (i != null) {
                        start(c, i);
                        return;
                    }
                }
                Log.w(TAG, "nothing installed for " + target);
        }
    }

    static Intent settings(Context c) {
        Intent tv = new Intent(Intent.ACTION_MAIN).addCategory("android.intent.category.LEANBACK_SETTINGS");
        return tv.resolveActivity(c.getPackageManager()) != null ? tv : new Intent(Settings.ACTION_SETTINGS);
    }

    private static void start(Context c, Intent i) {
        try {
            c.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (ActivityNotFoundException | SecurityException e) {
            Log.w(TAG, "could not open " + i, e);
        }
    }
}
