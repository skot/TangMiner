# Bring-Up Plan

1. Install OSS CAD Suite and put its `bin` directory on `PATH`.
2. Build the design with `make build`.
3. Fix any syntax or Gowin mapping issues found by Yosys.
4. Inspect resource utilization and timing from nextpnr.
5. Verify the UART pins against a known-good UART example if your board revision behaves differently.
6. Load the bitstream with `make load`.
7. Send a trivial high-target job and confirm an `F` response.
8. Add a simulation testbench with a known Bitcoin block header.
9. Add a Mujina-side serial driver.

The most important early check is endian correctness. The FPGA currently treats `midstate`, `tail`, `target`, and response `hash` as big-endian SHA-256 values. The host driver should own all Bitcoin wire-format conversion.
