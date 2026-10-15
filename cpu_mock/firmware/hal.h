/* The firmware's only view of the hardware. hal_sim.c implements it on the PC, for the testbench;
 * on a real CPU, reg_read32 and reg_write32 are plain loads and stores. */
#ifndef HAL_H
#define HAL_H

#include <stdint.h>

uint32_t reg_read32(uint32_t addr);
void reg_write32(uint32_t addr, uint32_t value);
/* A line on the console */
void hal_puts(const char *s);

/* The firmware. 0 when all went well. */
int fw_main(void);

#endif
