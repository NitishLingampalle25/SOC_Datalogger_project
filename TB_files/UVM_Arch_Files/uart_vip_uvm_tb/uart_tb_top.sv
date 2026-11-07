// =============================================================================
// uart_tb_top.sv
// Top-level testbench module for UART UVM TB.
//
// Responsibilities:
//   1. Generate clock and reset
//   2. Instantiate uart_vip_if
//   3. Instantiate axi_uart_top DUT (AXI ports tied idle)
//   4. Set virtual interface into config_db so driver can get it
//   5. Call run_test() — test name passed via +UVM_TESTNAME
//   6. Dump FSDB for Verdi
// =============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"
import uart_vip_pkg::*;

module uart_tb_top;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial  clk = 1'b0;
    always #5 clk = ~clk;       // 100 MHz

    initial begin
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Interface instance
    // -------------------------------------------------------------------------
    uart_vip_if vif();

    assign vif.clk   = clk;
    assign vif.rst_n = rst_n;

    // -------------------------------------------------------------------------
    // DUT — axi_uart_top
    // Only UART serial pins connected to interface.
    // AXI ports tied to idle — no register transactions from TB.
    // -------------------------------------------------------------------------
    axi_uart_top dut (
        // Clocks & reset
        .fixed_clk_i        (clk),
        .axi_aclk_i         (clk),
        .axi_aresetn_i      (rst_n),

        // AXI Write Address — idle
        .axi_awid_i         (12'b0),
        .axi_awaddr_i       (5'b0),
        .axi_awvalid_i      (1'b0),
        .axi_awready_o      (),

        // AXI Write Data — idle
        .axi_wdata_i        (32'b0),
        .axi_wstrb_i        (4'b0),
        .axi_wvalid_i       (1'b0),
        .axi_wready_o       (),

        // AXI Write Response — idle
        .axi_bid_o          (),
        .axi_bresp_o        (),
        .axi_bvalid_o       (),
        .axi_bready_i       (1'b1),

        // AXI Read Address — idle
        .axi_arid_i         (12'b0),
        .axi_araddr_i       (5'b0),
        .axi_arvalid_i      (1'b0),
        .axi_arready_o      (),

        // AXI Read Data — idle
        .axi_rid_o          (),
        .axi_rdata_o        (),
        .axi_rresp_o        (),
        .axi_rvalid_o       (),
        .axi_rready_i       (1'b1),

        // UART serial pins — connected to interface
        .uart_rx_i          (vif.uart_rx_i),
        .uart_tx_o          (vif.uart_tx_o),
        .read_interrupt_o   (vif.uart_read_irq_o)
    );

    // -------------------------------------------------------------------------
    // Config DB — make interface available to driver via "uart_vif" key
    // -------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual uart_vip_if)::set(null, "*", "uart_vif", vif);
        run_test();   // +UVM_TESTNAME=uart_test passed on command line
    end

    // -------------------------------------------------------------------------
    // FSDB dump for Verdi
    // Dumps all signals recursively:
    //   uart_tb_top        — TB signals + interface (uart_rx_i, uart_tx_o, irq)
    //   uart_tb_top.dut    — axi_uart_top internal signals (FSMs, FIFOs, etc.)
    // -------------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, uart_tb_top);        // TB + interface signals
        $fsdbDumpvars(0, uart_tb_top.dut);    // DUT internals
        $fsdbDumpMDA();
        $fsdbDumpSVA();
    end

endmodule
