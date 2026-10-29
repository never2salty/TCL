#!/usr/bin/env bash
# tcl.sh: macht einen TCL Google TV (getestet gedacht für den 65C735) "dumm":
# keine Werbung, keine Promo-Reihen, ein schlichter Home-Screen. Alles läuft über
# ADB, ohne Root, und lässt sich mit `./tcl.sh rueckgaengig` zurückdrehen.
#
#   ./tcl.sh verbinden <tv-ip>   ADB-Verbindung herstellen
#   ./tcl.sh check               zeigt, was sich ändern würde; ändert nichts
#   ./tcl.sh patch               alles nacheinander, fragt vor jedem Schritt
#   ./tcl.sh werbung             Werbe-/Tracking-Pakete deaktivieren
#   ./tcl.sh apps                vorinstallierte Apps weg (Rakuten TV, Pluto TV, ...)
#   ./tcl.sh extras              Ballast deaktivieren (Alexa, Anleitung, ...)
#   ./tcl.sh dns [aus]           werbefilterndes Private DNS an/aus
#   ./tcl.sh home [aus]          schlichter Home-Screen (TCL Home) an/aus
#   ./tcl.sh hintergrund <bild>  eigenes Hintergrundbild (jpg/png) auf den TV
#   ./tcl.sh youtube             SmartTube installieren (YouTube ohne Werbung)
#   ./tcl.sh backup              Backup von Einstellungen, Home-Screen und App-Liste
#   ./tcl.sh wiederherstellen    Patch + Backup neu aufspielen (z. B. nach Werksreset)
#   ./tcl.sh neu                 alles zurück, dann frisch patchen + Backup laden
#   ./tcl.sh rueckgaengig        alles zurück wie vorher
#
# Optionen: -y beantwortet alle Fragen mit Ja. Mehrere Geräte: ADB_SERIAL=<ip:port>.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

ADB=${ADB:-adb}
YES=0
DNS_HOST=${DNS_HOST:-dns.adguard-dns.com}

HOME_PKG=tv.dumbtv.home
HOME_APK=home/tcl-home.apk
HOME_MEDIA=/sdcard/Android/media/$HOME_PKG
STOCK_HOME="com.google.android.apps.tv.launcherx com.google.android.tungsten.setupwraith"

ST_PKG=org.smarttube.stable
ST_URL=https://github.com/yuliskov/SmartTube/releases/download/32.56s/SmartTube_stable_32.56_universal.apk
ST_SHA256=4a35b90940612e048e4e9cb9e10379f7db1e84f30375994129f10a571ee04ce5
YT_PKG=com.google.android.youtube.tv

AOSP_DREAM=com.android.dreams.basic/.Colors

# ---------------------------------------------------------------- Hilfen

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
die()  { printf 'Fehler: %s\n' "$*" >&2; exit 1; }

# adb ohne PATH-Gefummel: der platform-tools-Ordner darf neben diesem Skript oder in
# Downloads liegen.
find_adb() {
  command -v "$ADB" >/dev/null && return
  local d
  for d in ./platform-tools "$HOME/Downloads/platform-tools" "$HOME/Downloads/platform-tools-latest-windows/platform-tools" \
           "${USERPROFILE:-/nonexistent}/Downloads/platform-tools"; do
    if [[ -x $d/adb.exe ]]; then ADB=$d/adb.exe; return; fi
    if [[ -x $d/adb ]]; then ADB=$d/adb; return; fi
  done
  die "adb nicht gefunden. Den entpackten Ordner 'platform-tools' in diesen Ordner ($(pwd)) verschieben."
}

ask() {
  local a
  [[ $YES == 1 ]] && { printf '%s [j/N] j\n' "$1"; return 0; }
  read -r -p "$1 [j/N] " a </dev/tty || return 1
  [[ $a =~ ^[jJyY] ]]
}

adb_() { "$ADB" -s "$SERIAL" "$@"; }
dev()  { "$ADB" -s "$SERIAL" shell "$*" </dev/null 2>/dev/null | tr -d '\r'; }

