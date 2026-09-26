# FIR filter checked against a NumPy model

A VHDL testbench that calls Python while it simulates, using
[vunit-python-bridge](https://github.com/VUnit/vunit-python-bridge). The testbench asks a NumPy
model for random stimuli and the expected output of a FIR filter, drives the filter with the
stimuli and checks every output sample against the model.

```
src/fir.vhd       the design: a 4-tap FIR filter
tb/tb_fir.vhd     the VUnit testbench, calling Python through python_bridge
tb/model.py       the NumPy reference model
run.py            the VUnit run script
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python fir/run.py                # VUNIT_SIMULATOR=ghdl python fir/run.py to pick GHDL
```

Both tests pass. To see the model catch a bug, change `COEFFS` in `tb/model.py` and run again:

```
ERROR - sample 3 - Got ... Expected ...
```

VUnit picks a new seed on every run, so the stimuli change each time. Rerun a failure with the same
stimuli using `python fir/run.py --seed repeat`.

## How it works

`run.py` adds the bridge as a VUnit package:

```python
vu.add_package("vunit-python-bridge", allow_setup=True)
```

The testbench loads the model and calls it. `integer_array_t` values cross as NumPy arrays:

```vhdl
import_module_from_file(join(tb_path(runner_cfg), "model.py"), "model");
stimuli <= call_integer_array("model.stimuli", arg(1000), arg_unsigned(get_seed(runner_cfg)));
expected <= call_integer_array("model.fir", arg(stimuli));
```
