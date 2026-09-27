# vunit-py-examples

VHDL testbenches that call Python while they simulate, using
[vunit-python-bridge](https://github.com/VUnit/vunit-python-bridge) with [VUnit](https://vunit.github.io).

| Example | Shows |
| --- | --- |
| [gain](gain) | The smallest example, self-contained with its own `run.py`: a VHDL testbench calling a Python function |
| [fir](fir) | A FIR filter checked sample by sample against a NumPy model that also generates the stimuli |
| [hypothesis](hypothesis) | Hypothesis finding and shrinking a bug in a saturating adder (fails by design) |

## Requirements

- Python 3.10 or later with a shared `libpython` (distribution Pythons, `uv`, `pyenv` and
  python.org installers all qualify)
- NVC or GHDL (Questa also works)
- Linux and macOS: a C compiler and the Python headers (`python3-dev` on Debian/Ubuntu). The bridge
  compiles a small C library on first use and caches it in `vunit_out`. Windows uses prebuilt DLLs.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Then run all examples with `python run.py`. Each example compiles into a library named after its
folder, so `python run.py "fir.*"` runs one. `gain` has its own run script: `python gain/run.py`.

`requirements.txt` takes VUnit from its 5.0 pre-releases and the bridge from its releases, both on
PyPI.
