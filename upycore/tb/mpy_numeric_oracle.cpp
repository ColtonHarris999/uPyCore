// Independent host IEEE-754 conversion oracle for the RTL pipeline tests.
#include <cstdint>
#include <cstring>
#include <cmath>
extern "C" unsigned int oracle_i2f(long long x) {
    const float f = static_cast<float>(x);
    uint32_t u;
    std::memcpy(&u, &f, sizeof u);
    return u;
}
extern "C" unsigned int oracle_narrow(unsigned long long u) {
    double d;
    std::memcpy(&d, &u, sizeof d);
    if (std::isnan(d)) return (u >> 63 ? 0xffc00000u : 0x7fc00000u);
    const float f = static_cast<float>(d);
    uint32_t v;
    std::memcpy(&v, &f, sizeof v);
    return v;
}

extern "C" unsigned int oracle_classify(unsigned long long u) {
    double d;
    std::memcpy(&d, &u, sizeof d);
    const bool integral = std::isfinite(d) && std::trunc(d) == d;
    const bool odd = integral && std::fmod(std::fabs(d), 2.0) == 1.0;
    return unsigned(integral) | (unsigned(odd) << 1);
}
