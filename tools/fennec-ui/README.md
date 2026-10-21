# The interface of Firefox for Android, 2012

LegacyFox draws its interface with the images of Firefox 17 for Android
(November 2012), the last Firefox of 2012, taken unchanged from Mozilla's
sources, plus a few from Firefox 20 (private browsing, the new-tab menu
icons). The app icon and the about:home header carry the Firefox logo of
2004 (Wikimedia Commons, MPL/GPL/LGPL). Layouts, sizes and colors follow the same sources
(`mobile/android/base/resources/layout*`, `values*`) and the classes that
drew them (`BrowserToolbar.java`, `TabsPanel.java`, `AwesomeBar.java`, ...).

There was no Firefox for iOS in 2012, so the iPad gets the tablet interface
(`layout-xlarge-v11`) and the iPhone the phone one, with the tablets' round
back button added: iPhones have no back key.

- `fetch.sh` makes sparse checkouts of mozilla-central (gecko-dev on GitHub)
  at RELEASE_BASE_20121114 (17.0) and RELEASE_BASE_20130326 (20.0), and
  downloads two Material icons (Google, Apache 2.0) for Android's check
  boxes and the Firefox logo.
- `import.py` copies the images into `shell/Resources/Fennec/` as
  `fx_<name>~ipad.png`, `fx_<name>@2x~ipad.png`, `fx_<name>~iphone.png`,
  `fx_<name>@2x~iphone.png`, strips nine-patch borders into
  `ninepatch.plist`, and makes the app icons from the logo.

The Firefox resources are under the Mozilla Public License 2.0
(https://mozilla.org/MPL/2.0/); their source is the Mozilla repository at
the revisions above. "Firefox" and its logo are trademarks of Mozilla, whose
trademark policy reserves them for Mozilla's own builds; check it before
LegacyFox is distributed with the logo.
