# TV entwerben: Was gemacht wurde und wie du es auf andere TVs überträgst

Diese Datei fasst zusammen, was an deinem **TCL 65C735 (Google TV, Android 11)**
gemacht wurde, wie es technisch funktioniert, welche Fehler unterwegs auftraten und
wie du das auf andere Fernseher überträgst, etwa auf deinen Samsung.

---

## 1. Ziel

- keine Werbung, keine Promo-Reihen, keine vorinstallierten Hersteller-Apps
- ein schlichter Home-Screen: App-Raster über einem Hintergrundbild, Uhr, Datum, WLAN
- Eingänge, WLAN und Einstellungen mit einem Klick
- Casten vom Handy (Chromecast, AirPlay) bleibt
- alles umkehrbar, mit Backup

## 2. Was am TCL gemacht wurde

| Bereich | Was | Wie |
|---|---|---|
| Werbung und Tracking | TCL-Werbekanäle, Promo-Kacheln, Partner-App-Installer, Telemetrie, Promo-Bildschirmschoner abgeschaltet | `pm disable-user` über ADB ([listen/werbung.txt](listen/werbung.txt)) |
| Vorinstallierte Apps | Rakuten TV, Pluto TV, Google-Filme-Shop, ... | `pm disable-user` ([listen/apps.txt](listen/apps.txt)) |
| Ballast | Alexa, Anleitung, TCL-Browser, Drucken, ... | `pm disable-user` ([listen/extras.txt](listen/extras.txt)) |
| Geschützt | Eingänge, Fernbedienung, Einstellungen, Chromecast, AirPlay, Sprachsuche, Play Store | wird nie angefasst ([listen/niemals.txt](listen/niemals.txt)) |
| DNS-Filter | Werbe- und Tracking-Server im ganzen TV geblockt | Private DNS auf `dns.adguard-dns.com` |
| YouTube ohne Werbung | SmartTube installiert | APK von GitHub, SHA-256 geprüft |
| Home-Screen | **TCL Home** statt Google TV | eigene App (Fork von dumbtv home), Google-TV-Launcher deaktiviert |
| Hintergründe | eingebaute Berge, eigene Fotos oder ~700 Google-Chromecast-Backdrops | Bilder in `/sdcard/Android/media/tv.dumbtv.home/wallpapers/` |
| Sperrbildschirm | Zurück-Taste oder Bildschirmschoner: großes Bild, Uhr, Datum, WLAN | Activity `Saver` und `DreamService` |
| WLAN-Anzeige | Name und Signalstärke unter dem Datum | `WifiManager`, braucht Standort-Recht |
| Fernbedienung | Netflix, Prime Video → Apple TV, YouTube → SmartTube, TCL Channel → IPTV Smarters Pro, Zahnrad → Einstellungen, Favoriten → App nach vorne | Bedienungshilfe-Dienst filtert Tasten, Belegung in `home.conf` |
| Backup | Einstellungen, abgeschaltete Pakete, App-Liste, Home-Screen, Bilder | `tcl backup`, `tcl wiederherstellen`, `tcl neu` |

Alles wird nur **deaktiviert**, nichts gelöscht. `tcl rueckgaengig` oder ein Werksreset
stellt den Originalzustand wieder her.

## 3. Wie es technisch funktioniert

### ADB

Android-Fernseher haben eine Entwickler-Schnittstelle (ADB). Damit kann ein Computer im
selben WLAN Befehle auf dem TV ausführen, **ohne Root**:

1. TV: *Einstellungen › System › Info › Build* 7× OK drücken → Entwickleroptionen
2. *Entwickleroptionen › USB-Debugging* an
3. PC: `adb connect <TV-IP>:5555`, am TV „Zulassen“ bestätigen

Die wichtigsten Befehle, die das Skript benutzt:

| Befehl | Zweck |
|---|---|
| `pm list packages` / `-d` / `-3` | alle / abgeschaltete / selbst installierte Apps |
| `pm disable-user --user 0 <paket>` | App abschalten (umkehrbar mit `pm enable`) |
| `settings put global private_dns_mode hostname` + `private_dns_specifier` | DNS-Filter |
| `pm grant <paket> <recht>` | Recht vergeben, auch Entwickler-Rechte wie `WRITE_SECURE_SETTINGS` |
| `appops set <paket> WRITE_SETTINGS allow` | Systemeinstellungen schreiben erlauben |
| `settings put secure enabled_accessibility_services ...` | Bedienungshilfe-Dienst einschalten |
| `settings put secure screensaver_components ...` | Bildschirmschoner festlegen |
| `cmd package resolve-activity ... HOME` | prüfen, welche App HOME öffnet |

