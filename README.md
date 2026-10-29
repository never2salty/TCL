# TCL 65C735 dumb machen

Ein Skript, das deinen TCL Google TV aufräumt: **keine Werbung, keine Promo-Reihen,
ein schlichter Home-Screen** mit deinen Apps und HDMI-Eingängen. Casten vom Handy
(Chromecast, AirPlay), Fernbedienung, Sprachsuche und die Eingänge bleiben.

Alles läuft über ADB vom Computer aus, ohne Root. Es wird nichts gelöscht, nur
deaktiviert, und `./tcl.sh rueckgaengig` dreht alles zurück. Ein Werksreset tut
das auch.

Gemacht nach dem Vorbild von [dumbtv](https://github.com/humblemuzzu/dumbtv).
dumbtv selbst ist für Fire TV gebaut. Der 65C735 läuft mit Google TV
(Android 11), deshalb gibt es hier ein eigenes Skript. Paketlisten und Vorgehen
stammen aus den TCL-Berichten im dumbtv-Katalog (G08, G10).

## Was passiert

| Schritt | Befehl | Was es macht |
|---|---|---|
| Werbung | `./tcl.sh werbung` | schaltet TCL-Werbekanäle, Promo-Kacheln, Partner-App-Installationen, Telemetrie und den Promo-Bildschirmschoner ab ([listen/werbung.txt](listen/werbung.txt)) |
| Ballast | `./tcl.sh extras` | optional: Alexa, Anleitung, TCL-Browser, Play Spiele, Drucken, ... ([listen/extras.txt](listen/extras.txt)) |
| DNS-Filter | `./tcl.sh dns` | setzt Private DNS auf AdGuard DNS, blockt Werbung und Tracking im ganzen TV |
| YouTube | `./tcl.sh youtube` | installiert [SmartTube](https://github.com/yuliskov/SmartTube): YouTube ohne Werbung und ohne Shorts |
| Home-Screen | `./tcl.sh home` | ersetzt Google TV durch [dumbtv home](https://github.com/humblemuzzu/dumbtv/tree/main/launcher): Apps, Eingänge, Uhr. Sonst nichts. |

[listen/niemals.txt](listen/niemals.txt) wird nie angefasst: HDMI-Eingänge,
Fernbedienung, Einstellungen, Chromecast, AirPlay, Sprachsuche, Play Store,
TCL-Systemdienste.

Beide APKs werden von den offiziellen GitHub-Releases geladen und per SHA-256
geprüft, bevor sie auf den TV kommen.

## Einmal einrichten

**1. ADB am Computer.** [Android platform-tools](https://developer.android.com/tools/releases/platform-tools)
herunterladen und entpacken. Unter Windows das Skript in **Git Bash** ausführen
([git-scm.com](https://git-scm.com/download/win)), auf dem Mac und unter Linux im
normalen Terminal.

**2. Entwickleroptionen am TV.** *Einstellungen › System › Info › Android TV OS-Build*
markieren und 7× OK drücken, bis „Sie sind jetzt Entwickler“ erscheint. Dann
*Einstellungen › System › Entwickleroptionen › USB-Debugging* einschalten.

**3. IP-Adresse des TVs.** *Einstellungen › Netzwerk und Internet ›* dein WLAN bzw.
Ethernet. Dort steht sie, z. B. `192.168.178.42`.

## Patchen

```bash
git clone https://github.com/never2salty/tcl && cd tcl
```

```bash
./tcl.sh verbinden 192.168.178.42
```

Am TV erscheint „USB-Debugging zulassen?“: Haken bei *Immer zulassen*, dann OK.

```bash
./tcl.sh check
```

Zeigt, was sich ändern würde, und ändert noch nichts. Danach:

```bash
./tcl.sh patch
```

Fragt vor jedem Schritt mit j/N. Mit `./tcl.sh patch -y` läuft alles ohne
Rückfragen durch (die normale YouTube-App bleibt dabei an, siehe unten).

Beim Installieren fragt der TV evtl. per Play Protect nach: **Trotzdem
installieren** drücken. Nach dem Home-Screen-Schritt den TV etwa eine Minute
anlassen, bevor du ihn ausschaltest, damit Android den Zustand speichert.

## Vom Handy an den TV pushen

- **Chromecast** (Netflix, Prime, Disney+, Fotos, YouTube-App, ...) bleibt komplett
  an. Einfach wie immer auf das Cast-Symbol tippen.
- **AirPlay** vom iPhone bleibt an.
- **YouTube ohne Werbung:** In SmartTube einmal *Einstellungen › Mit Handy verknüpfen*,
  dann in der YouTube-App am Handy *Auf TV ansehen › Mit TV-Code verbinden*. Danach
  landen Videos, die du vom Handy schickst, in SmartTube. Wenn du **nur** so castest,
  kannst du die normale YouTube-App abschalten. Das Skript fragt danach, macht es mit
  `-y` aber nie automatisch.

## Zurück

```bash
./tcl.sh rueckgaengig
```

Schaltet alle Pakete wieder ein, die das Skript abgeschaltet hat, setzt DNS und
Bildschirmschoner zurück und fragt, ob dumbtv home und SmartTube runter sollen.
Der Ausgangszustand wird beim ersten Lauf in `zustand/` gespeichert. Lösch den
Ordner nicht.

Einzelne Schritte zurück:

```bash
./tcl.sh home aus
```

```bash
./tcl.sh dns aus
```

## Gut zu wissen

- **Neue Apps installieren:** In dumbtv home *Optionen* öffnen (von der obersten Reihe nach
  oben) und den Play Store einblenden. Oder kurz `./tcl.sh home aus`, installieren,
  dann `./tcl.sh home`.
- **Nach einem TCL-Update** kann der Google-TV-Home-Screen zurückkommen. Dann
  einfach `./tcl.sh patch` nochmal laufen lassen.
- **Kein Internet mehr in Apps?** `./tcl.sh dns aus`. Einen anderen Filter nimmst du
  so: `DNS_HOST=dns.mullvad.net ./tcl.sh dns`.
- **TCL-Pakete, die das Skript nicht kennt,** listet `./tcl.sh check` unten auf.
  Es lässt sie in Ruhe. Was du davon loswerden willst, schreib in
  `listen/extras.txt`.
- **Mehrere Geräte an adb?** `ADB_SERIAL=192.168.178.42:5555 ./tcl.sh ...`

## Getestet

Ich konnte das Skript nicht an einem echten 65C735 ausprobieren. Getestet wurde
es gegen einen simulierten TV. Die Paketlisten kommen von anderen TCL-Google-TVs
(G08 mit Android 14, G10 mit Android 12), auf denen sie ohne Probleme liefen. Der
C735 hat einen MediaTek-Chip und Android 11, deshalb können einzelne Pakete
anders heißen oder fehlen. Fehlende Pakete überspringt das Skript einfach.
Fang mit `./tcl.sh check` an.
