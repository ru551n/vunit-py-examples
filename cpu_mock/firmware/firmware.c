/* The firmware: writes two operands to adder_regs, reads their sum back and checks it. */
#include "hal.h"

/* adder_regs.vhd, in the CPU's bus window */
#define REG_A 0xF0000000u
#define REG_B 0xF0000004u
#define REG_SUM 0xF0000008u

/* Text without stdio, which the bare-metal RV32 build does not have */
static char *put_str(char *p, const char *s)
{
  while (*s) {
    *p++ = *s++;
  }
  return p;
}

static char *put_u32(char *p, uint32_t v)
{
  char digits[10];
  int n = 0;
  do {
    digits[n++] = (char)('0' + v % 10);
    v /= 10;
  } while (v);
  while (n) {
    *p++ = digits[--n];
  }
  return p;
}

int fw_main(void)
{
  static const uint32_t operands[][2] = {{3, 4}, {1000, 234}, {0xFFFFFFFFu, 2}};
  char line[40];

  for (unsigned i = 0; i < sizeof operands / sizeof operands[0]; i++) {
    uint32_t a = operands[i][0], b = operands[i][1];
    reg_write32(REG_A, a);
    reg_write32(REG_B, b);
    uint32_t sum = reg_read32(REG_SUM);
    char *p = put_u32(line, a);
    p = put_str(p, " + ");
    p = put_u32(p, b);
    p = put_str(p, " = ");
    p = put_u32(p, sum);
    *p = '\0';
    hal_puts(line);
    if (sum != a + b) {
      hal_puts("wrong sum");
      return 1;
    }
  }
  return 0;
}
