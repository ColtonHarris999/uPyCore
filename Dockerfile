FROM debian:forky-slim AS simulator
RUN apt-get update && apt-get install -y --no-install-recommends verilator

FROM python:3.14-slim

ENV DEBIAN_FRONTEND=noninteractive

# Trixie's Verilator 5.032 crashes on the GC's indexed writes.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ccache git make perl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=simulator /usr/bin/verilator /usr/bin/verilator_bin /usr/bin/
COPY --from=simulator /usr/share/verilator /usr/share/verilator
RUN verilator --version

WORKDIR /work

CMD ["make", "test"]
