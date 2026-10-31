// =============================================================================
// tb_soc_uvm_top.sv
// Top-level UVM testbench for veer2_dma_aes_wdt_uart_gpio_timer SoC
//
// Instantiates all 5 VIP interfaces, connects them to the DUT, sets them
// into UVM config_db, and launches the UVM test.
//
// Setup test only — no stimulus driven, just verifies UVM env builds cleanly.
//
// Compile with:
//   vcs -full64 -sverilog +incdir+<uvm_home>/src <uvm_home>/src/uvm_pkg.sv \
//       +incdir+uart_vip_uvm_tb +incdir+dma_vip_uvm_tb                      \
//       +incdir+gpio_vip_uvm_tb +incdir+systimer_vip_uvm_tb                 \
//       +incdir+wdt_vip_uvm_tb                                               \
//       uart_vip_uvm_tb/uart_vip_if.sv   uart_vip_uvm_tb/uart_vip_pkg.sv    \
//       dma_vip_uvm_tb/dma_vip_if.sv     dma_vip_uvm_tb/dma_vip_pkg.sv      \
//       gpio_vip_uvm_tb/gpio_vip_if.sv   gpio_vip_uvm_tb/gpio_vip_pkg.sv    \
//       systimer_vip_uvm_tb/systimer_vip_if.sv systimer_vip_uvm_tb/systimer_vip_pkg.sv \
//       wdt_vip_uvm_tb/wdt_vip_if.sv     wdt_vip_uvm_tb/wdt_vip_pkg.sv      \
//       tb_soc_uvm_top.sv -o simv_uvm_top
//
// Simulate:
//   ./simv_uvm_top +UVM_TESTNAME=uart_vip_test    +UVM_VERBOSITY=UVM_MEDIUM
// =============================================================================

`timescale 1ns/1ps

// ---- UVM base ---------------------------------------------------------------
import uvm_pkg::*;
`include "uvm_macros.svh"

// ---- VIP packages -----------------------------------------------------------
import uart_vip_pkg::*;
import dma_vip_pkg::*;
import gpio_vip_pkg::*;
import systimer_vip_pkg::*;
import wdt_vip_pkg::*;

module tb_soc_uvm_top;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    localparam CLK_PERIOD = 10; // 100 MHz

    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        `uvm_info("TB_TOP", "Reset released", UVM_MEDIUM)
    end

    // =========================================================================
    // VIP Interface Instances
    // =========================================================================
    uart_vip_if     uart_if();
    dma_vip_if      dma_if();
    gpio_vip_if     gpio_if();
    systimer_vip_if systimer_if();
    wdt_vip_if      wdt_if();

    // Drive clk and rst_n into every interface
    assign uart_if.clk        = clk;
    assign uart_if.rst_n      = rst_n;
    assign dma_if.clk         = clk;
    assign dma_if.rst_n       = rst_n;
    assign gpio_if.clk        = clk;
    assign gpio_if.rst_n      = rst_n;
    assign systimer_if.clk    = clk;
    assign systimer_if.rst_n  = rst_n;
    assign wdt_if.clk         = clk;
    assign wdt_if.rst_n       = rst_n;

    // =========================================================================
    // DUT — veer2_dma_aes_wdt_uart_gpio_timer
    // (Tied-off stub for UVM setup test; replace with full DUT for integration)
    // =========================================================================
    // Peripheral output signals connected to VIP interfaces
    // In a full run these come from the actual DUT ports.
    // For setup test we tie them to 0 so monitors have a valid signal.
    assign uart_if.uart_tx_o        = 1'b1;   // UART idle
    assign uart_if.uart_rx_i        = 1'b1;
    assign uart_if.uart_read_irq_o  = 1'b0;

    assign dma_if.dma_done_o        = 1'b0;
    assign dma_if.dma_error_o       = 1'b0;
    assign dma_if.dma_irq_o         = 1'b0;

    assign gpio_if.gpio_out_o       = 32'h0;
    assign gpio_if.gpio_tx_en_o     = 32'h0;
    assign gpio_if.gpio_in_i        = 32'hABCD_1234;
    assign gpio_if.gpio_irq_o       = 1'b0;

    assign systimer_if.timer_irq_o  = 1'b0;

    assign wdt_if.wdt_irq_o         = 1'b0;
    assign wdt_if.wdt_reset_o       = 1'b0;

    // =========================================================================
    // UVM config_db — publish all interfaces before run_test()
    // =========================================================================
    initial begin
        uvm_config_db #(virtual uart_vip_if    )::set(null,"*","uart_vif",    uart_if);
        uvm_config_db #(virtual dma_vip_if     )::set(null,"*","dma_vif",     dma_if);
        uvm_config_db #(virtual gpio_vip_if    )::set(null,"*","gpio_vif",    gpio_if);
        uvm_config_db #(virtual systimer_vip_if)::set(null,"*","systimer_vif",systimer_if);
        uvm_config_db #(virtual wdt_vip_if     )::set(null,"*","wdt_vif",     wdt_if);

        `uvm_info("TB_TOP", "All VIF handles set in config_db", UVM_MEDIUM)

        run_test();  // test name passed via +UVM_TESTNAME
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $fsdbDumpfile("tb_soc_uvm_top.fsdb");
        $fsdbDumpvars(0, tb_soc_uvm_top);
    end

endmodule
