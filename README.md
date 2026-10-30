# TCL 65C735 dumb machen

Ein Skript, das deinen TCL Google TV aufräumt: **keine Werbung, keine Promo-Reihen,
keine TCL-Apps und kein Rakuten TV**, dafür ein schlichter Home-Screen. Der zeigt
deine Apps als Raster über einem Bergbild, mit Uhr und Datum links oben und
**Eingänge · WLAN · Einstellungen** rechts oben.

Casten vom Handy (Chromecast, AirPlay), Fernbedienung, Sprachsuche und die
HDMI-Eingänge bleiben. Alles läuft per ADB vom Computer aus, ohne Root. Nichts
wird gelöscht, nur deaktiviert. Alles lässt sich zurückdrehen.

## Windows: einmal einrichten

**1. Git für Windows installieren.** Dafür brauchst du kein winget. Auf
[git-scm.com/download/win](https://git-scm.com/download/win) den Installer
herunterladen („64-bit Git for Windows Setup“) und bei allem *Weiter* klicken.

**2. Dieses Projekt holen.** CMD öffnen und eingeben:

```bat
cd %USERPROFILE%\Desktop
```

```bat
git clone -b claude/serene-ramanujan-fj301a https://github.com/never2salty/tcl
```

Jetzt liegt auf dem Desktop ein Ordner `tcl`.

**3. platform-tools hineinlegen.** Die heruntergeladene ZIP entpacken. Den
entstandenen Ordner **`platform-tools`** (da drin liegen `adb.exe` und viele
andere Dateien) komplett in den Ordner `tcl` auf dem Desktop schieben. Mehr musst
du mit den Dateien nicht machen.

**4. Am TV Entwickleroptionen einschalten.** *Einstellungen › System › Info ›
Android TV OS-Build* markieren und 7× OK drücken, bis „Sie sind jetzt Entwickler“
kommt. Dann *Einstellungen › System › Entwickleroptionen › USB-Debugging*
einschalten.

**5. IP-Adresse des TVs.** *Einstellungen › Netzwerk und Internet ›* dein WLAN ›
Status. Dort steht sie, z. B. `192.168.178.27`.

## Patchen

In CMD (ohne `./` und ohne `.sh`):

```bat
cd %USERPROFILE%\Desktop\tcl
```

```bat
tcl verbinden 192.168.178.27
```

Am TV „USB-Debugging zulassen?“ mit Haken bei *Immer zulassen* bestätigen.

```bat
tcl check
```

Zeigt, was sich ändern würde. Ändert noch nichts.

```bat
tcl patch
```

Macht zuerst ein Backup und fragt dann vor jedem Schritt mit j/N. Wenn der TV per
Play Protect fragt, **Trotzdem installieren** drücken. Danach den TV etwa eine
Minute anlassen.

Alle Befehle unten funktionieren genauso: In CMD schreibst du `tcl backup`, in
Git Bash, auf dem Mac oder unter Linux `./tcl.sh backup`.

## Was passiert

| Schritt | Befehl | Was es macht |
|---|---|---|
| Werbung | `./tcl.sh werbung` | TCL-Werbekanäle, Promo-Kacheln, Partner-App-Installationen, Telemetrie, Promo-Bildschirmschoner ([listen/werbung.txt](listen/werbung.txt)) |
| Apps | `./tcl.sh apps` | vorinstallierte Apps weg: Rakuten TV, Pluto TV, ... ([listen/apps.txt](listen/apps.txt)) |
| Ballast | `./tcl.sh extras` | Alexa, Anleitung, TCL-Browser, ... ([listen/extras.txt](listen/extras.txt)) |
| DNS-Filter | `./tcl.sh dns` | Private DNS auf AdGuard: blockt Werbung und Tracking im ganzen TV |
| YouTube | `./tcl.sh youtube` | [SmartTube](https://github.com/yuliskov/SmartTube): YouTube ohne Werbung und ohne Shorts |
| Home-Screen | `./tcl.sh home` | TCL Home statt Google TV (siehe unten) |
| Hintergrund | `./tcl.sh hintergrund foto.jpg` | eigenes Bild statt der eingebauten Berge |
| Hintergründe | `./tcl.sh hintergruende` | 30 zufällige Google-/Chromecast-Backdrops, wechseln stündlich |

[listen/niemals.txt](listen/niemals.txt) wird nie angefasst: HDMI-Eingänge,
Fernbedienung, Einstellungen, Chromecast, AirPlay, Sprachsuche, Play Store,
TCL-Systemdienste. Eine App, die du doch willst, kommentierst du in der Liste mit
`#` aus.

## Der Home-Screen

**TCL Home** ist [dumbtv home](https://github.com/humblemuzzu/dumbtv/tree/main/launcher)
(MIT-Lizenz), für diesen TV angepasst. Der Code liegt in [home/](home/):

- Apps als Raster mit großen Kacheln über einem Hintergrundbild
- oben rechts **Eingänge** (Liste deiner HDMI-Eingänge), **WLAN**, **Einstellungen**
  und **Optionen**
- Apps, die du selbst installierst, erscheinen sofort, auch Handy-Apps ohne TV-Banner
  (z. B. ein Browser). TCL-eigene Apps sind ausgeblendet. Unter *Optionen › Apps on home screen*
  blendest du jede App ein oder aus, auch den Play Store.
- Halte OK auf einer Kachel zum Verschieben, Umbenennen oder Ausblenden.
- Kein Internetzugriff, keine Werbung, keine Vorschläge.

Die App wird bei jeder Änderung in `home/` von GitHub Actions gebaut und als
`home/tcl-home.apk` ins Repo gelegt. `git pull` holt die neueste Version.

## Sperrbildschirm und WLAN-Anzeige

- **WLAN:** Unter dem Datum stehen der WLAN-Name und die Signalstärke (oder „LAN-Kabel“).
- **Sperrbildschirm:** Die Zurück-Taste auf dem Home-Screen zeigt deine Hintergründe
  groß mit Uhr, Datum und WLAN. Die Bilder wechseln jede Minute. Jede Taste bringt
  dich zurück. Derselbe Bildschirm ist auch der Bildschirmschoner des TVs.
- **Einstellen** unter *Optionen*: *Zurück-Taste* (Sperrbildschirm oder erste Kachel)
  und *Sperrbildschirm nach* (5 Min bis 1 Std oder Nie).

Diese Funktionen brauchen ein paar Rechte, die `tcl home` setzt: Standort (nur damit
Android den WLAN-Namen verrät), Einstellungen schreiben (Bildschirmschoner-Zeit) und
den Bedienungshilfe-Dienst „TCL Home Tasten“ (Fernbedienung). Die App
hat weiterhin keinen Internetzugriff.

## Apps aktualisieren

Der Play Store aktualisiert deine Apps weiter automatisch im Hintergrund, das Skript
blockiert das nicht. Von Hand: *Optionen › Apps aktualisieren (Play Store)* öffnet die
Update-Liste. Automatische Updates stellst du im Play Store unter Profil ›
Einstellungen ein. SmartTube aktualisiert sich selbst, TCL Home mit `git pull` und
`tcl update`.

## Tasten der Fernbedienung

Die App-Tasten hat der Google-TV-Home-Screen gesteuert, deshalb taten sie nach dem
Patch nichts mehr. `tcl tasten` belegt sie neu:

```bat
tcl tasten
```

Für jede Taste: am TV einmal drücken, dann am PC Enter. So lernt das Skript die
Tastencodes deiner Fernbedienung.

| Taste | öffnet |
|---|---|
| Netflix | Netflix |
| Prime Video | Apple TV |
| YouTube | SmartTube (oder YouTube, wenn SmartTube fehlt) |
| TCL Channel | IPTV Smarters Pro |
| Einstellungen (Zahnrad) | TV-Einstellungen |
| Favoriten (Lesezeichen) | schiebt die ausgewählte App nach vorne (oben links) |

Merkst du, dass Lautstärke oder Steuerkreuz hängen, schaltet `tcl tasten aus` den
Tasten-Dienst ab. Dann tun die App-Tasten nichts mehr, alles andere ist wie ab Werk.

Eine Taste umbelegen: `tcl taste <nummer> <ziel>`. Die Nummer zeigt `tcl tasten` an.
Das Ziel ist ein App-Paketname oder `favorit`, `settings`, `wifi`, `inputs`, `saver`
(Sperrbildschirm) oder `home`. `tcl taste <nummer> aus` gibt die
Taste wieder frei.

## Wechselnde Hintergründe

```bat
tcl hintergruende
```

Lädt 30 zufällige Fotos aus den Chromecast-/Google-TV-Backdrops (eine öffentliche
[Liste mit ~700 Bildern](https://github.com/dconnolly/chromecast-backgrounds)) nach
`hintergruende/` und schiebt sie auf den TV. Sie wechseln stündlich. Mehr oder
weniger Bilder: `tcl hintergruende 60`.

- **Eigene Sammlung:** Bilder in einen Ordner legen, dann `tcl hintergruende C:\Pfad\zum\Ordner`.
  Bilder, die dir nicht gefallen, löschst du aus `hintergruende\` und rufst
  `tcl hintergruende hintergruende` auf.
- **Wechsel ändern:** am TV *Optionen › Wallpaper rotation* (jede Rückkehr, stündlich,
  täglich, nach Tageszeit). *Optionen › Next wallpaper* springt sofort weiter.
  Oder beim Laden: `set ROTATE=daily` (CMD) vor dem Befehl.
- **Weg damit:** `tcl hintergruende aus`

Die Fotos sind für den privaten Gebrauch, die Rechte liegen bei den Fotografen.

## Backup und alles neu

```bash
./tcl.sh backup
```

Speichert unter `backup/<Datum>/`: TV-Einstellungen, welche Pakete aus sind,
deine installierten Apps, die Home-Screen-Einstellungen und das Hintergrundbild.
`./tcl.sh patch` macht das jedes Mal vorher automatisch.

```bash
./tcl.sh wiederherstellen
```

Spielt das neueste Backup auf den TV, z. B. nach einem Werksreset: Werbung aus,
Apps weg, DNS, SmartTube, Home-Screen, Hintergrund und Kachelreihenfolge. Am Ende
listet es Apps aus dem Backup, die jetzt fehlen. Die holst du aus dem Play Store.
Ein älteres Backup gibst du mit an: `./tcl.sh wiederherstellen backup/2026-10-29_2014`.

```bash
./tcl.sh neu
```

Alles von Grund auf neu: Backup machen, alles zurücksetzen, frisch patchen, Backup
zurückspielen. Gut, wenn etwas komisch ist.

## Zurück zum Original

```bash
./tcl.sh rueckgaengig
```

Schaltet alles wieder ein, setzt DNS und Bildschirmschoner zurück und fragt, ob
TCL Home und SmartTube runter sollen. Ein Werksreset (*Einstellungen › System ›
Info › Zurücksetzen*) macht ebenfalls alles rückgängig.

Einzelne Schritte zurück:

```bash
./tcl.sh home aus
```

```bash
./tcl.sh dns aus
```

## Updates und neu patchen

- **TCL- und Google-Updates laufen weiter.** Das Skript blockiert keine Updates.
- Nach einem großen Update kann der Google-TV-Home-Screen zurückkommen oder eine App
  wieder auftauchen. Dann einfach `./tcl.sh patch` nochmal. Patchen kannst du so oft
  du willst, es überspringt, was schon erledigt ist.
- Neue Version dieses Skripts holen: `git pull`

## Vom Handy an den TV pushen

- **Chromecast** (Netflix, Prime, Disney+, Fotos, YouTube-App, ...) und **AirPlay**
  bleiben an.
- **YouTube ohne Werbung:** In SmartTube *Einstellungen › Mit Handy verknüpfen*, dann
  in der YouTube-App am Handy *Auf TV ansehen › Mit TV-Code verbinden*. Wenn du nur so
  castest, kannst du die normale YouTube-App abschalten. Das Skript fragt danach,
  macht es mit `-y` aber nie automatisch.

## Gut zu wissen

- **Kein Internet mehr in Apps?** `./tcl.sh dns aus`
- **Mehrere Geräte an adb?** `ADB_SERIAL=192.168.178.42:5555 ./tcl.sh ...`
- **Mac/Linux:** Gleiche Befehle im Terminal. `adb` per Homebrew/Paketmanager oder
  `platform-tools` in den Ordner legen.

## Getestet

Ich konnte das Skript und den Home-Screen nicht an einem echten 65C735
ausprobieren. Das Skript wurde gegen einen simulierten TV getestet, der
Home-Screen wurde kompiliert. Die Paketlisten stammen von anderen
TCL-Google-TVs (G08, G10). Pakete, die es auf deinem TV nicht gibt, überspringt
das Skript. Fang mit `./tcl.sh check` an und mach vorher ein Backup.
