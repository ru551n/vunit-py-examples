from pathlib import Path

from vunit import VUnit

root = Path(__file__).parent

vu = VUnit.from_argv()
vu.add_vhdl_builtins()
vu.add_verification_components()
vu.add_package("vunit-python-bridge", allow_setup=True)

for example in (src.parent for src in root.glob("*/src")):
    lib = vu.add_library(example.name)
    lib.add_source_files(example / "*" / "*.vhd")

vu.main()
