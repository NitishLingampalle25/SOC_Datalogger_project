// aes_vip_if.sv — AES VIP interface
// External signals only: AES engine status and completion outputs.
// AES key/plaintext/ciphertext registers are accessed by the CPU through the
// AXI interconnect — those buses are internal and must NOT appear here.
`timescale 1ns/1ps
interface aes_vip_if;
    logic clk;
    logic rst_n;
    logic aes_busy_o;        // DUT drives: engine is processing (locks registers)
    logic aes_done_o;        // DUT drives: encryption complete (level)
    logic aes_done_pulse_o;  // DUT drives: single-cycle completion pulse (WDT kick)
    logic aes_irq_o;         // DUT drives: AES completion interrupt to PIC
endinterface
