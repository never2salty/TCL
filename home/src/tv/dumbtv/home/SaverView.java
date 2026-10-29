package tv.dumbtv.home;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.TransitionDrawable;
import android.os.Handler;
import android.os.Looper;
import android.text.format.DateFormat;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.File;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * The lock screen: the wallpapers, crossfading every minute, with a large clock, the date and
 * the network line in the corner. Shown by {@link Saver} (Back on the home screen) and by
 * {@link Dream} (Android's screensaver after the idle time).
 */
final class SaverView extends FrameLayout {
    private static final long STEP_MS = 60_000;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private final ImageView wall;
    private final TextView clock, date, net;
    private final WifiIcon icon;
    private Drawable shown;
    private int index = -1;
    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            update();
            ui.postDelayed(this, 1000 - System.currentTimeMillis() % 1000);
        }
    };
    private final Runnable next = new Runnable() {
        @Override
        public void run() {
            nextWallpaper();
            ui.postDelayed(this, STEP_MS);
        }
    };

    SaverView(Context c) {
        super(c);
        setBackgroundColor(Color.BLACK);
        wall = new ImageView(c);
        wall.setScaleType(ImageView.ScaleType.CENTER_CROP);
        addView(wall, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

        // A soft dark fade at the bottom keeps the white text readable on bright photos.
        GradientDrawable fade = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP,
                new int[] {0xAA000000, 0x00000000});
        android.view.View shade = new android.view.View(c);
        shade.setBackground(fade);
        LayoutParams sl = new LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(c, 320), Gravity.BOTTOM);
        addView(shade, sl);

        LinearLayout box = new LinearLayout(c);
        box.setOrientation(LinearLayout.VERTICAL);
        clock = Ui.text(c, 96, Ui.TEXT, Ui.LIGHT);
        date = Ui.text(c, 22, 0xDDFFFFFF, Ui.MEDIUM);
        date.setPadding(Ui.dp(c, 4), Ui.dp(c, 6), 0, 0);
        net = Ui.text(c, 16, 0xBBFFFFFF, Ui.MEDIUM);
        net.setPadding(Ui.dp(c, 4), Ui.dp(c, 10), 0, 0);
        net.setGravity(Gravity.CENTER_VERTICAL);
        icon = new WifiIcon(Ui.dp(c, 18), 0xDDFFFFFF);
        net.setCompoundDrawables(icon, null, null, null);
        net.setCompoundDrawablePadding(Ui.dp(c, 8));
        box.addView(clock);
        box.addView(date);
        box.addView(net);
        LayoutParams bl = new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.START);
        bl.leftMargin = Ui.dp(c, 64);
        bl.bottomMargin = Ui.dp(c, 56);
        addView(box, bl);
    }

    void start() {
        nextWallpaper();
        ui.post(tick);
        ui.postDelayed(next, STEP_MS);
    }

    void stop() {
        ui.removeCallbacks(tick);
        ui.removeCallbacks(next);
    }

    private void update() {
        Context c = getContext();
        Date now = new Date();
        clock.setText(DateFormat.getTimeFormat(c).format(now));
        Locale locale = Locale.getDefault();
        date.setText(DateFormat.format(DateFormat.getBestDateTimePattern(locale, "EEEEdMMMM"), now));
        if (now.getTime() / 1000 % 10 == 0 || net.getText().length() == 0) {
            Net n = Net.now(c);
            net.setText(n.label);
            icon.setSignal(n.level);
        }
    }

    private void nextWallpaper() {
        Context c = getContext();
        List<File> pool = Config.get(c).wallpapers();
        Bitmap b = null;
        if (!pool.isEmpty()) {
            index = (index + 1) % pool.size();
            b = decode(pool.get(index));
        } else {
            File one = Config.get(c).wallpaper();
            if (one != null) b = decode(one);
        }
        Drawable d = b != null ? new BitmapDrawable(getResources(), b)
                : getResources().getDrawable(R.drawable.wallpaper, null);
        if (shown == null) {
            wall.setImageDrawable(d);
        } else {
            TransitionDrawable t = new TransitionDrawable(new Drawable[] {shown, d});
            t.setCrossFadeEnabled(true);
            wall.setImageDrawable(t);
            t.startTransition(1500);
        }
        shown = d;
    }

    private Bitmap decode(File f) {
        int w = getResources().getDisplayMetrics().widthPixels;
        int h = getResources().getDisplayMetrics().heightPixels;
        BitmapFactory.Options o = new BitmapFactory.Options();
        o.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(f.getPath(), o);
        o.inSampleSize = 1;
        while (o.outWidth / (o.inSampleSize * 2) >= w && o.outHeight / (o.inSampleSize * 2) >= h) {
            o.inSampleSize *= 2;
        }
        o.inJustDecodeBounds = false;
        return BitmapFactory.decodeFile(f.getPath(), o);
    }
}
