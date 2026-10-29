package tv.dumbtv.home;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;

/**
 * The connection line under the date: the Wi-Fi name and its strength, or Ethernet.
 * The name needs ACCESS_FINE_LOCATION (tcl.sh grants it); without it Android hides the
 * name and the line just says WLAN.
 */
final class Net {
    /** No connection. */
    static final int NONE = -1;
    /** Cable, drawn as full bars. */
    static final int CABLE = 5;

    final String label;
    final int level;

    private Net(String label, int level) {
        this.label = label;
        this.level = level;
    }

    @SuppressWarnings("deprecation")
    static Net now(Context c) {
        ConnectivityManager cm = (ConnectivityManager) c.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo active = cm == null ? null : cm.getActiveNetworkInfo();
        if (active == null || !active.isConnected()) return new Net("Nicht verbunden", NONE);
        if (active.getType() == ConnectivityManager.TYPE_ETHERNET) return new Net("LAN-Kabel", CABLE);
        WifiManager wm = (WifiManager) c.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        WifiInfo info = wm == null ? null : wm.getConnectionInfo();
        if (info == null) return new Net("WLAN", 2);
        String ssid = info.getSSID();
        if (ssid == null || ssid.contains("unknown ssid")) ssid = "WLAN";
        if (ssid.length() > 1 && ssid.startsWith("\"") && ssid.endsWith("\"")) {
            ssid = ssid.substring(1, ssid.length() - 1);
        }
        return new Net(ssid, WifiManager.calculateSignalLevel(info.getRssi(), 5));
    }
}
