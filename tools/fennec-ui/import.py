#!/usr/bin/env python3
"""Bring the interface of Firefox 17 for Android (November 2012) into the shell.

LegacyFox draws its toolbar, tabs, menu and lists with the images Firefox
for Android shipped in 2012, taken unchanged from Mozilla's sources
(mobile/android/base/resources, MPL 2.0) and from its "unofficial" branding.

    tools/fennec-ui/import.py FIREFOX17 FIREFOX20 MATERIAL LOGO FIREFOXHOME

FIREFOX17: a checkout of mozilla-central at RELEASE_BASE_20121114 (Firefox
17.0) holding mobile/android; FIREFOX20: RELEASE_BASE_20130326 (Firefox
20.0), for what came a few months later in the same style (private
browsing, the menu icons for new tabs); MATERIAL: Google's Material icons
(Apache 2.0) for the few controls Firefox took from Android itself, such as
the check boxes of its settings; LOGO: the Firefox logo of 2004 (Mozilla,
MPL/GPL/LGPL, a Mozilla trademark) as Wikimedia renders it, for the app
icon and about:home; FIREFOXHOME: Mozilla's own iOS app of 2010-2012,
Firefox Home (github.com/mozilla-services/ios-sync-client, MPL 1.1), whose
blue bars and toolbar icons give the iOS 6 look: fh_<name>.png.
tools/fennec-ui/fetch.sh makes them.

Android picks an image by screen class and density; iOS by idiom and scale:
  iPad   1x  <- xlarge/large tablet, mdpi     name~ipad.png
  iPad   2x  <- xlarge/large tablet, xhdpi    name@2x~ipad.png
  iPhone 2x  <- phone, xhdpi                  name@2x~iphone.png
  iPhone 1x  <- phone, mdpi                   name~iphone.png
Nine-patches lose their 1 px marker border; the stretch and content insets
go to shell/Resources/Fennec/ninepatch.plist (points, per idiom).
"""
import os, plistlib, shutil, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "shell", "Resources", "Fennec")

ORDER = {
    "ipad":     (1, ["drawable-xlarge-mdpi-v11", "drawable-large-mdpi-v11", "drawable-mdpi-v11", "drawable", "drawable-nodpi"]),
    "ipad@2x":  (2, ["drawable-xlarge-xhdpi-v11", "drawable-large-xhdpi-v11", "drawable-xhdpi-v11", "drawable-xhdpi", "drawable-nodpi"]),
    # Phones had a hardware back key: the iPhone borrows the tablets' round
    # back button.
    "iphone":   (1, ["drawable-mdpi-v11", "drawable", "drawable-nodpi", "drawable-large-mdpi-v11"]),
    "iphone@2x": (2, ["drawable-xhdpi-v11", "drawable-xhdpi", "drawable-nodpi", "drawable-large-xhdpi-v11"]),
}

NAMES = """
address_bar_texture_tablet address_bar_texture_port address_bar_bg_curve address_bar_bg_shadow
address_bar_back_button_bg address_bar_back_button_pressed_bg address_bar_url_default address_bar_url_pressed
ic_menu_back ic_menu_forward ic_menu_reload ic_menu_bookmark_add ic_menu_bookmark_remove ic_menu_share
ic_menu_find_in_page ic_menu_desktop_mode ic_menu_save_as_pdf
menu menu_normal menu_pressed tabs_crop_normal tabs_crop_pressed tabs_crop_expanded_normal tabs_crop_expanded_pressed
tabs_full_normal tabs_full_pressed tabs_carat tabs_carat_contracted tabs_carat_expanded
favicon site_security_identified site_security_verified urlbar_stop reader
progress_spinner_1 progress_spinner_2 progress_spinner_3 progress_spinner_4 progress_spinner_5 progress_spinner_6
progress_spinner_7 progress_spinner_8 progress_spinner_9 progress_spinner_10 progress_spinner_11 progress_spinner_12
ic_awesomebar_go ic_awesomebar_search ic_awesomebar_star ic_awesomebar_reader folder
menu_popup_bg menu_popup_arrow menu_panel_bg menu_item_texture menu_item_pressed_texture menu_item_check
tabs_tray_bg tabs_tray_selected_bg tab_new tab_new_normal tab_new_pressed tab_close
tab_thumbnail_default tab_thumbnail_shadow
awesomebar_tab_center awesomebar_tab_left awesomebar_tab_right abouthome_bg
abouthome_promo_box_bg abouthome_promo_box_pressed_bg abouthome_promo_logo_sync
find_close find_next find_prev alert_download
doorhanger_arrow doorhanger_bg doorhanger_popup_bg doorhanger_shadow_bg
validation_bg validation_arrow validation_arrow_inverted
""".split()

# From Firefox 20: private browsing (purple toolbar) and new-tab menu icons.
NAMES20 = """
address_bar_texture_tablet_pb address_bar_texture_port_pb address_bar_url_default_pb address_bar_url_pressed_pb
menu_pb tab_new_pb tabs_private abouthome_bg_pb ic_menu_new_tab ic_menu_new_private_tab ic_menu_downloads
ic_menu_settings ic_menu_quit ic_menu_close_all_tabs ic_menu_desktop_mode_off ic_menu_desktop_mode_on
""".split()


MATERIAL = ["check_box", "check_box_outline_blank"]


def find(res, dirs, name):
    for d in dirs:
        for ext in (".9.png", ".png"):
            p = os.path.join(res, d, name + ext)
            if os.path.exists(p):
                return p, d
    return None, None


def runs(seq):
    out, start = [], None
    for i, on in enumerate(seq + [False]):
        if on and start is None:
            start = i
        elif not on and start is not None:
            out.append((start, i))
            start = None
    return out