### Home-Screen tauschen (Google TV)

- `cmd package set-home-activity` allein reicht auf Google TV nicht. Der Google-Launcher
  hat höhere Priorität.
- Funktioniert: erst den neuen Launcher installieren, dann **beide** Pakete abschalten:
  `com.google.android.apps.tv.launcherx` und `com.google.android.tungsten.setupwraith`.
  Nur launcherx allein lässt setupwraith HOME übernehmen und kann abstürzen.
- Danach ca. 1 Minute warten, bevor der TV ausgeschaltet wird.
- Auf älteren Android-TV-Geräten heißt der Launcher `com.google.android.tvlauncher`.

### Tasten der Fernbedienung

Die App-Tasten (Netflix, YouTube, ...) und das Zahnrad steuert auf Google TV der
Google-Launcher. Ist der aus, tun sie nichts. Lösung: Ein **Bedienungshilfe-Dienst**
(AccessibilityService mit `flagRequestFilterKeyEvents`) sieht jede Taste, bevor der TV
sie verarbeitet. Steht für den Tastencode eine Zeile `key.<code>=<ziel>` in `home.conf`,
öffnet er das Ziel. Alle anderen Tasten lässt er sofort durch.

- Die Tastencodes unterscheiden sich je nach Fernbedienung. `tcl tasten` lernt sie: Der
  Dienst schreibt jede Taste ins Log (`logcat -s TclHomeKey`), das Skript liest den Code.
- TCL startet solche Dienste nur mit `appops set <paket> AUTO_START allow`.
- **Wichtig:** Dieser Weg muss extrem schnell antworten. Eine langsame Version hat die
  Lautstärke ausgebremst und in 2er-Schritten springen lassen. Lautstärke, Steuerkreuz,
  OK, Zurück, HOME und Power werden deshalb gar nicht angefasst.

### Einstellungen per Datei

TCL Home liest `home.conf`. adb darf auf Android 11 nicht in `Android/data/<app>`
schreiben, aber in `Android/media/<app>`. Das Skript legt dort eine `home.conf` ab, und
die App übernimmt sie beim nächsten Druck auf HOME (Tastenbelegung, Bildwechsel, ...).

### App bauen

TCL Home ist reines Java ohne Bibliotheken ([home/](home/)). GitHub Actions baut sie bei
jeder Änderung in `home/` ([.github/workflows/home.yml](.github/workflows/home.yml)) und
legt `home/tcl-home.apk` ins Repo. Signiert wird mit `home/tcl-home.keystore`. Damit
passen Updates immer über die installierte Version.

## 4. Stolpersteine und Lösungen

| Problem | Ursache | Lösung |
|---|---|---|
| dumbtv-Skripte laufen nicht | dumbtv ist nur für Fire TV gebaut | eigenes Skript für Google TV |
| „Syntaxfehler“ in CMD | `./tcl.sh` ist ein Bash-Skript | `tcl.cmd` startet es über Git Bash, in CMD heißt es `tcl ...` |
| `$'\r': command not found` | Windows hat beim Klonen Zeilenenden umgewandelt | `.gitattributes` erzwingt LF, Ordner einmal neu klonen |
| adb-Pfad `C:/Program Files/Git/sdcard/...` | Git Bash wandelt `/sdcard/...` in Windows-Pfade um | `MSYS_NO_PATHCONV=1` im Skript |
| Installation hängt | Play Protect fragt am TV nach | am TV „Trotzdem installieren“ |
| Neue App (Browser) erscheint nicht | Handy-Apps ohne TV-Banner waren ausgeblendet | selbst installierte Apps werden jetzt immer gezeigt |
| App-Tasten tot | Google-Launcher hat sie gesteuert | Bedienungshilfe-Dienst + `tcl tasten` |
| Lautstärke laggt, springt um 2 | Tasten-Filter hat bei jeder Taste Dateien gelesen | Lautstärke & Co. werden sofort durchgelassen, Belegung im Hintergrund geladen |
| Ausschalten-Knopf startet nur den Bildschirmschoner | Android erlaubt normalen Apps kein Standby | Knopf entfernt |
| WLAN-Name fehlt | Android verrät ihn nur mit Standort-Recht und eingeschaltetem Standort | `pm grant ... ACCESS_FINE_LOCATION`, Standort an |
| Google-TV-Bildschirmschoner-Bilder | liegen nicht auf dem TV, werden gestreamt | öffentliche Liste der Chromecast-Backdrops |

