// gpio_vip_if.sv — GPIO VIP interface
// External signals only: parallel GPIO pad signals and interrupt.
// GPIO registers are accessed by the CPU through the AXI interconnect
// and must NOT appear here.
`timescale 1ns/1ps
interface gpio_vip_if;
    logic        clk;
    logic        rst_n;
    logic [31:0] gpio_in_i;     // TB drives: external pad inputs into DUT
    logic [31:0] gpio_out_o;    // DUT drives: pad output data
    logic [31:0] gpio_tx_en_o;  // DUT drives: pad output-enable (direction)
    logic        gpio_irq_o;    // DUT drives: GPIO interrupt to PIC
endinterface
