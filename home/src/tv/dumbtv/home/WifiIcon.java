package tv.dumbtv.home;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;

/** A Wi-Fi fan whose lit arcs follow the signal, or a small block for a cable. */
final class WifiIcon extends Drawable {
    private final Paint on = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint off = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final int size;
    private int level = Net.NONE;

    WifiIcon(int size, int color) {
        this.size = size;
        on.setColor(color);
        off.setColor(color);
        off.setAlpha(60);
        setBounds(0, 0, size, size);
    }

    void setSignal(int level) {
        if (this.level == level) return;
        this.level = level;
        invalidateSelf();
    }

    @Override
    public void draw(Canvas c) {
        float w = getBounds().width(), h = getBounds().height();
        float cx = getBounds().left + w / 2, by = getBounds().top + h * 0.92f;
        if (level == Net.CABLE) {
            c.drawRoundRect(new RectF(cx - w * 0.3f, by - h * 0.6f, cx + w * 0.3f, by - h * 0.1f), w * 0.08f, w * 0.08f, on);
            return;
        }
        // Four rings from the dot outwards; level 0..4 lights that many.
        float stroke = h * 0.12f;
        for (int i = 3; i >= 1; i--) {
            float r = h * (0.22f + i * 0.24f);
            Paint p = new Paint(i < level ? on : off);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(stroke);
            p.setStrokeCap(Paint.Cap.ROUND);
            c.drawArc(new RectF(cx - r, by - r, cx + r, by + r), 225, 90, false, p);
        }
        c.drawCircle(cx, by - stroke * 0.6f, stroke * 0.9f, level > 0 ? on : off);
    }

    @Override
    public int getIntrinsicWidth() {
        return size;
    }

    @Override
    public int getIntrinsicHeight() {
        return size;
    }

    @Override
    public void setAlpha(int alpha) {}

    @Override
    public void setColorFilter(ColorFilter cf) {}

    @Override
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }
}