## 5. Projektaufbau

```
tcl.sh                 das Skript (Bash), alle Befehle
tcl.cmd                Starter für CMD (ruft Git Bash)
listen/werbung.txt     Werbung/Tracking, wird abgeschaltet
listen/apps.txt        vorinstallierte Apps, die weg sollen
listen/extras.txt      Ballast (optional)
listen/niemals.txt     wird nie angefasst
home/                  Quellcode von TCL Home (Java), build.sh, tcl-home.apk
tools/wallpaper.py     erzeugt das eingebaute Bergbild
zustand/<seriennr>/    Ausgangszustand des TVs (nicht löschen, nicht im Git)
backup/<datum>/        Backups (nicht im Git)
```

## 6. Befehle

| Befehl | Was |
|---|---|
| `tcl verbinden <ip>` | ADB-Verbindung |
| `tcl check` | zeigt, was sich ändern würde |
| `tcl patch` | alles, mit Backup vorher |
| `tcl werbung` / `apps` / `extras` | Pakete abschalten |
| `tcl dns [aus]` | DNS-Filter |
| `tcl youtube` | SmartTube |
| `tcl home [aus]` | TCL Home an/aus |
| `tcl update` | neue TCL-Home-Version auf den TV (nach `git pull`) |
| `tcl tasten [aus]` | Fernbedienungstasten lernen / Dienst aus |
| `tcl taste <nr> <ziel>` | eine Taste umbelegen |
| `tcl hintergrund <bild>` | ein Hintergrundbild |
| `tcl hintergruende [n\|ordner\|aus]` | wechselnde Hintergründe |
| `tcl backup` / `wiederherstellen` / `neu` | Backup, zurückspielen, alles frisch |
| `tcl rueckgaengig` | Originalzustand |

---

## 7. Auf andere TVs übertragen

Ob das geht, hängt an einer Frage: **Lässt der TV Befehle über ADB zu?**

