#!/usr/bin/env python3
import argparse
import glob
import time

import serial

from make_job import compress, words_to_bytes, IV


GENESIS_HEADER = bytes.fromhex(
    "01000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a"
    "29ab5f49"
    "ffff001d"
    "1dac2b7c"
)


def make_packet(header, target, command=b"J"):
    midstate = words_to_bytes(compress(IV, header[:64]))
    tail = header[64:76]
    return b"TN" + command + midstate + tail + target


def try_port(port, packet, baud, timeout, response_len):
    with serial.Serial(port, baudrate=baud, timeout=timeout, write_timeout=timeout) as ser:
        time.sleep(0.1)
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        ser.write(packet)
        ser.flush()
        response = ser.read(response_len)
    return response


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("ports", nargs="*", help="serial ports to try")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument("--echo", action="store_true", help="ask FPGA to echo the parsed job instead of hashing")
    parser.add_argument("--hardcoded", action="store_true", help="ask FPGA to run its built-in genesis nonce-zero job")
    args = parser.parse_args()

    ports = args.ports or sorted(glob.glob("/dev/cu.usbserial-*"))
    expected_payload = make_packet(GENESIS_HEADER, b"\xff" * 32)[3:]
    if args.hardcoded:
        packet = b"TNH"
    else:
        packet = make_packet(GENESIS_HEADER, b"\xff" * 32, b"E" if args.echo else b"J")
    response_len = 77 if args.echo else 37

    print(f"packet_len={len(packet)}")
    for port in ports:
        try:
            response = try_port(port, packet, args.baud, args.timeout, response_len)
        except Exception as exc:
            print(f"{port}: ERROR {exc}")
            continue

        if len(response) != response_len:
            try:
                response = response + try_port(port, b"", args.baud, args.timeout, response_len - len(response))
            except Exception:
                pass

        print(f"{port}: read {len(response)} bytes {response.hex()}")
        if args.echo and len(response) == 77 and response[:1] == b"E":
            echoed = response[1:]
            print(f"{port}: ECHO {'OK' if echoed == expected_payload else 'MISMATCH'}")
            if echoed != expected_payload:
                for i, (got, exp) in enumerate(zip(echoed, expected_payload)):
                    if got != exp:
                        print(f"first mismatch payload[{i}] got=0x{got:02x} expected=0x{exp:02x}")
                        break
            return
        if not args.echo and len(response) == 37 and response[:1] == b"F":
            nonce = int.from_bytes(response[1:5], "big")
            digest = response[5:37].hex()
            print(f"{port}: FOUND nonce=0x{nonce:08x} hash={digest}")
            return

    raise SystemExit("no valid FPGA response")


if __name__ == "__main__":
    main()
