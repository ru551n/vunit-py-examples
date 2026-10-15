"""The CPU mock's Python side: the firmware, built for the PC, runs in a thread and each register
access it makes is handed to VHDL by step(), which does it as an AXI-Lite transaction. The
firmware thread waits for the answer, so it only runs between steps."""

import ctypes
import os
import queue
import subprocess
import threading
from pathlib import Path

OP_READ, OP_WRITE, OP_DONE = 1, 2, 3  # == cpu_mock.vhd
# Host seconds without a register access before the firmware counts as hung
REQUEST_TIMEOUT_S = 30

READ_FN = ctypes.CFUNCTYPE(ctypes.c_uint32, ctypes.c_uint32)
WRITE_FN = ctypes.CFUNCTYPE(None, ctypes.c_uint32, ctypes.c_uint32)
PUTS_FN = ctypes.CFUNCTYPE(None, ctypes.c_char_p)


def build(firmware_dir, build_dir):
    """firmware_sim.so from the firmware's C files."""
    sources = sorted(str(p) for p in Path(firmware_dir).glob("*.c"))
    out = Path(build_dir) / "firmware_sim.so"
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [os.environ.get("CC", "cc"), "-shared", "-fPIC", "-O2", "-Wall", *sources, "-o", str(out)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        raise RuntimeError(f"no C compiler '{cmd[0]}' to build the firmware: install one or set CC") from None
    if result.returncode:
        raise RuntimeError(f"building the firmware failed:\n{' '.join(cmd)}\n{result.stderr}")
    return out


def _signed(value):
    value &= 0xFFFF_FFFF
    return value - (1 << 32) if value >= 1 << 31 else value


class CpuMock:
    def __init__(self, firmware_dir, build_dir):
        self._lib = ctypes.CDLL(str(build(firmware_dir, build_dir)))
        self._requests = queue.Queue(maxsize=1)
        self._responses = queue.Queue(maxsize=1)
        # Kept referenced: the firmware calls them for as long as it runs
        self._callbacks = (READ_FN(self._read), WRITE_FN(self._write), PUTS_FN(self._puts))
        self._lib.hal_sim_set_callbacks(*self._callbacks)
        self._thread = threading.Thread(target=self._run, name="firmware", daemon=True)

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
        self._requests.put((OP_DONE, self._lib.fw_main(), 0))

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
        if op == OP_DONE and addr != 0:
            raise RuntimeError(f"the firmware returned {addr}")
        return [op, _signed(addr), _signed(data)]
