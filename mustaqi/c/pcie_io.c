// Fast copies to / from the card's BAR0 (mapped uncached from /sys/bus/pci/devices/.../resource0), for
// mustaqi/pcie_link.py.  gcc -O2 -mavx2 -mmovdir64b -shared -fPIC -o pcie_io.so pcie_io.c
//   reads:  32-byte AVX2 loads -> one 8-DW PCIe read request each (4-byte loads for an unaligned head / tail)
//   writes: MOVDIR64B -> one 64-byte (16-DW) PCIe write each (4-byte stores for an unaligned head / tail),
//           then SFENCE so the writes are on their way before any later store (e.g. an engine start command).
// Python's own copies are much worse on an uncached mapping: memcpy uses `rep movsb`, i.e. one byte per packet.
#include <immintrin.h>
#include <stddef.h>
#include <stdint.h>

void bar_read(void *dst, const void *src, size_t n) {          // n: multiple of 4, src 4-byte aligned
    const char *s = (const char *)src;
    char *d = (char *)dst;
    while (n >= 4 && ((uintptr_t)s & 31)) {
        *(uint32_t *)d = *(const volatile uint32_t *)s; s += 4; d += 4; n -= 4;
    }
    while (n >= 32) {
        __m256i v = _mm256_load_si256((const __m256i *)s);
        _mm256_storeu_si256((__m256i *)d, v);
        s += 32; d += 32; n -= 32;
    }
    while (n >= 4) {
        *(uint32_t *)d = *(const volatile uint32_t *)s; s += 4; d += 4; n -= 4;
    }
}

void bar_write(void *dst, const void *src, size_t n) {         // n: multiple of 4, dst 4-byte aligned
    char *d = (char *)dst;
    const char *s = (const char *)src;
    while (n >= 4 && ((uintptr_t)d & 63)) {
        *(volatile uint32_t *)d = *(const uint32_t *)s; s += 4; d += 4; n -= 4;
    }
    while (n >= 64) {
        _movdir64b(d, s);
        s += 64; d += 64; n -= 64;
    }
    while (n >= 4) {
        *(volatile uint32_t *)d = *(const uint32_t *)s; s += 4; d += 4; n -= 4;
    }
    _mm_sfence();
}

void bar_write32(void *dst, const void *src, size_t n) {       // 4-byte stores only (registers)
    volatile uint32_t *d = (volatile uint32_t *)dst;
    const uint32_t *s = (const uint32_t *)src;
    for (size_t i = 0; i < n / 4; i++) d[i] = s[i];
    _mm_sfence();
}

void bar_write32_pair(void *d0, uint32_t v0, void *d1, uint32_t v1) {   // two register stores back to back
    *(volatile uint32_t *)d0 = v0;          // (engine starts for the FFN unit: no interrupt window in between
    *(volatile uint32_t *)d1 = v1;          // worth speaking of, see pcie_link.start_pair)
    _mm_sfence();
}

uint32_t bar_read32(const void *src) {
    return *(const volatile uint32_t *)src;
}
