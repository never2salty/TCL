package tv.dumbtv.home;

import android.accessibilityservice.AccessibilityService;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;

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

    private Keys() {}

    /** True when the key was taken. Both the press and the release are taken, so nothing leaks. */
    static boolean handle(AccessibilityService s, KeyEvent e) {
        int code = e.getKeyCode();
        Config cfg = Config.get(s);
        if (e.getAction() == KeyEvent.ACTION_DOWN && e.getRepeatCount() == 0) {
            Log.i(TAG, "key " + code + " " + KeyEvent.keyCodeToString(code));
            cfg.refresh();
        }
        String target = cfg.get("key." + code, "").trim();
        if (target.isEmpty()) return false;
        if (e.getAction() == KeyEvent.ACTION_UP) run(s, target);
        return true;
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
