/* The firmware: writes two operands to adder_regs, reads their sum back and checks it. */
#include <stdio.h>

#include "hal.h"

/* adder_regs.vhd */
#define REG_A 0x0u
#define REG_B 0x4u
#define REG_SUM 0x8u

int fw_main(void)
{
  static const uint32_t operands[][2] = {{3, 4}, {1000, 234}, {0xFFFFFFFFu, 2}};
  char line[64];

  for (unsigned i = 0; i < sizeof operands / sizeof operands[0]; i++) {
    uint32_t a = operands[i][0], b = operands[i][1];
    reg_write32(REG_A, a);
    reg_write32(REG_B, b);
    uint32_t sum = reg_read32(REG_SUM);
    snprintf(line, sizeof line, "%lu + %lu = %lu", (unsigned long)a, (unsigned long)b, (unsigned long)sum);
    hal_puts(line);
    if (sum != a + b) {
      hal_puts("wrong sum");
      return 1;
    }
  }
  return 0;
}
