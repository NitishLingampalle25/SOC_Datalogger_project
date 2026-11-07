// =============================================================================
// tb_soc_uvm_top.sv
// Top-level UVM testbench for veer2_dma_aes_wdt_uart_gpio_timer SoC
//
// Testplan: VeeR_EL2_SoC_Testplan.ods
// Tests: TC_UART_01..04, TC_TMR_01..02, TC_AES_01..02,
//        TC_DMA_01..02, TC_WDT_01..04, TC_GPIO_01..03,
//        TC_PIPE_01, TC_BUS_01..02, TC_FULL_01
//
// Compile:
//   vcs -full64 -sverilog +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv \
//       +incdir+uart_vip_uvm_tb   uart_vip_uvm_tb/uart_vip_if.sv   uart_vip_uvm_tb/uart_vip_pkg.sv   \
//       +incdir+dma_vip_uvm_tb    dma_vip_uvm_tb/dma_vip_if.sv     dma_vip_uvm_tb/dma_vip_pkg.sv     \
//       +incdir+gpio_vip_uvm_tb   gpio_vip_uvm_tb/gpio_vip_if.sv   gpio_vip_uvm_tb/gpio_vip_pkg.sv   \
//       +incdir+systimer_vip_uvm_tb systimer_vip_uvm_tb/systimer_vip_if.sv systimer_vip_uvm_tb/systimer_vip_pkg.sv \
//       +incdir+wdt_vip_uvm_tb    wdt_vip_uvm_tb/wdt_vip_if.sv     wdt_vip_uvm_tb/wdt_vip_pkg.sv     \
//       soc_uvm_pkg.sv tb_soc_uvm_top.sv -o simv_soc_uvm
//
// Simulate (example):
//   ./simv_soc_uvm +UVM_TESTNAME=tc_uart_01_test  +UVM_VERBOSITY=UVM_MEDIUM
//   ./simv_soc_uvm +UVM_TESTNAME=tc_full_01_test
// =============================================================================

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

