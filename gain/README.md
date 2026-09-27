# Calling a Python function from VHDL

The smallest example, self-contained in this folder: the testbench loads a Python file and calls a
function in it with a positional and a keyword argument, then checks the result.

```
tb_gain.vhd   the testbench
gain.py       the Python function
run.py        the VUnit run script
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python gain/run.py
```

## How it works

`run.py` adds the bridge as a VUnit package:

```python
vu.add_package("vunit-python-bridge", allow_setup=True)
```

`allow_setup=True` lets the package configure the simulator and build its native interface where
needed.

`gain.py` is plain Python:

```python
def gain(sample, factor):
    return sample * factor
```

The testbench runs the file with `exec_file`, which makes `gain` a function of the Python session,
and calls it with `call`. `arg` passes a positional argument and `kwarg` a keyword argument, and the
result comes back as a VHDL `integer`:

```vhdl
exec_file("gain.py");
expected := call("gain", arg(7), kwarg("factor", 3));
check_equal(expected, 21);
```

A relative file name is found next to the testbench.
