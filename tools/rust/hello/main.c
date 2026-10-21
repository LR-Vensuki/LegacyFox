#include <stdio.h>
#include <stdint.h>
struct rect { float x, y, w, h; };
void lf_rust_hello(void);
double lf_rust_abi(uint64_t a, struct rect r, double d, uint32_t b);
int main(void) {
    lf_rust_hello();
    struct rect r = { 1.5f, 2.5f, 3.5f, 4.5f };
    double sum = lf_rust_abi(10000000000ULL, r, 0.25, 7);
    printf("sum=%f (want 10000000019.250000)\n", sum);
    return sum == 10000000019.25 ? 0 : 1;
}
