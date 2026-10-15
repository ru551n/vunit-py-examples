/* The HAL on the PC: every call goes to a Python function set by tb/cpu_mock.py, which turns
 * register accesses into AXI-Lite transactions in the simulation. */
#include "hal.h"

typedef uint32_t (*read_fn)(uint32_t addr);
typedef void (*write_fn)(uint32_t addr, uint32_t value);
typedef void (*puts_fn)(const char *s);

static read_fn read_cb;
static write_fn write_cb;
static puts_fn puts_cb;

void hal_sim_set_callbacks(read_fn read, write_fn write, puts_fn puts)
{
  read_cb = read;
  write_cb = write;
  puts_cb = puts;
}

uint32_t reg_read32(uint32_t addr)
{
  return read_cb(addr);
}

void reg_write32(uint32_t addr, uint32_t value)
{
  write_cb(addr, value);
}

void hal_puts(const char *s)
{
  puts_cb(s);
}
