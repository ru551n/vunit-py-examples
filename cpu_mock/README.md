# Firmware on a mocked CPU

C firmware drives the design through VUnit's AXI-Lite master: every register access the firmware
makes is one bus transaction in the simulation. The design is tested by the software that will run
on it, without a CPU in the simulation. Two tests run the same `firmware.c`:

- **Test native firmware**: built for the PC, with a HAL that calls Python. Fastest, and needs only `cc`.
- **Test RV32 firmware on Unicorn**: built for RV32IM with a RISC-V GCC, as for a real CPU, and run
  in the [Unicorn](https://www.unicorn-engine.org) emulator. Loads and stores in the bus window
  become the bus transactions, so the real binary, with its startup code and memory layout, is tested.

```
src/adder_regs.vhd        the design: AXI-Lite registers A, B and SUM = A + B
firmware/firmware.c       the firmware: writes A and B, reads SUM and checks it
firmware/hal.h            the firmware's view of the hardware: reg_read32, reg_write32, hal_puts
firmware/hal_sim.c        that view on the PC: every call goes to Python
firmware/rv32/            that view on RV32 (loads and stores), its startup code and linker script
tb/cpu_mock.py            builds the firmware, runs it natively or in Unicorn, one access per step
tb/cpu_mock.vhd           the CPU mock: does each access with the bus master
tb/tb_adder_regs.vhd      the testbench
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python run.py "cpu_mock.*" -v
```

The firmware is compiled into each test's output path: with `cc` (or `CC`) natively, and with a
RISC-V GCC for RV32: `RISCV_GCC`, else the first of `riscv-none-elf-gcc` (for example the
[xPack](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack) build),
`riscv64-unknown-elf-gcc` and `riscv32-unknown-elf-gcc` on `PATH`. Tested on Linux only. `-v` shows
the firmware's console:

```
firmware: 3 + 4 = 7
firmware: 1000 + 234 = 1234
firmware: 4294967295 + 2 = 1
```

Change `a + b` in `src/adder_regs.vhd` and the firmware prints `wrong sum` and returns 1, which
fails both tests with `RuntimeError: the firmware returned 1`.

## How it works

The firmware only reaches the hardware through `hal.h`. The firmware runs in a Python thread, and
each register access becomes a request that waits for the VHDL side:

```vhdl
request := call_integer_vector("cpu.step", arg(value));  -- [op, address, data]
case request(0) is
  when op_read => read_bus(net, bus_handle, ..., data);
  when op_write => write_bus(net, bus_handle, ..., ...);
  when others => exit;  -- the firmware returned
end case;
```

`step` hands the result of one access back to the firmware and returns its next one, so the
firmware only runs between steps and simulated time is spent on the bus only.

Natively, `hal_sim.c` calls functions that `cpu_mock.py` sets with `ctypes`. In Unicorn, RAM holds
the binary at 0x0, accesses to 0xF000_0000 to 0xF000_0FFF go to the simulation, and two emulator
registers at 0xFFFF_0000 take the console's characters and the exit status that `start.S` writes
when `fw_main` returns.

When the firmware returns non-zero, crashes (an unmapped access or an invalid instruction, with its
pc) or makes no access for 30 s, `step` raises and the test fails.
