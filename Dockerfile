FROM debian:forky-slim AS simulator
RUN apt-get update && apt-get install -y --no-install-recommends verilator

FROM python:3.14-slim

ENV DEBIAN_FRONTEND=noninteractive

# Trixie's Verilator 5.032 crashes on the GC's indexed writes. The RISC-V
# compiler and picolibc build the I/O core's firmware (iocore/sw/TOOLCHAIN.md),
# which every image with board I/O carries.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ccache git make perl gcc-riscv64-unknown-elf picolibc-riscv64-unknown-elf \
 && rm -rf /var/lib/apt/lists/*

COPY --from=simulator /usr/bin/verilator /usr/bin/verilator_bin /usr/bin/
COPY --from=simulator /usr/share/verilator /usr/share/verilator
RUN verilator --version

WORKDIR /work

CMD ["make", "test"]
