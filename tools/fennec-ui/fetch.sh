#!/bin/sh
# Sparse checkouts of the Firefox for Android sources tools/fennec-ui/import.py
# reads: Firefox 17.0 (the interface) and 20.0 (private browsing), Material
# check boxes, and the Firefox logo of 2004.
set -e
DIR=${1:-$HOME/.cache/legacyfox/fennec}
mkdir -p "$DIR"
fetch() {
    [ -d "$DIR/$1" ] && return
    git clone -q --filter=blob:none --no-checkout --depth 1 --branch "$2" https://github.com/mozilla/gecko-dev "$DIR/$1"
    git -C "$DIR/$1" sparse-checkout set --no-cone /config/milestone.txt $3
    git -C "$DIR/$1" checkout -q
}
fetch gd17 RELEASE_BASE_20121114 "/mobile/android/base/resources /mobile/android/branding/unofficial /mobile/android/base/*.java"
fetch gd20 RELEASE_BASE_20130326 "/mobile/android/base/resources"
mkdir -p "$DIR/material"
for n in check_box check_box_outline_blank; do
    for s in 1x 2x; do
        [ -f "$DIR/material/${n}_$s.png" ] || curl -sSfL -o "$DIR/material/${n}_$s.png" \
            "https://raw.githubusercontent.com/google/material-design-icons/master/png/toggle/$n/materialicons/24dp/$s/baseline_${n}_black_24dp.png"
    done
done
# Firefox Home, Mozilla's iOS app of 2010-2012.
[ -d "$DIR/fxhome" ] || git clone -q --depth 1 https://github.com/mozilla-services/ios-sync-client "$DIR/fxhome"
# The Firefox logo of 2004, as Wikimedia Commons renders its SVG.
[ -f "$DIR/firefox-2004.png" ] || curl -sSfL -A "Mozilla/5.0 LegacyFox-build" -o "$DIR/firefox-2004.png" \
    "https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Mozilla_Firefox_logo_2004.svg/960px-Mozilla_Firefox_logo_2004.svg.png"
echo "tools/fennec-ui/import.py $DIR/gd17 $DIR/gd20 $DIR/material $DIR/firefox-2004.png $DIR/fxhome"
