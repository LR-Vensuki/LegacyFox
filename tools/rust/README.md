# Rust для armv7 iOS 4–7

`armv7-apple-ios` убрали из rustc; есть только `armv7s-apple-ios` (A6). Свой
таргет `armv7-apple-ios-legacy.json` — его копия под Cortex-A8 (A4) и VFPv3,
без нативных thread-local (dyld умеет их только с iOS 8–9).

std собирается из исходников (`-Z build-std`), как в gecko-w10m. rustc не
умеет линковать под `armv7` на Apple (паника `unsupported architecture`),
поэтому Rust собирается только как staticlib, а линкует clang из Theos — так
же Gecko и линкует `gkrust`.

Чего std не находит на iOS 4–7, даёт `compat/` (`clock_gettime`,
`CCRandomGenerateBytes`).

Проверка: `hello/` — std, потоки, мьютексы, thread_local, время и передача
float/u64/структур из C в Rust (`main.c` сверяет сумму).

```bash
cd hello
IPHONEOS_DEPLOYMENT_TARGET=4.0 RUSTC_BOOTSTRAP=1 cargo +nightly build --release \
  -Z build-std=std,panic_abort -Z json-target-spec --target ../armv7-apple-ios-legacy.json
../linker.sh -arch armv7 main.c target/armv7-apple-ios-legacy/release/libhello.a \
  ../../../compat/build/liblegacyfox_compat.a -o hello-armv7 -Wl,-w
```

## Для сборки Firefox

`install-target.sh` кладёт таргет и собранный под него std прямо в sysroot
nightly-тулчейна. Тогда rustc находит `armv7-apple-ios-legacy` по имени, как
встроенный таргет. `-Z build-std` внутри сборки Firefox не работает: зависимости
std начинают искаться среди вендоренных крейтов Firefox и не совпадают по
версиям. Скрипт надо перезапускать после каждого `rustup update`.
