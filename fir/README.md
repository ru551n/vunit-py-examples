# FIR filter checked against a NumPy model

The testbench asks a NumPy model for random stimuli and the expected output of a FIR filter. VUnit's
AXI-stream verification components drive the stimuli into the filter and check every output sample.

```
src/fir.vhd       the design: a 4-tap FIR filter
tb/tb_fir.vhd     the testbench
tb/model.py       the NumPy model
```

## Run it

Set up the environment as described in the [top-level README](../README.md), then:

```bash
python run.py
```

Change `COEFFS` in `tb/model.py` and the test fails with a `TDATA mismatch`. VUnit picks a new seed,
and so new stimuli, on every run; `python run.py --seed repeat` reruns the last one.

## How it works

`run.py` in the repository root adds the bridge as a VUnit package:

```python
vu.add_package("vunit-python-bridge", allow_setup=True)
```

The testbench loads the model and calls it. `integer_array_t` values cross as NumPy arrays:

```vhdl
import_module_from_file(join(tb_path(runner_cfg), "model.py"), "model");
stimuli := call("model.stimuli", arg(1000), arg_unsigned(get_seed(runner_cfg)));
expected := call("model.fir", arg(stimuli));
```
