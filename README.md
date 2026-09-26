# vunit-py-examples

VHDL testbenches that call Python while they simulate, using
[vunit-python-bridge](https://github.com/VUnit/vunit-python-bridge) with [VUnit](https://vunit.github.io).

| Example | Shows |
| --- | --- |
| [fir](fir) | A FIR filter checked sample by sample against a NumPy model that also generates the stimuli |

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

Then run an example with `python <example>/run.py`.

`requirements.txt` pins VUnit and the bridge to git commits, since neither the VUnit release with
package support nor the bridge is on PyPI yet.
