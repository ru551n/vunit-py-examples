import queue
import threading

from hypothesis import given, settings, strategies as st

examples = queue.Queue()
results = queue.Queue()
error = None


@settings(max_examples=1000, deadline=None, database=None, derandomize=True)
@given(st.integers(0, 255), st.integers(0, 255))
def saturating_add(a, b):
    examples.put((a, b))
    got = results.get()
    assert got == min(a + b, 255), f"{a} + {b} gave {got}"


def run():
    global error
    try:
        saturating_add()
    except Exception as exc:
        error = exc
    examples.put(None)


threading.Thread(target=run, daemon=True).start()


def next_example():
    global example
    example = examples.get()
    return example is not None


def finish():
    if error:
        raise error