# Paketnamen aus einer Liste: Kommentare und Leerzeilen weg.
pkgs_of() { sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$1"; }

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# Lädt $2 nach .cache/$1 und prüft die SHA-256 gegen $3.
fetch() {
  local out=.cache/$1
  mkdir -p .cache
  if [[ ! -f $out || $(sha256 "$out") != "$3" ]]; then
    note "lade $2"
    curl -fL --retry 4 --retry-delay 3 --connect-timeout 20 --progress-bar -o "$out.part" "$2" \
      || die "Download fehlgeschlagen: $2"
    mv "$out.part" "$out"
  fi
  [[ $(sha256 "$out") == "$3" ]] || { rm -f "$out"; die "Prüfsumme stimmt nicht für $1, nicht installiert"; }
  note "Prüfsumme ok"
  APK=$out
}

pick_device() {
  find_adb
  if [[ -n ${ADB_SERIAL:-} ]]; then
    SERIAL=$ADB_SERIAL
  else
    local list n
    list=$("$ADB" devices | tr -d '\r' | awk 'NR>1 && $2=="device" {print $1}')
    n=$(printf '%s' "$list" | grep -c . || true)
    [[ $n -eq 0 ]] && die "kein TV verbunden. Zuerst: ./tcl.sh verbinden <tv-ip>"
    [[ $n -gt 1 ]] && die "mehrere Geräte verbunden, eins wählen: ADB_SERIAL=<serial> ./tcl.sh ...  ($(printf '%s' "$list" | paste -sd' ' -))"
    SERIAL=$list
  fi
  [[ $(adb_ get-state 2>/dev/null | tr -d '\r') == device ]] || die "$SERIAL antwortet nicht (am TV 'Zulassen' gedrückt?)"
  # Nach Seriennummer, nicht IP: die IP kann sich ändern, der TV nicht.
  local id
  id=$(dev getprop ro.serialno)
  STATE=zustand/$(printf '%s' "${id:-$SERIAL}" | tr -c 'A-Za-z0-9._-' '_')
  mkdir -p "$STATE"
  touch "$STATE/deaktiviert.txt"
}

# Liest die Paketlisten des TVs einmal ein.
refresh() {
  ALL=$(dev pm list packages | sed 's/^package://')
  OFF=$(dev pm list packages -d | sed 's/^package://')
}
present()  { grep -qxF "$1" <<<"$ALL"; }
disabled() { grep -qxF "$1" <<<"$OFF"; }
never()    { pkgs_of listen/niemals.txt | grep -qxF "$1"; }

device_info() {
  local brand model build sdk
  brand=$(dev getprop ro.product.brand)
  model=$(dev getprop ro.product.model)
  build=$(dev getprop ro.build.display.id)
  sdk=$(dev getprop ro.build.version.sdk)
  say "Gerät:   $brand $model ($SERIAL)"
  say "Android: $(dev getprop ro.build.version.release) (sdk $sdk), Build $build"
  if ! dev pm list features | grep -q 'android.software.leanback'; then
    die "das ist kein Android/Google TV. Abbruch."
  fi
  if [[ ! $brand =~ [Tt][Cc][Ll] ]]; then
    say "Hinweis: Marke ist nicht TCL. Die Listen sind für TCL gemacht."
    ask "Trotzdem weitermachen?" || exit 1
  fi
}

# Speichert beim ersten Lauf, wie der TV vorher eingestellt war.
snapshot() {
  [[ -f $STATE/vorher.txt ]] && return
  {
    printf 'private_dns_mode=%s\n' "$(dev settings get global private_dns_mode)"
    printf 'private_dns_specifier=%s\n' "$(dev settings get global private_dns_specifier)"
    printf 'screensaver_components=%s\n' "$(dev settings get secure screensaver_components)"
  } >"$STATE/vorher.txt"
  dev pm list packages -d | sed 's/^package://' >"$STATE/vorher-deaktiviert.txt"
  note "Ausgangszustand gesichert in $STATE/"
}
before() { sed -n "s/^$1=//p" "$STATE/vorher.txt" | head -1; }

# Deaktiviert ein Paket und merkt es sich fürs Rückgängigmachen.
disable_pkg() {
  local p=$1 out
  if never "$p" && [[ ${2:-} != --home ]]; then note "geschützt   $p"; return; fi
  if ! present "$p"; then return; fi
  if disabled "$p"; then note "schon aus   $p"; return; fi
  out=$(dev pm disable-user --user 0 "$p")
  if [[ $out == *disabled-user* ]]; then
    note "deaktiviert $p"
    grep -qxF "$p" "$STATE/deaktiviert.txt" || printf '%s\n' "$p" >>"$STATE/deaktiviert.txt"
    OFF=$OFF$'\n'$p
  else
    note "abgelehnt   $p (${out:-keine Antwort})"
  fi
}

enable_pkg() {
  dev pm enable --user 0 "$1" | grep -q 'enabled' && note "aktiviert   $1"
  grep -vxF "$1" "$STATE/deaktiviert.txt" >"$STATE/deaktiviert.tmp" || true
  mv "$STATE/deaktiviert.tmp" "$STATE/deaktiviert.txt"
}

# Ist der Bildschirmschoner abgeschaltet, nimmt Android den eigenen, sonst bleibt das Bild stehen.
fix_screensaver() {
  local cur pkg
  cur=$(dev settings get secure screensaver_components)
  pkg=${cur%%/*}
  [[ -z $pkg || $pkg == null ]] && return
  if disabled "$pkg" || ! present "$pkg"; then
    if present com.android.dreams.basic; then
      dev settings put secure screensaver_components "$AOSP_DREAM"
      note "Bildschirmschoner: Android-Standard (Farben) statt $pkg"
    fi
  fi
}

# ---------------------------------------------------------------- Befehle

cmd_verbinden() {
  [[ -n ${1:-} ]] || die "usage: ./tcl.sh verbinden <tv-ip>[:port]"
  local target=$1
  [[ $target == *:* ]] || target=$target:5555
  find_adb
  "$ADB" connect "$target"
  say "Jetzt am TV 'USB-Debugging zulassen' bestätigen (Haken bei 'Immer zulassen')."
  for _ in $(seq 1 30); do
    [[ $("$ADB" -s "$target" get-state 2>/dev/null | tr -d '\r') == device ]] && { say "Verbunden: $target"; return; }
    sleep 1
  done
  die "keine Freigabe vom TV. Nochmal: ./tcl.sh verbinden $1"
}

cmd_check() {
  pick_device; device_info; refresh
  local p state
  for list in werbung apps extras; do
    step "$list.txt"
    while read -r p; do
      if ! present "$p"; then continue
      elif never "$p"; then state=geschützt
      elif disabled "$p"; then state="schon aus"
      else state="würde aus"; fi
      note "$(printf '%-11s %s' "$state" "$p")"
    done < <(pkgs_of "listen/$list.txt")
  done
  step "TCL-Pakete, die in keiner Liste stehen (bleiben an)"
  grep '^com\.tcl\.' <<<"$ALL" | while read -r p; do
    pkgs_of listen/werbung.txt | grep -qxF "$p" && continue
    pkgs_of listen/extras.txt | grep -qxF "$p" && continue
    never "$p" && continue
    note "$p$(disabled "$p" && printf ' (aus)')"
  done
  step "Installierte Apps (nicht vom System)"
  dev pm list packages -3 | sed 's/^package:/   /'
  step "Home-Screen"
  note "aktuell: $(dev cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)"
  present $HOME_PKG && note "dumbtv home ist installiert"
  step "DNS"
  note "private_dns_mode=$(dev settings get global private_dns_mode) private_dns_specifier=$(dev settings get global private_dns_specifier)"
}

cmd_werbung() {
  pick_device; refresh; snapshot
  step "Werbung und Tracking abschalten"
  ask "Pakete aus listen/werbung.txt deaktivieren?" || return 0
  local p
  while read -r p; do disable_pkg "$p"; done < <(pkgs_of listen/werbung.txt)
  fix_screensaver
}

cmd_apps() {
  pick_device; refresh; snapshot
  step "Vorinstallierte Apps entfernen (Rakuten TV, Pluto TV, ...)"
  ask "Apps aus listen/apps.txt deaktivieren?" || return 0
  local p
  while read -r p; do disable_pkg "$p"; done < <(pkgs_of listen/apps.txt)
}

cmd_extras() {
  pick_device; refresh; snapshot
  step "Ballast abschalten (Alexa, Anleitung, Browser, Play Spiele, ...)"
  ask "Pakete aus listen/extras.txt deaktivieren?" || return 0
  local p
  while read -r p; do disable_pkg "$p"; done < <(pkgs_of listen/extras.txt)
}

cmd_dns() {
  pick_device; snapshot
  if [[ ${1:-} == aus ]]; then
    step "Private DNS zurücksetzen"
    local mode spec
    mode=$(before private_dns_mode); spec=$(before private_dns_specifier)
    if [[ -z $mode || $mode == null ]]; then dev settings delete global private_dns_mode >/dev/null
    else dev settings put global private_dns_mode "$mode"; fi
    if [[ -z $spec || $spec == null ]]; then dev settings delete global private_dns_specifier >/dev/null
    else dev settings put global private_dns_specifier "$spec"; fi
    note "private_dns_mode=$(dev settings get global private_dns_mode)"
    return
  fi
  step "Werbefilter per DNS ($DNS_HOST)"
  note "Blockt Werbe- und Tracking-Server für den ganzen TV (Apps, Google TV, TCL)."
  note "YouTube-Werbung kommt von denselben Servern wie die Videos, dafür: ./tcl.sh youtube"
  ask "Private DNS auf $DNS_HOST setzen?" || return 0
  dev settings put global private_dns_specifier "$DNS_HOST"
  dev settings put global private_dns_mode hostname
  sleep 3
  if dev ping -c 1 -W 3 google.com >/dev/null; then
    note "Internet geht, DNS aktiv"
  else
    note "ping ohne Antwort. Wenn Apps kein Internet mehr haben: ./tcl.sh dns aus"
  fi
}

cmd_home() {
  pick_device; refresh; snapshot
  local p
  if [[ ${1:-} == aus ]]; then
    step "Google-TV-Home zurückholen"
    for p in $STOCK_HOME; do enable_pkg "$p"; done
    dev am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null
    note "TCL Home bleibt installiert (entfernen: adb uninstall $HOME_PKG)"
    return
  fi
  step "Schlichter Home-Screen (TCL Home)"
  note "App-Raster über einem Hintergrundbild, oben Eingänge, WLAN und Einstellungen."
  note "Keine Werbung, keine Vorschläge, kein Internet. TCL-Apps sind ausgeblendet."
  note "Dafür wird der Google-TV-Home-Screen deaktiviert (nicht gelöscht)."
  ask "TCL Home installieren und als Home-Screen setzen?" || return 0
  [[ -f $HOME_APK ]] || die "$HOME_APK fehlt. Neueste Version holen: git pull"
  note "installiere... Falls der TV fragt (Play Protect): 'Trotzdem installieren' drücken."
  local out
  out=$(adb_ install -r "$HOME_APK" 2>&1 | grep -m1 -E 'Success|Failure|failed')
  if [[ $out == *UPDATE_INCOMPATIBLE* ]]; then
    # Ein dumbtv home von woanders ist mit anderem Schlüssel signiert.
    note "ein anderes dumbtv home ist installiert, ersetze es"
    adb_ uninstall $HOME_PKG >/dev/null
    out=$(adb_ install -r "$HOME_APK" 2>&1 | grep -m1 -E 'Success|Failure|failed')
  fi
  note "$out"
  refresh
  present $HOME_PKG || die "TCL Home ist nicht installiert, Google TV bleibt Home-Screen"
  # Beide Pakete zusammen: setupwraith beantwortet HOME sonst selbst und kann abstürzen.
  for p in $STOCK_HOME; do disable_pkg "$p" --home; done
  # Bleibt noch ein TCL-Home übrig, zeigt Android sonst eine Auswahl.
  dev cmd package set-home-activity "$HOME_PKG/.Home" >/dev/null
  dev input keyevent KEYCODE_HOME
  sleep 2
  local now
  now=$(dev cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)
  note "HOME öffnet jetzt: $now"
  if [[ $now != $HOME_PKG/* ]]; then
    note "HOME zeigt nicht auf dumbtv home. Zurück mit: ./tcl.sh home aus"
    return 1
  fi
  note "Wichtig: TV jetzt ~1 Minute nicht ausschalten, damit Android den Zustand speichert."
  note "Apps ein-/ausblenden, sortieren, Kachelgröße: oben rechts 'Optionen'."
  note "Neue Apps: Play Store in Optionen > Apps on home screen anhaken."
}

cmd_youtube() {
  pick_device; refresh; snapshot
  step "YouTube ohne Werbung (SmartTube)"
  note "SmartTube: Open-Source-YouTube für TVs, ohne Werbung und ohne Shorts."
  note "Vom Handy pushen: in SmartTube 'Einstellungen > Mit Handy verknüpfen' einmal koppeln."
  ask "SmartTube installieren?" || return 0
  fetch smarttube.apk "$ST_URL" "$ST_SHA256"
  note "installiere (~30 MB)..."
  adb_ install -r "$APK" 2>&1 | grep -m1 -E 'Success|Failure|failed' | sed 's/^/   /'
  refresh
  present $ST_PKG || die "SmartTube ist nicht installiert"
  note "SmartTube installiert"
  if present $YT_PKG && ! disabled $YT_PKG; then
    note "Die normale YouTube-App braucht es, wenn du vom Handy per Chromecast an YouTube castest."
    # Nie per -y: ohne die App geht Chromecast an YouTube nicht mehr.
    if [[ $YES == 0 ]] && ask "Normale YouTube-App (mit Werbung) trotzdem deaktivieren?"; then
      disable_pkg $YT_PKG
    fi
  fi
}

cmd_hintergrund() {
  [[ -f ${1:-} ]] || die "usage: ./tcl.sh hintergrund <bild.jpg|png>"
  pick_device
  local ext=${1##*.}
  ext=$(printf '%s' "$ext" | tr 'A-Z' 'a-z')
  [[ $ext == jpg || $ext == jpeg || $ext == png || $ext == webp ]] || die "nur jpg, png oder webp"
  step "Hintergrundbild"
  dev mkdir -p "$HOME_MEDIA"
  dev rm -f "$HOME_MEDIA/wallpaper.jpg" "$HOME_MEDIA/wallpaper.jpeg" "$HOME_MEDIA/wallpaper.png" "$HOME_MEDIA/wallpaper.webp"
  adb_ push "$1" "$HOME_MEDIA/wallpaper.$ext" | tail -1 | sed 's/^/   /'
  note "erscheint, sobald du HOME drückst. Ohne eigenes Bild gibt es die eingebauten Berge."
}

# Ein Backup ist ein Ordner unter backup/: TV-Einstellungen, deaktivierte Pakete, App-Liste,
# Home-Screen-Einstellungen und Hintergrundbilder. `wiederherstellen` spielt es zurück.
cmd_backup() {
  pick_device
  local dir
  dir=backup/$(date +%Y-%m-%d_%H%M)
  mkdir -p "$dir"
  step "Backup nach $dir/"
  dev getprop >"$dir/geraet.txt"
  for ns in global secure system; do dev settings list $ns >"$dir/settings-$ns.txt"; done
  dev pm list packages -d | sed 's/^package://' >"$dir/deaktiviert.txt"
  dev pm list packages -3 | sed 's/^package://' >"$dir/apps.txt"
  cp "$STATE/deaktiviert.txt" "$dir/von-tcl-sh.txt" 2>/dev/null || true
  [[ -f $STATE/vorher.txt ]] && cp "$STATE/vorher.txt" "$dir/vorher.txt"
  # Android erlaubt adb das Lesen unter Android/media, nicht unter Android/data.
  adb_ pull "$HOME_MEDIA" "$dir/home" >/dev/null 2>&1 || true
  dev "cat /sdcard/Android/data/$HOME_PKG/files/home.conf" >"$dir/home.conf" 2>/dev/null
  [[ -s $dir/home.conf ]] || rm -f "$dir/home.conf"
  note "$(wc -l <"$dir/deaktiviert.txt" | tr -d ' ') deaktivierte Pakete, $(wc -l <"$dir/apps.txt" | tr -d ' ') installierte Apps"
  [[ -f $dir/home.conf || -d $dir/home ]] && note "Home-Screen-Einstellungen gesichert"
  note "fertig. Zurückspielen: ./tcl.sh wiederherstellen $dir"
}

latest_backup() { find backup -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1; }

cmd_wiederherstellen() {
  local dir=${1:-$(latest_backup)}
  [[ -n $dir && -d $dir ]] || die "kein Backup gefunden. Erst: ./tcl.sh backup"
  pick_device; refresh; snapshot
  step "Wiederherstellen aus $dir/"
  ask "Patch und Backup auf den TV spielen?" || return 0
  local saved=$YES p
  YES=1
  cmd_werbung; cmd_apps
  # Was im Backup aus war und in einer der Listen steht, wieder ausschalten.
  if [[ -f $dir/von-tcl-sh.txt ]]; then
    refresh
    while read -r p; do
      [[ -z $p ]] && continue
      [[ " $STOCK_HOME " == *" $p "* ]] && continue
      disable_pkg "$p"
    done <"$dir/von-tcl-sh.txt"
  fi
  if grep -q '^private_dns_mode=hostname' "$dir/settings-global.txt" 2>/dev/null; then
    DNS_HOST=$(sed -n 's/^private_dns_specifier=//p' "$dir/settings-global.txt" | head -1)
    cmd_dns
  fi
  if grep -qx "$ST_PKG" "$dir/apps.txt" 2>/dev/null; then cmd_youtube; fi
  if grep -qx "com.google.android.apps.tv.launcherx" "$dir/deaktiviert.txt" 2>/dev/null \
      || grep -qx "$HOME_PKG" "$dir/apps.txt" 2>/dev/null; then
    cmd_home
    dev mkdir -p "$HOME_MEDIA"
    if [[ -d $dir/home ]]; then
      adb_ push "$dir/home/." "$HOME_MEDIA/" >/dev/null && note "Hintergrund zurückgespielt"
    fi
    if [[ -f $dir/home.conf ]]; then
      adb_ push "$dir/home.conf" "$HOME_MEDIA/home.conf" >/dev/null && note "Home-Screen-Einstellungen zurückgespielt"
    fi
  fi
  YES=$saved
  step "Apps aus dem Backup, die jetzt fehlen (aus dem Play Store neu laden)"
  refresh
  while read -r p; do present "$p" || note "$p"; done <"$dir/apps.txt"
}

cmd_neu() {
  pick_device
  step "Alles neu: Backup, zurücksetzen, frisch patchen, Backup zurückspielen"
  ask "Wirklich alles neu aufspielen?" || return 0
  cmd_backup
  local dir
  dir=$(latest_backup)
  YES=1 cmd_rueckgaengig_keep
  cmd_wiederherstellen "$dir"
}

cmd_patch() {
  pick_device; device_info
  cmd_backup
  cmd_werbung
  cmd_apps
  cmd_extras
  cmd_dns
  cmd_youtube
  cmd_home
  step "Fertig"
  note "Zurück geht alles mit: ./tcl.sh rueckgaengig"
  note "Nach einem TCL-Firmware-Update ggf. nochmal ./tcl.sh patch laufen lassen."
}

cmd_rueckgaengig() {
  pick_device; refresh
  [[ -f $STATE/vorher.txt ]] || die "kein gespeicherter Ausgangszustand für $SERIAL in $STATE/"
  step "Alles zurück"
  ask "Alle von tcl.sh deaktivierten Pakete wieder aktivieren und Einstellungen zurücksetzen?" || return 0
  reset_all
  if present $HOME_PKG && ask "TCL Home deinstallieren?"; then adb_ uninstall $HOME_PKG | sed 's/^/   /'; fi
  if present $ST_PKG && ask "SmartTube deinstallieren?"; then adb_ uninstall $ST_PKG | sed 's/^/   /'; fi
  note "Fertig. Der TV ist wieder wie vorher."
}

# Für `neu`: zurücksetzen, aber installierte Apps behalten.
cmd_rueckgaengig_keep() {
  pick_device; refresh
  [[ -f $STATE/vorher.txt ]] || return 0
  step "Zurücksetzen"
  reset_all
}

reset_all() {
  local p ss
  while read -r p; do [[ -n $p ]] && enable_pkg "$p"; done < <(cat "$STATE/deaktiviert.txt")
  cmd_dns aus
  ss=$(before screensaver_components)
  if [[ -n $ss && $ss != null ]]; then dev settings put secure screensaver_components "$ss"; fi
  dev am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null
}

# ---------------------------------------------------------------- Start

args=()
for a in "$@"; do
  case $a in
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]+"${args[@]}"}"

cmd=${1:-}
shift || true
case $cmd in
  verbinden|check|patch|werbung|apps|extras|dns|home|hintergrund|youtube|backup|wiederherstellen|neu|rueckgaengig)
    "cmd_$cmd" "$@" ;;
  *) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
