// LegacyFox default prefs: Gecko in one process on 512 MB devices (A4-A6).
//
// Starting point: the low-memory set of gecko-w10m (tools/build-appx.sh),
// tightened for half to a quarter of that phone's memory.

// ---- One process ------------------------------------------------------------
pref("browser.tabs.remote.autostart", false);
pref("fission.autostart", false);
pref("dom.ipc.processCount", 1);

// ---- Memory -----------------------------------------------------------------
// Decoded images: 32 MB instead of w10m's 128 MB.
pref("image.mem.surfacecache.max_size_kb", 32768);
pref("image.mem.surfacecache.min_expiration_ms", 30000);
pref("image.mem.discardable", true);
pref("image.mem.animated.discardable", true);
// No pages kept alive for back/forward: they are reloaded instead.
pref("browser.sessionhistory.max_total_viewers", 0);
pref("browser.sessionhistory.max_entries", 20);
pref("browser.cache.memory.capacity", 4096);
pref("browser.cache.disk.capacity", 102400);
pref("browser.cache.disk.smart_size.enabled", false);
// JS: a small nursery and an early, frequent GC.
pref("javascript.options.mem.nursery.max_kb", 4096);
pref("javascript.options.mem.gc_high_frequency_heap_growth_max", 150);
pref("javascript.options.mem.gc_high_frequency_heap_growth_min", 120);
pref("javascript.options.mem.gc_low_frequency_heap_growth", 120);
pref("javascript.options.mem.gc_allocation_threshold_mb", 10);
// Video: keep little of the MSE buffer around.
pref("media.mediasource.eviction_threshold.video", 12582912);
pref("media.mediasource.eviction_threshold.audio", 2097152);
// Media data goes to the file cache only: it saves memory, and the memory
// cache handed corrupt samples near the end of files here.
pref("media.memory_cache_max_size", 0);
// Background tabs go to the session store when memory runs low.
pref("browser.tabs.unloadOnLowMemory", true);
pref("browser.sessionstore.interval", 30000);
pref("browser.sessionstore.max_tabs_undo", 3);
pref("browser.sessionstore.resume_from_crash", false);
pref("gfx.webrender.texture-cache.small", true);
pref("layout.css.report_errors", false);
pref("network.http.max-connections", 32);
pref("network.http.max-persistent-connections-per-server", 4);
pref("network.http.http3.enable", false);
pref("dom.max_script_run_time", 20);

// ---- Fonts ------------------------------------------------------------------
// One process: no font list in shared memory.
pref("gfx.e10s.font-list.shared", false);
// CJK: the fonts iOS 6 ships (no PingFang, Songti or Hiragino Sans there).
pref("font.name-list.serif.zh-CN", "Heiti SC, STHeiti");
pref("font.name-list.sans-serif.zh-CN", "Heiti SC, STHeiti");
pref("font.name-list.monospace.zh-CN", "Heiti SC, STHeiti");
pref("font.name-list.serif.zh-TW", "Heiti TC, STHeiti");
pref("font.name-list.sans-serif.zh-TW", "Heiti TC, STHeiti");
pref("font.name-list.monospace.zh-TW", "Heiti TC, STHeiti");
pref("font.name-list.serif.zh-HK", "Heiti TC, STHeiti");
pref("font.name-list.sans-serif.zh-HK", "Heiti TC, STHeiti");
pref("font.name-list.monospace.zh-HK", "Heiti TC, STHeiti");
pref("font.name-list.serif.ja", "Hiragino Mincho ProN, Hiragino Kaku Gothic ProN, Heiti J");
pref("font.name-list.sans-serif.ja", "Hiragino Kaku Gothic ProN, Heiti J");
pref("font.name-list.monospace.ja", "Hiragino Kaku Gothic ProN, Heiti J");
pref("font.name-list.serif.ko", "Apple SD Gothic Neo, AppleGothic, Heiti K");
pref("font.name-list.sans-serif.ko", "Apple SD Gothic Neo, AppleGothic, Heiti K");
pref("font.name-list.monospace.ko", "Apple SD Gothic Neo, AppleGothic, Heiti K");

// ---- Graphics: software WebRender (SGX is OpenGL ES 2.0 only) --------------
pref("gfx.webrender.software", true);
pref("gfx.canvas.accelerated", false);
// Render targets and their depth buffers of 1024 x 1024 (4 MB) instead of
// 2048 x 2048 (16 MB) each.
pref("gfx.webrender.max-shared-surface-size", 1024);

