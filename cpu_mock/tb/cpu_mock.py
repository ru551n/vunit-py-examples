"""The CPU mock's Python side: the firmware runs in a thread and each register access it makes is
handed to VHDL by step(), which does it as an AXI-Lite transaction. The firmware thread waits for
the answer, so it only runs between steps.

The firmware runs either natively, built for the PC with hal_sim.c, or as an RV32 binary in the
Unicorn emulator, where loads and stores to the bus window become the register accesses."""

import ctypes
import os
import queue
import shutil
import subprocess
import threading
from pathlib import Path

OP_READ, OP_WRITE, OP_DONE = 1, 2, 3  # == cpu_mock.vhd
# Host seconds without a register access before the firmware counts as hung
REQUEST_TIMEOUT_S = 30

READ_FN = ctypes.CFUNCTYPE(ctypes.c_uint32, ctypes.c_uint32)
WRITE_FN = ctypes.CFUNCTYPE(None, ctypes.c_uint32, ctypes.c_uint32)
PUTS_FN = ctypes.CFUNCTYPE(None, ctypes.c_char_p)

# The RV32 memory map: RAM (== firmware/rv32/link.ld), the bus window that reaches the simulation,
# and the console (== firmware/rv32/hal_rv32.c) and exit (== start.S) registers of the emulator
RAM_BASE, RAM_SIZE = 0x0000_0000, 0x1_0000
BUS_BASE, BUS_SIZE = 0xF000_0000, 0x1000
EMULATOR_BASE = 0xFFFF_0000
CONSOLE, EXIT = 0x0, 0x4
RISCV_GCCS = ("riscv-none-elf-gcc", "riscv64-unknown-elf-gcc", "riscv32-unknown-elf-gcc")


def _run(cmd, what):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        raise RuntimeError(f"{what}: '{cmd[0]}' not found") from None
    if result.returncode:
        raise RuntimeError(f"{what} failed:\n{' '.join(cmd)}\n{result.stderr}")


def build_native(firmware_dir, build_dir):
    """firmware_sim.so from the firmware's C files and hal_sim.c, with cc or CC."""
    sources = sorted(str(p) for p in Path(firmware_dir).glob("*.c"))
    out = Path(build_dir) / "firmware_sim.so"
    out.parent.mkdir(parents=True, exist_ok=True)
    cc = os.environ.get("CC", "cc")
    _run([cc, "-shared", "-fPIC", "-O2", "-Wall", *sources, "-o", str(out)], "building the firmware with CC")
    return out


def build_rv32(firmware_dir, build_dir):
    """firmware.bin, a RAM image for RV32IM, with RISCV_GCC or the first RISC-V GCC on PATH."""
    gcc = os.environ.get("RISCV_GCC") or next(filter(shutil.which, RISCV_GCCS), None)
    if gcc is None:
        raise RuntimeError(f"no RISC-V GCC ({', '.join(RISCV_GCCS)}) on PATH: install one or set RISCV_GCC")
    fw, out = Path(firmware_dir), Path(build_dir) / "firmware.bin"
    out.parent.mkdir(parents=True, exist_ok=True)
    rv32 = fw / "rv32"
    cmd = [gcc, "-march=rv32im", "-mabi=ilp32", "-O2", "-Wall", "-ffreestanding", "-nostdlib", "-Wl,--no-relax"]
    cmd += ["-T", str(rv32 / "link.ld"), "-I", str(fw), str(rv32 / "start.S"), str(rv32 / "hal_rv32.c")]
    cmd += [str(fw / "firmware.c"), "-lgcc", "-o", str(out.with_suffix(".elf"))]
    _run(cmd, "building the RV32 firmware")
    objcopy = gcc.removesuffix("gcc") + "objcopy"
    _run([objcopy, "-O", "binary", str(out.with_suffix(".elf")), str(out)], "making the RV32 RAM image")
    return out


