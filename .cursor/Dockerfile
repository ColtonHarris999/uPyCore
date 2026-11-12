FROM debian:forky-slim AS simulator
RUN apt-get update && apt-get install -y --no-install-recommends verilator

FROM python:3.14-slim

ENV DEBIAN_FRONTEND=noninteractive

# Verilator comes from Debian forky, as in the repository's own Dockerfile:
# trixie's 5.032 crashes on the GC's indexed writes and does not build the
# SoC simulator. The RISC-V compiler and picolibc build the I/O core's
# firmware (iocore/sw/TOOLCHAIN.md), which every image with board I/O
# carries. The i686 toolchain is the unix oracle (make oracle / make
# oracle-mpz). tmux holds the timing runs and hardware areas that outlive
# one command.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential \
        ccache \
        make \
        perl \
        git \
        curl \
        ca-certificates \
        patch \
        tmux \
        gcc-riscv64-unknown-elf \
        binutils-riscv64-unknown-elf \
        picolibc-riscv64-unknown-elf \
        gcc-i686-linux-gnu \
        libc6-dev-i386-cross \
        libc6-i386 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=simulator /usr/bin/verilator /usr/bin/verilator_bin /usr/bin/
COPY --from=simulator /usr/share/verilator /usr/share/verilator
RUN verilator --version

# Yosys 0.70 with read_slang. This is the open timing flow's elaborator
# (upycore/tools/sta/run.py). There is no native yosys binary.
RUN pip install --no-cache-dir --root-user-action=ignore --disable-pip-version-check \
        'yowasp-yosys==0.70.0.0.post1259'

# sky130 typical-corner liberty, the file sta/run.py times against.
# OpenROAD-flow-scripts b5dceb3c08fd30c9a1c5c0587bc6a57e0392080a
# ("sky130 default fanout"). The hash is part of the timing baseline.
ARG SKY130_URL=https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/b5dceb3c08fd30c9a1c5c0587bc6a57e0392080a/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
ARG SKY130_SHA256=ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9
RUN mkdir -p /opt/sky130 \
 && curl -fsSL "$SKY130_URL" -o /opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib \
 && echo "${SKY130_SHA256}  /opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib" | sha256sum -c -

ENV YOSYS=yowasp-yosys \
    SKY130_LIB=/opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib
