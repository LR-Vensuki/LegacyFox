# C++ для armv7 iOS 4–7

`../build-libcxx.sh` собирает статические libc++ и libc++abi из LLVM 21 в
`~/.cache/legacyfox/libcxx-armv7`.

Как компилировать (так же будет собираться Gecko):

- компилятор — системный clang 21, линкер — ld64 из Theos (`--ld-path`);
- код компилируется с `-target armv7-apple-ios9.0 -femulated-tls`: clang
  разрешает `thread_local` на 32-битном ARM только начиная с iOS 9, а
  `-femulated-tls` превращает его в вызовы `__emutls_get_address`, которые
  работают на любой iOS;
- линкуется с `-target armv7-apple-ios4.0`, так что бинарник запускается с
  iOS 4, а `__emutls_get_address` берётся из `libclang_rt.ios.a` Theos;
- `-include compat/legacyfox_compat.h` и `liblegacyfox_compat.a`.

Линковка против iPhoneOS6.1.sdk ловит всё, чего нет в iOS 6.1. Что есть в
6.1, но нет в 4.x (например, функции `*_l` из xlocale и SjLj-раскрутка), можно
проверить только на устройстве.

`hello.cpp` — потоки, мьютексы, condition_variable, thread_local, исключения,
std::format, filesystem, variant/optional/span.
