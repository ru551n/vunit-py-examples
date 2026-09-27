from pathlib import Path
from vunit import VUnit

root = Path(__file__).resolve().parent

vu = VUnit.from_argv()
vu.add_vhdl_builtins()
vu.add_package("vunit-python-bridge", allow_setup=True)

lib = vu.add_library("lib")
lib.add_source_files(root / "tb_gain.vhd")

vu.main()
