// systimer_vip_if.sv — System Timer VIP interface
// External signals only: timer compare-match interrupt.
// Timer registers (CFG0, CMP, VAL_LO, CTRL, INTR_EN, INTR_ST) are accessed
// by the CPU through the AXI interconnect — they are internal and must NOT
// appear here.
`timescale 1ns/1ps
interface systimer_vip_if;
    logic clk;
    logic rst_n;
    logic timer_irq_o;  // DUT drives: compare-match interrupt to PIC/CPU
endinterface
