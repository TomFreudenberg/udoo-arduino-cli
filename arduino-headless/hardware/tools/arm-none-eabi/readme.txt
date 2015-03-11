GNU Tools for ARM Embedded Processors

Table of Contents
* Installing executables on Linux
* Installing executables on Windows 
* Invoking GCC
* Architecture options usage
* C Libraries usage
* Linker scripts
* Startup code

* Installing executables on Linux *
Unpack the tarball to the target directory, like this:
$ cd target_dir && tar xjf arm-none-eabi-gcc-4_x-YYYYMMDD.tar.bz2

* Installing executables on Windows *
Run the installer (arm-none-eabi-gcc-4_x-YYYYMMDD.exe) and follow the
instructions.

* Invoking GCC *
On Linux, either invoke with the complete path like this:
$ target_dir/arm-none-eabi-gcc-4_x/bin/arm-none-eabi-gcc

Or set path like this:
$ export PATH=$PATH:target_dir/arm-none-eabi-gcc-4_x/bin/arm-none-eabi-gcc/bin
$ arm-none-eabi-gcc

On Windows (although the above approaches also work), it can be more
convenient to either have the installer register environment variables, or run
INSTALL_DIR\bin\gccvar.bat to set environment variables for the current cmd. 

* Architecture options usage *

This toolchain is built and optimized for Cortex-R/M bare metal development.
the following table shows how to invoke GCC/G++ with correct command line
options for variants of Cortex-R and Cortex-M architectures. 

--------------------------------------------------------------------
| ARM Core | Command Line Options                       | multilib |
|----------|--------------------------------------------|----------|
|Cortex-M0+| -mthumb -mcpu=cortex-m0plus                | armv6-m  |
|Cortex-M0 | -mthumb -mcpu=cortex-m0                    |          |
|Cortex-M1 | -mthumb -mcpu=cortex-m1                    |          |
|          |--------------------------------------------|          |
|          | -mthumb -march=armv6-m                     |          |
|----------|--------------------------------------------|----------|
|Cortex-M3 | -mthumb -mcpu=cortex-m3                    | armv7-m  |
|          |--------------------------------------------|          |
|          | -mthumb -march=armv7-m                     |          |
|----------|--------------------------------------------|----------|
|Cortex-M4 | -mthumb -mcpu=cortex-m4                    | armv7e-m |
|(No FP)   |--------------------------------------------|          |
|          | -mthumb -march=armv7e-m                    |          |
|----------|--------------------------------------------|----------|
|Cortex-M4 | -mthumb -mcpu=cortex-m4 -mfloat-abi=softfp | armv7e-m |
|(Soft FP) | -mfpu=fpv4-sp-d16                          | /softfp  |
|          |--------------------------------------------|          |
|          | -mthumb -march=armv7e-m -mfloat-abi=softfp |          |
|          | -mfpu=fpv4-sp-d16                          |          |
|----------|--------------------------------------------|----------|
|Cortex-M4 | -mthumb -mcpu=cortex-m4 -mfloat-abi=hard   | armv7e-m |
|(Hard FP) | -mfpu=fpv4-sp-d16                          | /fpu     |
|          |--------------------------------------------|          |
|          | -mthumb -march=armv7e-m -mfloat-abi=hard   |          |
|          | -mfpu=fpv4-sp-d16                          |          |
|----------|--------------------------------------------|----------|
|Cortex-R4 | -march=armv7-r                             | default  |
|Cortex-R5 |--------------------------------------------|----------|
|(No FP)   | -mthumb -march=armv7-r                     | armv7-r  |
|          |                                            | /thumb   |
|----------|--------------------------------------------|----------|
|Cortex-R4 | -mthumb -march=armv7-r -mfloat-abi=softfp  | armv7-r  |
|Cortex-R5 | -mfpu=vfpv3-d16                            | /thumb   |
|(Soft FP) |                                            | /softfp  |
|          |--------------------------------------------|----------|
|          | -march=armv7-r -mfloat-abi=softfp          | default  |
|          | -mfpu=vfpv3-d16                            |          |
|----------|--------------------------------------------|----------|
|Cortex-R4 | -mthumb -march=armv7-r -mfloat-abi=hard    | armv7-r  |
|Cortex-R5 | -mfpu=vfpv3-d16                            | /thumb   |
|(Hard FP) |                                            | /fpu     |
--------------------------------------------------------------------
The "default" means default ARM library in the root of SYSROOT lib folder.

