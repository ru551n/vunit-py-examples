/* Reset: set the stack and run fw_main, then write its result to the emulator's exit register
 * (tb/cpu_mock.py), which stops the CPU. RAM starts zeroed in the emulator, so .bss is not cleared. */
  .section .text.start
  .global _start
_start:
  la sp, __stack_top
  call fw_main
  li t0, 0xFFFF0004
  sw a0, 0(t0)
1:
  j 1b
