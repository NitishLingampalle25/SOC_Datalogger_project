// uart_vip_if.sv — UART VIP interface
// External signals only: serial pins and RX-data-ready interrupt.
// AXI-Lite register access is internal to the SoC (CPU → interconnect → UART);
// it does NOT appear on the top-level DUT port and must NOT be in this interface.
`timescale 1ns/1ps
interface uart_vip_if;
    logic clk;
    logic rst_n;
    logic uart_rx_i;        // TB drives: serial byte stimulus into DUT RX pin
    logic uart_tx_o;        // DUT drives: serialised TX output
    logic uart_read_irq_o;  // DUT drives: RX FIFO data-ready interrupt
endinterface
