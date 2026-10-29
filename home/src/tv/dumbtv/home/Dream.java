package tv.dumbtv.home;

import android.service.dreams.DreamService;

/** Android's screensaver: the same lock screen, started by the system after the idle time. */
public final class Dream extends DreamService {
    private SaverView view;

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);
        view = new SaverView(this);
        setContentView(view);
    }

    @Override
    public void onDreamingStarted() {
        super.onDreamingStarted();
        view.start();
    }

    @Override
    public void onDreamingStopped() {
        view.stop();
        super.onDreamingStopped();
    }
}
