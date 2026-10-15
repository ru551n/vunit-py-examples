/* One RAM for code, data and stack; == RAM_BASE and RAM_SIZE in tb/cpu_mock.py */
MEMORY
{
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : { *(.text.start) *(.text*) *(.rodata*) *(.srodata*) } > ram
  .data : { *(.data*) *(.sdata*) } > ram
  .bss : { *(.bss*) *(.sbss*) *(COMMON) } > ram
  __stack_top = ORIGIN(ram) + LENGTH(ram);
}
