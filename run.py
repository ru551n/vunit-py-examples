from pathlib import Path

from vunit import VUnit

root = Path(__file__).parent

vu = VUnit.from_argv()
vu.add_vhdl_builtins()
# allow_setup lets the package build its native bridge library for the simulator
vu.add_package("vunit-python-bridge", allow_setup=True)

lib = vu.add_library("lib")
lib.add_source_files(root / "src" / "*.vhd")
lib.add_source_files(root / "tb" / "*.vhd")

vu.main()
