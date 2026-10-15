/* The HAL on a RISC-V CPU: registers are plain loads and stores. The console is a register of
 * the emulator (tb/cpu_mock.py), one character per write. */
#include "hal.h"

#define CONSOLE 0xFFFF0000u

uint32_t reg_read32(uint32_t addr)
{
  return *(volatile uint32_t *)(uintptr_t)addr;
}

void reg_write32(uint32_t addr, uint32_t value)
{
  *(volatile uint32_t *)(uintptr_t)addr = value;
}

void hal_puts(const char *s)
{
  while (*s) {
    reg_write32(CONSOLE, (uint8_t)*s++);
  }
  reg_write32(CONSOLE, '\n');
}
