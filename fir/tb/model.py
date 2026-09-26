import numpy as np

COEFFS = [1, 3, 3, 1]


def stimuli(length, seed):
    return np.random.default_rng(seed).integers(-128, 128, length)


def fir(samples):
    return np.convolve(samples, COEFFS)[: len(samples)]