def ninepatch(path):
    """The image without its marker border, and (stretch, content) insets
    in pixels as (top, left, bottom, right)."""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    black = lambda p: p[3] > 128 and max(p[:3]) < 60
    top = runs([black(px[x, 0]) for x in range(1, w - 1)])
    left = runs([black(px[0, y]) for y in range(1, h - 1)])
    bottom = runs([black(px[x, h - 1]) for x in range(1, w - 1)])
    right = runs([black(px[w - 1, y]) for y in range(1, h - 1)])
    iw, ih = w - 2, h - 2
    stretch = (left[0][0], top[0][0], ih - left[-1][1], iw - top[-1][1])
    content = stretch
    if bottom and right:
        content = (right[0][0], bottom[0][0], ih - right[-1][1], iw - bottom[-1][1])
    return im.crop((1, 1, w - 1, h - 1)), stretch, content


def main():
    src17, src20, material, logo, fxhome = sys.argv[1:6]
    res = os.path.join(src17, "mobile/android/base/resources")
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    insets = {}
    for name, res in [(n, res) for n in NAMES] + [(n, os.path.join(src20, "mobile/android/base/resources")) for n in NAMES20]:
        found = False
        for variant, (scale, dirs) in ORDER.items():
            path, d = find(res, dirs, name)
            if not path:
                continue
            found = True
            idiom = variant.split("@")[0]
            suffix = ("@2x" if scale == 2 else "") + "~" + idiom
            dst = os.path.join(OUT, "fx_%s%s.png" % (name, suffix))
            if path.endswith(".9.png"):
                im, stretch, content = ninepatch(path)
                im.save(dst)
                # Points from the 1x image when there is one.
                entry = insets.setdefault(name, {})
                if idiom not in entry or scale == 1:
                    entry[idiom] = [v / scale for v in stretch]
                    entry[idiom + "Content"] = [v / scale for v in content]
            else:
                shutil.copyfile(path, dst)
        if not found:
            sys.exit("not in the sources: " + name)
    with open(os.path.join(OUT, "ninepatch.plist"), "wb") as f:
        plistlib.dump(insets, f)

    # Android's own widgets, from Material icons: md_<name>.png at 1x and 2x.
    for name in MATERIAL:
        for scale, suffix in (("1x", ""), ("2x", "@2x")):
            shutil.copyfile(os.path.join(material, "%s_%s.png" % (name, scale)),
                            os.path.join(OUT, "md_%s%s.png" % (name, suffix)))

    # Firefox Home for iOS: its images as they are (1x and @2x).
    images = os.path.join(fxhome, "Sources", "Images")
    for f in sorted(os.listdir(images)):
        if f.endswith(".png"):
            shutil.copyfile(os.path.join(images, f), os.path.join(OUT, "fh_" + f.replace("-", "_")))

    # The Firefox logo (2004) for the app icon and the about:home header.
    icon = Image.open(logo).convert("RGBA")
    icon = icon.crop(icon.getbbox())
    for size, suffix in ((72, ""), (144, "@2x")):
        w = size * icon.width // icon.height
        icon.resize((w, size), Image.LANCZOS).save(os.path.join(OUT, "fx_brand_logo%s.png" % suffix))
    make_launch_images(os.path.join(fxhome, "Sources", "Images", "Background@2x.png"))
    make_app_icons(icon, os.path.join(fxhome, "Sources", "Images", "Background@2x.png"))
    print(len(os.listdir(OUT)), "files in", OUT)


def make_launch_images(background_path):
    """Firefox Home's blue while LegacyFox starts; Default-568h@2x.png is
    also what tells iOS 6 the app fills the iPhone 5's taller screen."""
    bg = Image.open(background_path).convert("RGB")
    for name, size in (("Default.png", (320, 480)), ("Default@2x.png", (640, 960)),
                       ("Default-568h@2x.png", (640, 1136))):
        bg.resize(size, Image.LANCZOS).save(os.path.join(ROOT, "shell", "Resources", name))


def make_app_icons(icon, texture_path):
    """iOS draws its icons square: the logo goes on Firefox Home's blue (the
    middle of its background); depiction/icon.png gets Cydia's rounded corners."""
    texture = Image.open(texture_path).convert("RGBA")
    side = min(texture.size)
    left, top = (texture.width - side) // 2, (texture.height - side) // 2
    big = texture.crop((left, top, left + side, top + side)).resize((144, 144), Image.LANCZOS)
    w = 128 * icon.width // icon.height
    fox = icon.resize((w, 128), Image.LANCZOS)
    big.alpha_composite(fox, ((144 - w) // 2, 8))
    big = big.convert("RGB")
    sizes = {"Icon.png": 57, "Icon@2x.png": 114, "Icon-72.png": 72, "Icon-72@2x.png": 144,
             "Icon-Small.png": 29, "Icon-Small@2x.png": 58, "Icon-Small-50.png": 50, "Icon-Small-50@2x.png": 100}
    for name, size in sizes.items():
        big.resize((size, size), Image.LANCZOS).save(os.path.join(ROOT, "shell", "Resources", name))
    from PIL import ImageDraw
    mask = Image.new("L", (144 * 4, 144 * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 144 * 4 - 1, 144 * 4 - 1), radius=int(144 * 4 * 0.175), fill=255)
    rounded = big.convert("RGBA")
    rounded.putalpha(mask.resize((144, 144), Image.LANCZOS))
    rounded.save(os.path.join(ROOT, "depiction", "icon.png"))


if __name__ == "__main__":
    main()
