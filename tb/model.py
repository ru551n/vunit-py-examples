"""Reference model for tb_fir.vhd, called from VHDL through vunit-python-bridge."""

import numpy as np

COEFFS = [1, 3, 3, 1]


def stimuli(length, seed):
    """Random signed 8-bit samples; int8 arrays become 8-bit signed integer_array_t."""
    return np.random.default_rng(seed).integers(-128, 128, length, dtype=np.int8)


def fir(samples):
    """The expected filter output, same length as the input."""
    return np.convolve(samples.astype(np.int32), COEFFS)[: len(samples)]
