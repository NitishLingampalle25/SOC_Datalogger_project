// wdt_vip_if.sv — WDT VIP interface
// External signals only: the three WDT output lines.
// WDT registers are programmed by the CPU through the AXI interconnect —
// those buses are internal and must NOT appear here.
// aes_done_pulse_o → WDT auto-kick is an internal DUT wire; it also must
// NOT appear in this interface.
`timescale 1ns/1ps
interface wdt_vip_if;
    logic clk;
    logic rst_n;
    logic wdt_irq_o;     // DUT drives: stage-1 early-warning interrupt
    logic wdt_nmi_o;     // DUT drives: stage-2 NMI escalation to CPU
    logic wdt_reset_o;   // DUT drives: stage-3 hard system reset
    logic wdt_timeout_o; // DUT drives: raw timeout flag (unmasked)
endinterface
