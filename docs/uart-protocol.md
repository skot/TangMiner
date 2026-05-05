# UART Protocol

The FPGA side intentionally uses a tiny binary protocol so Mujina can treat the Tang Nano board like a simple hash engine.

UART settings:

- `115200`
- `8N1`
- no flow control

All multi-byte fields are sent big-endian.

## Start Job

Host to FPGA:

```text
"T" "N" "J"
midstate[32]
tail[12]
target[32]
```

Total length: `79` bytes.

Fields:

- `midstate`: SHA-256 internal state after the first 64 bytes of the Bitcoin block header.
- `tail`: bytes 64 through 75 of the 80-byte block header, excluding the nonce. These are interpreted as three big-endian SHA-256 message words.
- `target`: 256-bit big-endian integer target. The FPGA compares `reverse_bytes(hash) <= target`, matching Bitcoin's little-endian proof-of-work integer.

The FPGA constructs the final first-pass SHA-256 block as:

```text
tail[0:12] || nonce || 0x80 || zero padding || 0x00000280
```

It always starts at nonce zero, increments internally, then performs the second SHA-256 pass over the 32-byte first digest.

## Stop Job

Host to FPGA:

```text
"T" "N" "S"
```

## Found Response

FPGA to host:

```text
"F"
nonce[4]
hash[32]
```

Total length: `37` bytes.

The hash is returned in normal SHA digest byte order. The nonce is returned in the four wire-order bytes used in the hashed Bitcoin header.

## Mujina Integration Sketch

A Mujina driver can sit at the same layer as an ASIC hashboard driver:

1. Convert pool work into a block header and target.
2. Precompute SHA-256 midstate for bytes `0..63` of the header.
3. Send `TNJ` job packets with unique work, such as distinct extranonce2/merkle roots.
4. Listen for `F` responses.
5. Reconstruct and submit shares after converting hash/nonce endian forms expected by the pool stack.

This first protocol does not include temperature, clock control, nonce range completion, or multi-core enumeration. Those can be added as separate command bytes once the single-core path is verified.

For standalone testing, `scripts/make_job.py` emits this packet format from an 80-byte header and a big-endian target.
