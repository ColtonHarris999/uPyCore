FROM python:3.14-slim

ENV DEBIAN_FRONTEND=noninteractive

# Verilator 5.032 (Debian trixie) builds the uPyCore hart. Ubuntu's 5.020
# rejects slices of function-call return values used in the RTL. The RISC-V
# compiler and picolibc build the I/O core's firmware (iocore/sw/TOOLCHAIN.md),
# which every image with board I/O carries.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git make verilator gcc-riscv64-unknown-elf picolibc-riscv64-unknown-elf \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["make", "test"]
