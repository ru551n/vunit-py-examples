# Calling a Python function from VHDL

The smallest example: the testbench loads a Python file and calls a function in it with a positional
and a keyword argument, then checks the result.

```
tb/tb_gain.vhd   the testbench
tb/gain.py       the Python function
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python run.py "gain.*"
```

## How it works

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