// ---- JIT --------------------------------------------------------------------
// Gecko turns the JIT off in the parent process on iOS (no executable memory
// for apps there); LegacyFox is one process and has dynamic-codesigning.
pref("javascript.options.main_process_disable_jit", false);
// Baseline everywhere, Ion only for really hot code.
pref("javascript.options.baselinejit", true);
pref("javascript.options.ion", true);
pref("javascript.options.ion.threshold", 3000);

// ---- Video: H.264 for the hardware decoder ---------------------------------
pref("media.av1.enabled", false);
pref("media.webm.enabled", false);

// ---- Off: nothing to spend memory or traffic on ----------------------------
pref("dom.gamepad.enabled", false);
pref("browser.ml.enable", false);
pref("browser.ml.chat.enabled", false);
pref("browser.ml.linkPreview.enabled", false);
pref("browser.safebrowsing.malware.enabled", false);
pref("browser.safebrowsing.phishing.enabled", false);
pref("browser.safebrowsing.downloads.enabled", false);
pref("browser.safebrowsing.provider.google4.updateURL", "");
pref("browser.safebrowsing.provider.google4.gethashURL", "");
pref("browser.safebrowsing.provider.mozilla.updateURL", "");
pref("browser.safebrowsing.provider.mozilla.gethashURL", "");
pref("app.normandy.enabled", false);
pref("app.normandy.api_url", "");
pref("app.shield.optoutstudies.enabled", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.archive.enabled", false);
pref("security.remote_settings.crlite_filters.enabled", false);
pref("app.update.enabled", false);

// ---- Touch ------------------------------------------------------------------
pref("dom.w3c_touch_events.enabled", 1);
pref("dom.meta-viewport.enabled", true);
pref("apz.allow_zooming", true);
pref("apz.allow_double_tap_zooming", true);
pref("ui.touch.radius.enabled", true);
// Long press on a link or an image: the shell's menu (GeckoView:ContextMenu).
pref("ui.click_hold_context_menus", true);
pref("ui.click_hold_context_menus.delay", 500);

// ---- Mozilla account, Sync, passwords stay on -------------------------------
pref("identity.fxaccounts.enabled", true);
// The Mozilla account servers, as desktop Firefox sets them
// (browser/app/profile/firefox.js); sign-in is the OAuth WebChannel flow.
pref("identity.fxaccounts.remote.root", "https://accounts.firefox.com/");
pref("identity.fxaccounts.contextParam", "oauth_webchannel_v1");
pref("identity.fxaccounts.remote.profile.uri", "https://profile.accounts.firefox.com/v1");
pref("identity.fxaccounts.remote.oauth.uri", "https://oauth.accounts.firefox.com/v1");
pref("identity.fxaccounts.pairing.enabled", false);
pref("identity.sync.tokenserver.uri", "https://token.services.mozilla.com/1.0/sync/1.5");
pref("identity.fxaccounts.autoconfig.uri", "");
pref("identity.fxaccounts.telemetry.clientAssociationPing.enabled", false);
// Sync what LegacyFox has: bookmarks and history (Places), passwords and
// form history. Desktop tabs, add-ons, prefs and autofill stay out.
pref("services.sync.engine.bookmarks", true);
pref("services.sync.engine.history", true);
pref("services.sync.engine.passwords", true);
pref("services.sync.engine.forms", true);
pref("services.sync.engine.tabs", false);
pref("services.sync.engine.addons", false);
pref("services.sync.engine.prefs", false);
pref("services.sync.engine.addresses", false);
pref("services.sync.engine.creditcards", false);
// Only these engines exist here at all: the tabs engine wants desktop
// browser windows.
pref("services.sync.registerEngines", "Bookmarks,History,Password,Form");
pref("signon.rememberSignons", true);
pref("signon.autofillForms", true);

// ---- Downloads --------------------------------------------------------------
// Straight into the shared Downloads folder (other apps and iFile find files
// there), without asking: the shell lists them under Menu > Downloads.
pref("browser.download.useDownloadDir", true);
pref("browser.download.folderList", 2);
pref("browser.download.dir", "/var/mobile/Media/Downloads");
pref("browser.download.always_ask_before_handling_new_types", false);
pref("browser.download.start_downloads_in_tmp_dir", false);
pref("browser.download.open_pdf_attachments_inline", true);

// ---- Language -----------------------------------------------------------------
// Sites in Russian first (the engine's own locale is English).
pref("intl.accept_languages", "ru-RU, ru, en-US, en");

// ---- Developer tools stay off --------------------------------------------------
// Builds that are not Mozilla's official ones turn remote debugging on, which
// loads the DevTools server and all its actors at startup.
pref("devtools.debugger.remote-enabled", false);
pref("devtools.chrome.enabled", false);
