/* =============================================================================
 * crt0.S  –  Minimal bare-metal startup for VeeR EL2 (RV32IMC)
 *
 * Responsibilities:
 *   1. Provide the reset entry point at the start of .text.init
 *      (linker places this at 0x8000_0000 = reset vector)
 *   2. Set up the stack pointer (DCCM top: 0xF004_0000 + 64 KB = 0xF005_0000)
 *   3. Zero the .bss section
 *   4. Call main()
 *   5. Park after main() returns (spin forever)
 * =============================================================================
 */

    .section .text.init
    .globl  _start
    .type   _start, @function

_start:
    /* ---------------------------------------------------------------
     * Disable all interrupts at machine level
     * --------------------------------------------------------------- */
    csrw    mie,  zero
    csrw    mstatus, zero

    /* ---------------------------------------------------------------
     * Set stack pointer to top of DCCM region
     *   DCCM base = 0xF004_0000, size = 64 KB → top = 0xF005_0000
     * --------------------------------------------------------------- */
    li      sp, 0xF0050000

    /* ---------------------------------------------------------------
     * Zero .bss section
     *   BSS_START and BSS_END are symbols exported by link.ld
     * --------------------------------------------------------------- */
    la      a0, BSS_START
    la      a1, BSS_END
    beq     a0, a1, .bss_done
.bss_loop:
    sw      zero, 0(a0)
    addi    a0, a0, 4
    blt     a0, a1, .bss_loop
.bss_done:

    /* ---------------------------------------------------------------
     * Jump to main()
     * --------------------------------------------------------------- */
    call    main

    /* ---------------------------------------------------------------
     * Park: main() should never return but handle it safely
     * --------------------------------------------------------------- */
.park:
    j       .park

    .size _start, . - _start