def _signed(value):
    value &= 0xFFFF_FFFF
    return value - (1 << 32) if value >= 1 << 31 else value


class CpuMock:
    def __init__(self, firmware_dir, build_dir, cpu="native"):
        self._requests = queue.Queue(maxsize=1)
        self._responses = queue.Queue(maxsize=1)
        if cpu == "native":
            self._main = self._native(build_native(firmware_dir, build_dir))
        elif cpu == "rv32":
            self._main = self._rv32(build_rv32(firmware_dir, build_dir))
        else:
            raise ValueError(f"unknown CPU '{cpu}', expected 'native' or 'rv32'")
        self._thread = threading.Thread(target=self._run, name="firmware", daemon=True)

    def _native(self, library):
        lib = ctypes.CDLL(str(library))
        # Kept referenced: the firmware calls them for as long as it runs
        self._callbacks = (READ_FN(self._read), WRITE_FN(self._write), PUTS_FN(self._puts))
        lib.hal_sim_set_callbacks(*self._callbacks)
        return lib.fw_main

    def _rv32(self, image):
        from unicorn import UC_ARCH_RISCV, UC_MODE_RISCV32, Uc, UcError
        from unicorn.riscv_const import UC_RISCV_REG_PC

        uc = Uc(UC_ARCH_RISCV, UC_MODE_RISCV32)
        uc.mem_map(RAM_BASE, RAM_SIZE)
        uc.mem_write(RAM_BASE, image.read_bytes())
        uc.mmio_map(
            BUS_BASE,
            BUS_SIZE,
            lambda uc, offset, size, data: self._read(BUS_BASE + offset),
            None,
            lambda uc, offset, size, value, data: self._write(BUS_BASE + offset, value),
            None,
        )
        console = bytearray()
        status = []

        def emulator_write(uc, offset, size, value, data):
            if offset == EXIT:
                status.append(_signed(value))
                uc.emu_stop()
            elif value == ord("\n"):
                self._puts(bytes(console))
                console.clear()
            else:
                console.append(value & 0xFF)

        uc.mmio_map(EMULATOR_BASE, 0x1000, lambda *args: 0, None, emulator_write, None)

        def main():
            try:
                uc.emu_start(RAM_BASE, RAM_BASE + RAM_SIZE)
            except UcError as error:
                raise RuntimeError(f"{error} at pc 0x{uc.reg_read(UC_RISCV_REG_PC):08x}") from None
            if not status:
                raise RuntimeError(f"the CPU stopped at pc 0x{uc.reg_read(UC_RISCV_REG_PC):08x} without exiting")
            return status[0]

        return main

    def _ask(self, op, addr=0, data=0):
        self._requests.put((op, addr, data))
        return self._responses.get()

    def _read(self, addr):
        return self._ask(OP_READ, addr) & 0xFFFF_FFFF

    def _write(self, addr, value):
        self._ask(OP_WRITE, addr, value)

    def _puts(self, s):
        print("firmware:", s.decode(errors="replace"), flush=True)

    def _run(self):
        try:
            self._requests.put((OP_DONE, self._main(), None))
        except Exception as error:  # pylint: disable=broad-exception-caught
            self._requests.put((OP_DONE, None, error))

    def step(self, value):
        """Answer the previous request with value; return the next one as [op, address, data]."""
        if self._thread.is_alive():
            self._responses.put(value)
        else:
            self._thread.start()
        try:
            op, addr, data = self._requests.get(timeout=REQUEST_TIMEOUT_S)
        except queue.Empty:
            raise RuntimeError(f"the firmware made no register access for {REQUEST_TIMEOUT_S} s") from None
        if op == OP_DONE:
            if data is not None:
                raise RuntimeError(f"the firmware crashed: {data}")
            if addr != 0:
                raise RuntimeError(f"the firmware returned {addr}")
            return [op, 0, 0]
        return [op, _signed(addr), _signed(data)]