import uart_vip_pkg::*;
import dma_vip_pkg::*;
import gpio_vip_pkg::*;
import systimer_vip_pkg::*;
import wdt_vip_pkg::*;
import soc_uvm_pkg::*;

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
        repeat(20) @(posedge clk);
        rst_n = 1'b1;
        `uvm_info("TB_TOP","Reset released",UVM_MEDIUM)
    end

    // =========================================================================
    // VIP Interface Instances
    // =========================================================================
    uart_vip_if     uart_if();
    dma_vip_if      dma_if();
    gpio_vip_if     gpio_if();
    systimer_vip_if systimer_if();
    wdt_vip_if      wdt_if();

    // Clock & reset to all interfaces
    assign uart_if.clk         = clk;   assign uart_if.rst_n         = rst_n;
    assign dma_if.clk          = clk;   assign dma_if.rst_n          = rst_n;
    assign gpio_if.clk         = clk;   assign gpio_if.rst_n         = rst_n;
    assign systimer_if.clk     = clk;   assign systimer_if.rst_n     = rst_n;
    assign wdt_if.clk          = clk;   assign wdt_if.rst_n          = rst_n;

    // =========================================================================
    // DUT — veer2_dma_aes_wdt_uart_gpio_timer
    //
    // Only external (top-level port) signals are connected through VIP
    // interfaces.  AXI buses, ICCM/DCCM, debug, and all internal buses are
    // NOT connected here — they remain inside the DUT hierarchy.
    //
    // Replace stub assigns below with actual DUT instantiation:
    //   veer2_dma_aes_wdt_uart_gpio_timer dut (
    //       .clk(clk),   .rst_l(rst_n),  .dbg_rst_l(1'b1),
    //       .fixed_clk(clk),
    //       .rst_vec(31'h0), .nmi_vec(31'h0), .jtag_id(31'h0), .core_id('0),
    //       .nmi_int(1'b0),  .timer_int(1'b0), .soft_int(1'b0),
    //       .extintsrc_req('0),
    //       // UART external pins
    //       .uart_rx_i(uart_if.uart_rx_i),
    //       .uart_tx_o(uart_if.uart_tx_o),
    //       .uart_read_irq_o(uart_if.uart_read_irq_o),
    //       // DMA status
    //       .dma_done_o(dma_if.dma_done_o),
    //       .dma_error_o(dma_if.dma_error_o),
    //       .dma_irq_o(dma_if.dma_irq_o),
    //       // GPIO pads
    //       .gpio_in_i(gpio_if.gpio_in_i),
    //       .gpio_out_o(gpio_if.gpio_out_o),
    //       .gpio_tx_en_o(gpio_if.gpio_tx_en_o),
    //       .gpio_irq_o(gpio_if.gpio_irq_o),
    //       // Timer interrupt
    //       .timer_irq_o(systimer_if.timer_irq_o),
    //       // WDT escalation lines
    //       .wdt_irq_o(wdt_if.wdt_irq_o),
    //       .wdt_nmi_o(wdt_if.wdt_nmi_o),
    //       .wdt_reset_o(wdt_if.wdt_reset_o),
    //       .wdt_timeout_o(wdt_if.wdt_timeout_o)
    //       // AES is verified internally via firmware (no external VIP pins)
    //       // IFU/SB/DMA AXI masters — connect to memory model or leave floating
    //   );
    // =========================================================================

    // -------------------------------------------------------------------------
    // DUT output stubs — replace with actual DUT port connections when RTL
    // is available.  Only external signals appear here; AXI buses are
    // internal to the SoC and are NOT connected through VIP interfaces.
    //
    // Connect as:
    //   <top_module> dut (
    //       .clk(clk), .rst_l(rst_n), ...
    //       .uart_rx_i(uart_if.uart_rx_i),
    //       .uart_tx_o(uart_if.uart_tx_o),
    //       .uart_read_irq_o(uart_if.uart_read_irq_o),
    //       .dma_done_o(dma_if.dma_done_o),
    //       .dma_error_o(dma_if.dma_error_o),
    //       .dma_irq_o(dma_if.dma_irq_o),
    //       .gpio_in_i(gpio_if.gpio_in_i),
    //       .gpio_out_o(gpio_if.gpio_out_o),
    //       .gpio_tx_en_o(gpio_if.gpio_tx_en_o),
    //       .gpio_irq_o(gpio_if.gpio_irq_o),
    //       .timer_irq_o(systimer_if.timer_irq_o),
    //       .wdt_irq_o(wdt_if.wdt_irq_o),
    //       .wdt_nmi_o(wdt_if.wdt_nmi_o),
    //       .wdt_reset_o(wdt_if.wdt_reset_o),
    //       .wdt_timeout_o(wdt_if.wdt_timeout_o)
    //   );
    // -------------------------------------------------------------------------

    // UART — TB drives uart_rx_i; DUT drives uart_tx_o and uart_read_irq_o
    assign uart_if.uart_tx_o       = 1'b1;  // idle (mark) until DUT connected
    assign uart_if.uart_read_irq_o = 1'b0;

    // DMA — all outputs driven by DUT; stubbed to 0 until DUT connected
    assign dma_if.dma_done_o  = 1'b0;
    assign dma_if.dma_error_o = 1'b0;
    assign dma_if.dma_irq_o   = 1'b0;

    // GPIO — TB drives gpio_in_i; DUT drives outputs
    assign gpio_if.gpio_out_o   = 32'h0;
    assign gpio_if.gpio_tx_en_o = 32'h0;
    assign gpio_if.gpio_irq_o   = 1'b0;

    // SysTimer — DUT drives timer_irq_o
    assign systimer_if.timer_irq_o = 1'b0;

    // WDT — DUT drives all four output lines
    assign wdt_if.wdt_irq_o     = 1'b0;
    assign wdt_if.wdt_nmi_o     = 1'b0;
    assign wdt_if.wdt_reset_o   = 1'b0;
    assign wdt_if.wdt_timeout_o = 1'b0;

    // =========================================================================
    // TC_FULL_01 monitor — watches gpio_out_o[31:16] for firmware pass/fail
    // =========================================================================
    always @(posedge clk) begin
        if (gpio_if.gpio_out_o[31:16] === 16'h900D) begin
            $display("*** ALL FIRMWARE CHECKS PASSED (gpio_out=0x900D) ***");
            $finish;
        end
        if (gpio_if.gpio_out_o[31:16] === 16'hDEAD) begin
            $display("!!! FIRMWARE FAILURE DETECTED (gpio_out=0xDEAD) !!!");
            $finish;
        end
    end

    // =========================================================================
    // Simulation timeout guard — 10 ms
    // =========================================================================
    initial begin
        #(10_000_000);
        `uvm_fatal("TB_TOP","Simulation timeout (10ms) — no $finish from firmware")
    end

    // =========================================================================
    // UVM config_db — publish all VIF handles
    // =========================================================================
    initial begin
        uvm_config_db #(virtual uart_vip_if    )::set(null,"*","uart_vif",    uart_if);
        uvm_config_db #(virtual dma_vip_if     )::set(null,"*","dma_vif",     dma_if);
        uvm_config_db #(virtual gpio_vip_if    )::set(null,"*","gpio_vif",    gpio_if);
        uvm_config_db #(virtual systimer_vip_if)::set(null,"*","systimer_vif",systimer_if);
        uvm_config_db #(virtual wdt_vip_if     )::set(null,"*","wdt_vif",     wdt_if);

        `uvm_info("TB_TOP","All VIF handles published to config_db",UVM_MEDIUM)
        run_test();  // +UVM_TESTNAME selects which test class to run
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("tb_soc_uvm_top.vcd");
        $dumpvars(0, tb_soc_uvm_top);
    end

endmodule
