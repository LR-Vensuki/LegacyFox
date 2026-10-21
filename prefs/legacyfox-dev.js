// LegacyFox development prefs: installed by tools/deploy.sh only, never in
// the package. Chrome JS output goes to stderr (lf.log with the debug file).
pref("browser.dom.window.dump.enabled", true);
pref("devtools.console.stdout.chrome", true);
pref("geckoview.logging", "Debug");
