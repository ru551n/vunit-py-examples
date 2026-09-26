# Finding a bug with Hypothesis

[Hypothesis](https://hypothesis.readthedocs.io) generates the inputs of an 8-bit saturating adder
from VHDL, checks each result and, when one is wrong, shrinks it to the simplest failing input. The
adder has a planted bug: `255 + 1` wraps to 0 instead of saturating at 255.

```
src/saturating_add.vhd   the design, with the bug
tb/tb_saturating_add.vhd the testbench
tb/property.py           the Hypothesis property
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python run.py "hypothesis.*"
```

The test fails by design, with the shrunk counterexample:

```
AssertionError: 1 + 255 gave 0
Failing test case: saturating_add(
    a=1,
    b=255,
)
```

Change `full > 256` to `full >= 256` in `src/saturating_add.vhd` and it passes.

## How it works

Hypothesis wants to call the test, but here the simulator is in charge. So `property.py` runs the
property in a thread that hands each example to VHDL through a queue and waits for the result:

```python
@given(st.integers(0, 255), st.integers(0, 255))
def saturating_add(a, b):
    examples.put((a, b))
    got = results.get()
    assert got == min(a + b, 255), f"{a} + {b} gave {got}"
```

The testbench takes examples until Hypothesis is done, then `finish` raises the failure, if any:

```vhdl
while call("property.next_example") loop
  a <= to_unsigned(eval("property.example[0]"), a'length);
  b <= to_unsigned(eval("property.example[1]"), b'length);
  wait for 1 ns;
  call("property.results.put", arg(to_integer(sum)));
end loop;
call("property.finish");
```
