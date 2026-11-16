// Was CleanHome zeigt. Nach einer Änderung: samsung\install.ps1 erneut ausführen.
//
// Jeder Eintrag ist ein Teil des App-Namens (Groß/Klein egal) oder eine App-ID.
// Die Namen und IDs deines TVs zeigt die Kachel "Diagnose" ganz unten.

// Oben, in dieser Reihenfolge. Was nicht installiert ist, wird übersprungen.
var PINNED = [
  { match: ["netflix"],                        label: "Netflix",     color: "#b00710" },
  { match: ["prime video", "amazon"],          label: "Prime Video", color: "#00a8e1" },
  { match: ["youtube"],                        label: "YouTube",     color: "#c4302b", not: ["kids", "music", "tv"] },
  { match: ["apps", "samsung apps", "com.samsung.tv.store", "org.volt.apps"], label: "App Store", color: "#3d5afe", exact: true }
];

// Nie zeigen. Einfach Namensteile oder IDs ergänzen.
var HIDDEN = [
  "e-manual", "samsung promotion", "tv plus", "universal guide", "bixby"
];

// Falls der TV keine App-Liste herausgibt, probiert CleanHome diese bekannten IDs.
var FALLBACK = [
  { label: "Netflix",     color: "#b00710", ids: ["org.tizen.netflix-app", "3201907018807", "11101200001"] },
  { label: "Prime Video", color: "#00a8e1", ids: ["org.tizen.primevideo", "3201910019365", "3201512006785"] },
  { label: "YouTube",     color: "#c4302b", ids: ["111299001912", "9Ur5IzDKqV.TizenYouTube"] },
  { label: "Disney+",     color: "#0b1a5e", ids: ["3201901017640", "MCmYXNxgcu.DisneyPlus"] },
  { label: "App Store",   color: "#3d5afe", ids: ["com.samsung.tv.store", "org.volt.apps", "org.tizen.apps"] }
];
