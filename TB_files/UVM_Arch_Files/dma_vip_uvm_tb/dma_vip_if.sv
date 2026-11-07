// dma_vip_if.sv — DMA VIP interface
// External signals only: DMA completion status and interrupt lines.
// DMA descriptor registers are programmed by the VeeR core through the AXI
// interconnect — those buses are internal and must NOT appear here.
`timescale 1ns/1ps
interface dma_vip_if;
    logic clk;
    logic rst_n;
    logic dma_done_o;   // DUT drives: transfer completed successfully
    logic dma_error_o;  // DUT drives: transfer aborted (e.g. SLVERR on DST)
    logic dma_irq_o;    // DUT drives: completion interrupt to PIC
endinterface