* C Library usage *

This toolchain is released with prebuilt C libraries, based on newlib. In
additon to conventional -lc options for libc, you can choose to use or not use
semihosting by using the following options.

** semihosting
You can add the following line to the linker script (e.g. a.ld) to include
the semihosting library in a group (recommended).

GROUP(libgcc.a libc.a libm.a librdimon.a)

Then compile the programs like: 
$ arm-none-eabi-gcc --specs=rdimon.specs -T a.ld $(OTHER_OPTIONS)

Or you can add -lrdimon in the cmd line and compile the programs like:
$ arm-none-eabi-gcc --specs=rdimon.specs \
  -Wl,--start-group -lgcc -lc -lm -lrdimon -Wl,--end-group $(OTHER_OPTIONS)

** non-semihosting/retarget
If you are using retarget, then
$ arm-none-eabi-gcc \
  -Wl,--start-group -lgcc -lc -lm -lnosys -Wl,--end-group $(OTHER_OPTIONS)
Or
$ grep GROUP a.ld
GROUP(libgcc.a libc.a libm.a libnosys.a)
$ arm-none-eabi-gcc -T a.ld $(OTHER_OPTIONS)

* Linker scripts *

Latest update of linker scripts template is available on 
http://www.onarm.com/cmsis/download

Following is an example linker script which can work with this toolchain:

/**************************************************************************/
/* Configure memory regions */
MEMORY
{
  FLASH (rx) : ORIGIN = 0x0, LENGTH = 0x8000 /* 32k */
  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 0x2000 /* 8k */
}

/* Config Libraries */
GROUP(libgcc.a libc.a libm.a libnosys.a)

/* Linker script to place sections and symbol values. Should be used together
 * with other linker script that defines memory regions FLASH and RAM.
 * It references following symbols, which must be defined in code:
 *   Reset_Handler : Entry of reset handler
 * 
 * It defines following symbols, which code can use without definition:
 *   __exidx_start
 *   __exidx_end
 *   __etext
 *   __data_start__
 *   __preinit_array_start
 *   __preinit_array_end
 *   __init_array_start
 *   __init_array_end
 *   __fini_array_start
 *   __fini_array_end
 *   __data_end__
 *   __bss_start__
 *   __bss_end__
 *   __end__
 *   end
 *   __HeapLimit
 *   __StackLimit
 *   __StackTop
 *   __stack
 */
ENTRY(Reset_Handler)

