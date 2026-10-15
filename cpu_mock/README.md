# Firmware on a mocked CPU

C firmware, built for the PC, drives the design through VUnit's AXI-Lite master: every register
access the firmware makes is one bus transaction in the simulation. The design is tested by the
software that will run on it, without a CPU in the simulation and at the speed of native code.

```
src/adder_regs.vhd      the design: AXI-Lite registers A, B and SUM = A + B
firmware/firmware.c     the firmware: writes A and B, reads SUM and checks it
firmware/hal.h          the firmware's view of the hardware: reg_read32, reg_write32, hal_puts
firmware/hal_sim.c      that view on the PC: every call goes to Python
tb/cpu_mock.py          builds the firmware and runs it in a thread, one register access per step
tb/cpu_mock.vhd         the CPU mock: does each access with the bus master
tb/tb_adder_regs.vhd    the testbench
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python run.py "cpu_mock.*" -v
```

The firmware is compiled with `cc` (or `CC`) into the test's output path, so this example needs a C
compiler on every platform; it is tested on Linux only. `-v` shows the firmware's console:

```
firmware: 3 + 4 = 7
firmware: 1000 + 234 = 1234
firmware: 4294967295 + 2 = 1
```

Change `a + b` in `src/adder_regs.vhd` and the firmware prints `wrong sum` and returns 1, which
fails the test with `RuntimeError: the firmware returned 1`.

## How it works

The firmware only reaches the hardware through `hal.h`. On a real CPU `reg_read32` and
`reg_write32` are plain loads and stores; `hal_sim.c` instead calls functions that `cpu_mock.py`
sets with `ctypes`. The firmware runs in a Python thread, and each call becomes a request that
waits for the VHDL side:

```vhdl
request := call_integer_vector("cpu.step", arg(value));  -- [op, address, data]
case request(0) is
  when op_read => read_bus(net, bus_handle, ..., data);
  when op_write => write_bus(net, bus_handle, ..., ...);
  when others => exit;  -- fw_main returned
end case;
```

`step` hands the result of one access back to the firmware and returns its next one, so the
firmware only runs between steps and the simulation never waits on it. Simulated time is spent on
the bus only. When `fw_main` returns non-zero, or makes no access for 30 s, `step` raises and the
test fails.
