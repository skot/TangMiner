# TangMiner

TangMiner is an experimental Bitcoin miner for the [Sipeed Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html) and [Tang Nano 9K](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html) FPGA boards based on [Gowin](https://gowinsemi.com) Arora FPGAs.

FPGAs are generally more efficient Bitcoin miners than CPUs and GPUs, but are nowhere near the performance of even the oldest mining ASICs. Gowin Arora FPGAs are small by FPGA standards but were selected for this project for affordability and open source toolchain support. I don't wish the horror of proprietary vendor FPGA toolchains on anyone.

This is a learning and integration project, not an economically useful miner. The active gateware is authored in SpinalHDL/Scala, generates Verilog, and uses a compact iterative SHA-256 compressor driven over the Tang Nano USB-UART by host miner software such as [Mujina](https://github.com/256foundation/mujina).

## Status

Current working state:

- Tang Nano 20K is the default target and has been built, flashed to SPI flash, loaded to SRAM, and smoke-tested over USB-UART.
- Tang Nano 9K remains supported through the same SpinalHDL top level and board-specific constraints.
- The host protocol is documented below and implemented directly in the FPGA UART parser.
- Mujina integration is working through its (experimental, messy, unreleased) Tang Nano FPGA backend.
- The SpinalHDL bitstream includes the fixed target byte-order comparison used for host-side share validation.
- Legacy hand-written Verilog remains in the tree for comparison and Icarus-based simulation.

Still worth improving:

- SpinalHDL-native simulation coverage with known block-header vectors.
- Better hashrate accounting and long-run hardware statistics in the host integration.
- More cores or pipelining if the design graduates from bring-up into performance work.

## Toolchain

TangMiner uses the open Gowin FPGA flow. The easiest complete install is [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), which bundles the FPGA build tools used here.

Main tools:

- [Yosys](https://github.com/YosysHQ/yosys) for Verilog synthesis.
- [nextpnr](https://github.com/YosysHQ/nextpnr), specifically `nextpnr-himbaechel`, for Gowin place and route.
- [Project Apicula](https://github.com/YosysHQ/apicula), specifically `gowin_pack`, for Gowin bitstream packing.
- [openFPGALoader](https://github.com/trabucayre/openFPGALoader) for SRAM loading and flash programming.
- [SpinalHDL](https://github.com/SpinalHDL/SpinalHDL) for Scala-authored hardware generation.
- [sbt](https://github.com/sbt/sbt) for building and running the SpinalHDL generator.
- [OpenJDK](https://github.com/openjdk/jdk) for the JVM used by sbt and SpinalHDL.
- [Icarus Verilog](https://github.com/steveicarus/iverilog), provided by OSS CAD Suite as `iverilog` and `vvp`, for the legacy Verilog simulations.

## Installing The Complete Toolchain

On macOS, install Java and sbt with [Homebrew](https://github.com/Homebrew/brew):

```sh
brew install openjdk sbt
```

Install OSS CAD Suite from the official releases. Pick the asset that matches your machine; for Apple Silicon macOS:

```sh
cd "$HOME"
OSS_CAD_PLATFORM=darwin-arm64
export OSS_CAD_PLATFORM
OSS_CAD_URL="$(
  curl -fsSL https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest |
    python3 -c 'import json,sys,os
platform=os.environ["OSS_CAD_PLATFORM"]
assets=json.load(sys.stdin)["assets"]
print(next(a["browser_download_url"] for a in assets if platform in a["name"]))'
)"
curl -L -o oss-cad-suite.tgz "$OSS_CAD_URL"
tar -xzf oss-cad-suite.tgz
rm oss-cad-suite.tgz
```

For Linux, set `OSS_CAD_PLATFORM` to `linux-x64` or `linux-arm64`. For Windows, download the `windows-x64` installer from the release page.

Activate the FPGA tools in a shell:

```sh
source "$HOME/oss-cad-suite/environment"
```

The Makefile defaults to `OSS_CAD_SUITE=$HOME/oss-cad-suite` and `TARGET=tangnano20k`. Override either value when needed:

```sh
make build OSS_CAD_SUITE=/path/to/oss-cad-suite TARGET=tangnano9k
```

If your `openFPGALoader` comes from Homebrew or another package manager, you can override just that tool:

```sh
make flash OPENFPGALOADER=openFPGALoader
```

## Build

Build the default Tang Nano 20K SpinalHDL bitstream:

```sh
make build
```

This generates `build/spinal/top.v` from `src/main/scala/tangminer/TangMiner.scala`, synthesizes it, runs place and route, and writes a target-specific bitstream such as `build/tangminer_spinal_tangnano20k.fs`.

Build for the Tang Nano 9K:

```sh
make build TARGET=tangnano9k
```

Generate only the SpinalHDL Verilog:

```sh
make spinal-verilog
```

Build the legacy hand-written Verilog bitstream for comparison:

```sh
make build-verilog
```

## Load To SRAM

Load the SpinalHDL bitstream to SRAM:

```sh
make load
```

For the Tang Nano 20K, explicitly selecting the FTDI channel and a conservative JTAG clock can help if the onboard debugger was recently switched into UART mode:

```sh
make load OPENFPGALOADER='openFPGALoader --ftdi-channel 0 --freq 2000000'
```

## Flash

Flash the SpinalHDL bitstream:

```sh
make flash
```

For the Tang Nano 20K, this form is often the most reliable:

```sh
make flash OPENFPGALOADER='openFPGALoader --ftdi-channel 0 --freq 2000000'
```

Use `make load-verilog` or `make flash-verilog` only when testing the legacy Verilog design.

## Serial Smoke Test

The board communicates over USB-UART at `115200 8N1`. After loading the FPGA bitstream, put the Tang Nano 20K BL616 bridge into UART mode from its console if needed:

```text
choose uart
```

Then run the smoke tests:

```sh
python3 -m venv .venv
. .venv/bin/activate
pip install pyserial

python scripts/serial_smoke.py --echo --timeout 2 /dev/cu.usbserial-*
python scripts/serial_smoke.py --timeout 3 /dev/cu.usbserial-*
```

The echo test should report `ECHO OK`. The hash test uses an easy all-ones target and should return an `F` response with a nonce and hash.

## Host Serial Protocol

TangMiner exposes a tiny binary UART protocol so host miner software can treat the FPGA as a hash engine. The FPGA UART is fixed at `115200 8N1` with no flow control.

Every host command starts with the two sync bytes `TN`, followed by a one-byte command tag. Unknown command tags are ignored and reset the parser back to sync search.

### Start Job

Host to FPGA:

```text
"T" "N" "J"
midstate[32]
tail[12]
target[32]
```

Total length: `79` bytes.

Fields:

- `midstate`: SHA-256 internal state after bytes `0..63` of the 80-byte Bitcoin block header.
- `tail`: header bytes `64..75`, excluding the nonce. These 12 bytes become the final three SHA-256 message words before the nonce word.
- `target`: 32-byte big-endian proof-of-work target integer.

When a job is accepted, the FPGA starts scanning at nonce word `0x00000000` and increments internally. A new `TNJ` command replaces the current work and restarts scanning from zero.

The FPGA constructs the first-pass final block as:

```text
tail[12] || nonce_word[4] || 0x80 || zero padding || 0x00000280
```

It then performs the second SHA-256 pass over the 32-byte first digest. For target comparison, the FPGA byte-reverses the final SHA digest and compares it as a big-endian integer against `target`, matching Bitcoin proof-of-work semantics.

### Found Response

FPGA to host:

```text
"F"
nonce[4]
hash[32]
```

Total length: `37` bytes.

`nonce` is returned as the four bytes that were inserted into the hashed Bitcoin header. Host software should copy those bytes into header bytes `76..79` or parse them as a Bitcoin little-endian nonce field. `hash` is returned in normal SHA-256 digest byte order.

The host should still validate every returned nonce before submitting a share. Mujina does this by rebuilding the block header, double-hashing it on the host, and checking the resulting block hash against the share target.

### Echo Job

Host to FPGA:

```text
"T" "N" "E"
midstate[32]
tail[12]
target[32]
```

FPGA to host:

```text
"E"
midstate[32]
tail[12]
target[32]
```

Total response length: `77` bytes.

This command does not start hashing. It echoes the parsed payload and is useful for checking serial wiring, byte order, and parser alignment.

### Stop Job

Host to FPGA:

```text
"T" "N" "S"
```

This stops the current scan and returns the core to idle. There is no acknowledgement response.

### Hardcoded Test Job

Host to FPGA:

```text
"T" "N" "H"
```

This starts a built-in genesis-style easy-target test job. It exists for bring-up and smoke testing; miner host software should use `TNJ` for real work.

## Make A Test Job Packet

```sh
python3 scripts/make_job.py \
  --header <80-byte-header-hex> \
  --target <32-byte-big-endian-target-hex> \
  > job.bin
```

Send `job.bin` to the board over USB-UART. Mujina generates equivalent packets directly from pool work.

## Simulate

```sh
make sim
```

The current Icarus testbenches exercise the legacy hand-written Verilog. SpinalHDL simulation coverage is a next step.

## Hardware Notes

- Default board: Sipeed Tang Nano 20K
- 20K FPGA: `GW2AR-LV18QN88C8/I7`
- 20K family: `GW2A-18C`
- 9K FPGA: `GW1NR-LV9QN88PC6/I5`
- 9K family: `GW1N-9C`
- Clock: onboard `27 MHz`
- UART: `115200 8N1`

The LED, clock, and UART pins follow the board-specific constraints in `constr/`.
