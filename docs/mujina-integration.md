# Mujina Integration Notes

Mujina is a Rust Cargo workspace centered around `mujina-minerd`. Its README describes a CPU backend for exercising the mining pipeline and hardware-specific support for mining devices.

The Tang Nano integration should follow the same shape: a hardware backend that receives jobs from Mujina's mining pipeline and translates them into `TNJ` UART packets.

## Proposed Backend Boundary

The backend needs four pieces:

- serial port discovery/configuration for the Tang Nano USB-UART
- job conversion from Mujina work into `midstate`, `tail`, and `target`
- response parsing for `F || nonce || hash`
- share validation/submission through the existing Mujina pipeline

## Endian Contract

Keep the FPGA simple:

- FPGA consumes SHA-256 big-endian words.
- FPGA returns the SHA digest in normal SHA byte order.
- FPGA compares `reverse_bytes(hash) <= target`, because Bitcoin proof-of-work
  interprets the 32 digest bytes as a little-endian integer.
- Mujina owns Bitcoin wire-format conversion, compact target expansion, and pool share formatting.

The current bitstream always starts at nonce zero and scans `current_nonce` as a big-endian SHA word.
Mujina therefore treats the returned nonce bytes as header wire order and
converts them into Rust's `BlockHeader::nonce` little-endian `u32` before
host-side validation and share submission.

## First Driver Milestone

The fastest useful milestone is a non-pooled dummy-work path:

1. Generate or receive a synthetic block header.
2. Set a very easy target.
3. Send one `TNJ` packet.
4. Confirm the FPGA returns an `F` response.
5. Check the returned nonce against Mujina's CPU hashing path.

Once that is stable, pool work can use the same packet path.

## Mujina Driver Smoke Test

The Mujina branch in `/Users/skot/Bitcoin/mujina/mujina-skot` now has a
`fpga_miner` backend. To exercise the full scheduler path with dummy work:

```bash
cd /Users/skot/Bitcoin/mujina/mujina-skot
MUJINA_TANG_NANO_PORT=/dev/cu.usbserial-1101 \
MUJINA_USB_DISABLE=1 \
RUST_LOG=mujina_miner=debug \
cargo run -p mujina-miner --bin mujina-minerd
```

Expected proof that work reached the FPGA and came back through Mujina:

```text
fpga_miner::thread: sending Tang Nano work
scheduler: Share found
```

For Stratum work, add the usual Mujina pool variables, for example
`MUJINA_POOL_URL`, `MUJINA_POOL_USER`, and optionally `MUJINA_POOL_FORCED_RATE`
while this tiny FPGA core is still very slow.