SECTIONS
{
	.text :
	{
		KEEP(*(.isr_vector))
		*(.text*)

		KEEP(*(.init))
		KEEP(*(.fini))

		/* .ctors */
		*crtbegin.o(.ctors)
		*crtbegin?.o(.ctors)
		*(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
		*(SORT(.ctors.*))
		*(.ctors)

		/* .dtors */
 		*crtbegin.o(.dtors)
 		*crtbegin?.o(.dtors)
 		*(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
 		*(SORT(.dtors.*))
 		*(.dtors)

		*(.rodata*)

		KEEP(*(.eh_frame*))
	} > FLASH

	.ARM.extab : 
	{
		*(.ARM.extab* .gnu.linkonce.armextab.*)
	} > FLASH

	__exidx_start = .;
	.ARM.exidx :
	{
		*(.ARM.exidx* .gnu.linkonce.armexidx.*)
	} > FLASH
	__exidx_end = .;

	__etext = .;
		
	.data : AT (__etext)
	{
		__data_start__ = .;
		*(vtable)
		*(.data*)

		. = ALIGN(4);
		/* preinit data */
		PROVIDE_HIDDEN (__preinit_array_start = .);
		KEEP(*(.preinit_array))
		PROVIDE_HIDDEN (__preinit_array_end = .);

		. = ALIGN(4);
		/* init data */
		PROVIDE_HIDDEN (__init_array_start = .);
		KEEP(*(SORT(.init_array.*)))
		KEEP(*(.init_array))
		PROVIDE_HIDDEN (__init_array_end = .);


		. = ALIGN(4);
		/* finit data */
		PROVIDE_HIDDEN (__fini_array_start = .);
		KEEP(*(SORT(.fini_array.*)))
		KEEP(*(.fini_array))
		PROVIDE_HIDDEN (__fini_array_end = .);

		. = ALIGN(4);
		/* All data end */
		__data_end__ = .;

	} > RAM

	.bss :
	{
		__bss_start__ = .;
		*(.bss*)
		*(COMMON)
		__bss_end__ = .;
	} > RAM
	
	.heap :
	{
		__end__ = .;
		end = __end__;
		*(.heap*)
		__HeapLimit = .;
	} > RAM

	/* .stack_dummy section doesn't contains any symbols. It is only
	 * used for linker to calculate size of stack sections, and assign
	 * values to stack symbols later */
	.stack_dummy :
	{
		*(.stack*)
	} > RAM

	/* Set stack top to end of RAM, and stack limit move down by
	 * size of stack_dummy section */
	__StackTop = ORIGIN(RAM) + LENGTH(RAM);
	__StackLimit = __StackTop - SIZEOF(.stack_dummy);
	PROVIDE(__stack = __StackTop);
	
	/* Check if data + heap + stack exceeds RAM limit */
	ASSERT(__StackLimit >= __HeapLimit, "region RAM overflowed with stack")
}
/**************************************************************************/

* Startup code *

Latest update of startup code template is available on 
http://www.onarm.com/cmsis/download

Following is an example startup code for cortex-m0:
    .syntax unified
    .arch armv6-m

    .section .stack
    .align 3
    .globl    __StackTop
    .globl    __StackLimit
__StackLimit:
#ifdef __STACK_SIZE
    .space    __STACK_SIZE
#else
    .space    0xc00
#endif

    .size __StackLimit, . - __StackLimit
__StackTop:
    .size __StackTop, . - __StackTop

    .section .heap
    .align 3
    .globl    __HeapBase
    .globl    __HeapLimit
__HeapBase:
#ifdef __HEAP_SIZE
    .space    __HEAP_SIZE
#endif
    .size __HeapBase, . - __HeapBase
__HeapLimit:
    .size __HeapLimit, . - __HeapLimit
    
    .section .isr_vector
    .align 2
    .globl __isr_vector
__isr_vector:
    .long    __StackTop            /* Top of Stack */
    .long    Reset_Handler         /* Reset Handler */
    .long    NMI_Handler           /* NMI Handler */
    .long    HardFault_Handler     /* Hard Fault Handler */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    SVC_Handler           /* SVCall Handler */
    .long    0                     /* Reserved */
    .long    0                     /* Reserved */
    .long    PendSV_Handler        /* PendSV Handler */
    .long    SysTick_Handler       /* SysTick Handler */

    /* External interrupts */
    .long    Default_Handler
    
    .size    __isr_vector, . - __isr_vector

    .text
    .thumb
    .thumb_func
    .align 2
    .globl    Reset_Handler
    .type    Reset_Handler, %function
Reset_Handler:
/*     Loop to copy data from read only memory to RAM. The ranges
 *      of copy from/to are specified by following symbols evaluated in 
 *      linker script.
 *      __etext: End of code section, i.e., begin of data sections to copy from.
 *      __data_start__/__data_end__: RAM address range that data should be
 *      copied to. Both must be aligned to 4 bytes boundary.  */

    ldr    r1, =__etext
    ldr    r2, =__data_start__
    ldr    r3, =__data_end__

    subs    r3, r2
    ble    .flash_to_ram_loop_end

    movs    r4, 0
.flash_to_ram_loop:
    ldr    r0, [r1,r4]
    str    r0, [r2,r4]
    adds    r4, 4
    cmp    r4, r3
    blt    .flash_to_ram_loop
.flash_to_ram_loop_end:

#ifndef __NO_SYSTEM_INIT
    ldr    r0, =SystemInit
    blx    r0
#endif

    ldr    r0, =_start
    bx    r0
    .pool
    .size Reset_Handler, . - Reset_Handler
    
/*    Macro to define default handlers. Default handler
 *    will be weak symbol and just dead loops. They can be
 *    overwritten by other handlers */
    .macro    def_default_handler    handler_name
    .align 1
    .thumb_func
    .weak    \handler_name
    .type    \handler_name, %function
\handler_name :
    b    .
    .size    \handler_name, . - \handler_name
    .endm
    
    def_default_handler    NMI_Handler
    def_default_handler    HardFault_Handler
    def_default_handler    SVC_Handler
    def_default_handler    PendSV_Handler
    def_default_handler    SysTick_Handler
    def_default_handler    Default_Handler

    .weak    DEF_IRQHandler
    .set    DEF_IRQHandler, Default_Handler

    .end