| System | Apps abschalten | Home-Screen tauschen | DNS-Filter | Fazit |
|---|---|---|---|---|
| Android TV / Google TV (Sony, Philips, TCL, Hisense-GTV, Xiaomi, ...) | ja | ja | ja | dieses Projekt passt |
| Fire TV (Stick, Fire-TV-Fernseher) | ja | ja | ja | Original [dumbtv](https://github.com/humblemuzzu/dumbtv) nehmen |
| **Samsung (Tizen)** | nur Store-Apps | **nein** | nur per Router/Netzwerk | stark eingeschränkt, siehe unten |
| LG (webOS) | nein | nein | nur per Router/Netzwerk | stark eingeschränkt |
| Roku, Hisense VIDAA, Vizio | nein | nein | nur per Router | nur Einstellungen |

### 7.1 Anderer Android/Google TV

1. Projekt kopieren (oder dieses Repo nehmen) und `tcl verbinden <ip>`, dann `tcl check`.
2. Bei „Pakete, die in keiner Liste stehen“ schauen, was der Hersteller mitliefert.
   Werbe-Apps in `listen/werbung.txt` oder `listen/apps.txt`, alles für Eingänge und
   Bild in `listen/niemals.txt`.
3. Herstellerpakete anpassen: TCL heißt `com.tcl.*`, Sony `com.sony.*`, Philips/Skyworth
   `com.smartdevice.*`/`org.droidtv.*`, Hisense `com.hisense.*`/`com.vidaa.*`,
   Xiaomi `com.mitv.*`/`com.xiaomi.*`. Chip-Pakete (MediaTek `com.mediatek.*`, Realtek
   `com.realtek.*`) **nie** abschalten, ohne zu wissen, was sie tun.
4. Erst `tcl backup`, dann Schritt für Schritt `tcl werbung`, TV testen, dann den Rest.
5. TCL Home funktioniert auf jedem Google TV mit Android 8 oder neuer. Die Ausblendung
   der Hersteller-Apps steht in `home/src/tv/dumbtv/home/Catalog.java`
   (`!it.id.startsWith("com.tcl.")`). Für andere Marken den Präfix anpassen.
6. `tcl tasten` lernt jede Fernbedienung neu.

Regel: Nie ein Paket abschalten, das du nicht verstehst, und nach jedem Schritt den TV
einmal neu starten. Was nach dem Neustart kaputt ist, mit `tcl rueckgaengig` oder
`adb shell pm enable <paket>` zurückholen.

### 7.2 Samsung (Tizen)

Samsung lässt **kein ADB** zu. Der Entwicklermodus (Apps-Bereich, Ziffern `12345`) erlaubt
nur das Werkzeug `sdb`. Damit kann man Apps installieren und Store-Apps entfernen, aber
**keine Systemeinstellungen ändern, keine Samsung-Dienste abschalten und keinen
Home-Screen tauschen**. Ein Skript wie `tcl.sh` ist auf Samsung deshalb nicht möglich.
Was trotzdem geht, die Menüpfade unterscheiden sich je nach Baujahr:

**Am TV einstellen**
- *Einstellungen › Allgemein › Bedingungen & Datenschutz* (bzw. *Datenschutz*):
  - **Infos zur Wiedergabe / Viewing Information Services (ACR)** aus. Das ist die
    Inhaltserkennung, die meldet, was du schaust.
  - **Interessenbasierte Werbung** aus
  - **Spracherkennungsdienste** aus, wenn du Bixby nicht nutzt
  - Marketing-Zustimmungen widerrufen
- *Einstellungen › Allgemein › Funktionen von Smart Hub*:
  - **Mit Smart Hub-Startseite starten** aus. Dann startet der TV auf dem letzten Eingang
    statt auf dem Werbe-Hub.
  - **Letzte App automatisch starten** nach Wunsch
- *Einstellungen › Support › Software-Update* nach Wunsch

**DNS-Filter**
- *Einstellungen › Allgemein › Netzwerk › Netzwerkstatus › IP-Einstellungen ›
  DNS-Einstellung: Manuell eingeben* und **94.140.14.14** eintragen (AdGuard DNS).
  Blockt einen großen Teil der Samsung-Werbung und -Telemetrie.
- Besser für alle Geräte: denselben DNS in der **FRITZ!Box** eintragen (*Internet ›
  Zugangsdaten › DNS-Server*) oder ein Pi-hole / AdGuard Home im Netz betreiben.
- YouTube-Werbung lässt sich per DNS nicht blocken. Auf Samsung gibt es dafür das
  Community-Projekt **TizenBrew** mit **TizenTube** (YouTube ohne Werbung, Installation
  über den Entwicklermodus). Das ist kein offizielles Samsung-Angebot, also vorher die
  aktuelle Anleitung des Projekts lesen.

**Der saubere Weg für Samsung:** einen **Google-TV-Streamer, Chromecast mit Google TV
oder Fire-TV-Stick** an HDMI anschließen und dieses Projekt (bzw. dumbtv beim Fire TV) auf
dem Stick anwenden. Den Samsung selbst dann **nicht mit dem Internet verbinden**. So
bekommt er keine Werbung und keine Updates, er ist nur noch Bildschirm. Startet er mit
dem letzten Eingang (siehe oben), siehst du nur noch deinen Home-Screen.

Für Hotels gibt es noch den **Hotel- bzw. Hospitality-Modus** (bei vielen Modellen am TV
mit der Infrarot-Fernbedienung *Mute, 1, 1, 9, Enter*). Damit lassen sich Start-Eingang
und Menüs festlegen. Vorsicht: Falsche Einstellungen dort sperren Menüs. Nur nutzen, wenn
du weißt, was du tust.

### 7.3 LG (webOS)

Wie Samsung: kein ADB, kein Launcher-Tausch. Am TV unter *Einstellungen › Allgemein ›
System › Zusätzliche Einstellungen* bzw. *Datenschutz*: **Live Plus** (Inhaltserkennung)
aus, **Werbung / Benutzerverträge** einschränken, **Home Promotion** und **Content
Recommendation** aus. DNS manuell in den Netzwerk-Einstellungen oder im Router. Sauberer
Weg ebenfalls: Streaming-Stick an HDMI, TV offline.

### 7.4 Checkliste für jeden neuen TV

1. Welches System? (Einstellungen › Info). Android/Google TV → Abschnitt 7.1, sonst 7.2/7.3
2. Backup bzw. Fotos von den Einstellungen machen
3. Werbung/Tracking in den Datenschutz-Einstellungen aus
4. DNS-Filter (Router oder TV)
5. Android TV: `tcl check` → Listen anpassen → `tcl patch`
6. Testen: Eingänge, Fernbedienung, Ton, Casten, Neustart
7. Was kaputt ist: einzeln wieder einschalten

---

*Grundlage: [dumbtv](https://github.com/humblemuzzu/dumbtv) (MIT), die TCL-Berichte aus dessen
Gerätekatalog, [SmartTube](https://github.com/yuliskov/SmartTube) und die öffentliche Liste der
[Chromecast-Backdrops](https://github.com/dconnolly/chromecast-backgrounds).*
