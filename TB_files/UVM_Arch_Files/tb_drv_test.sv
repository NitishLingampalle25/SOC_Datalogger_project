// =============================================================================
// tb_drv_test.sv
// Combined driver testbench — instantiates all 6 VIP interfaces and DUTs.
// Sets all virtual interfaces into config_db so each VIP driver can get them.
// All signals visible in one Verdi window via FSDB dump.
//
// VIPs and config_db keys:
//   UART      → "uart_vif"      (uart_vip_if)
//   GPIO      → "gpio_vif"      (gpio_vip_if)
//   DMA       → "dma_vif"       (dma_vip_if)
//   WDT       → "wdt_vif"       (wdt_vip_if)
//   SysTimer  → "systimer_vif"  (systimer_vip_if)
// =============================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"

import uart_vip_pkg::*;
import gpio_vip_pkg::*;
import dma_vip_pkg::*;
import wdt_vip_pkg::*;
import systimer_vip_pkg::*;
import amba_axi_pkg::*;

module tb_drv_test;

    // =========================================================================
    // Clock & Reset (shared across all DUTs)
    // =========================================================================
    logic clk;
    logic rst_n;

    initial  clk = 1'b0;
    always #5 clk = ~clk;    // 100 MHz

    initial begin
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
    end

    // =========================================================================
    // Interface instantiations
    // =========================================================================
    uart_vip_if      uart_vif();
    gpio_vip_if      gpio_vif();
    dma_vip_if       dma_vif();
    wdt_vip_if       wdt_vif();
    systimer_vip_if  systimer_vif();

    // Connect clk/rst to all interfaces
    assign uart_vif.clk      = clk;  assign uart_vif.rst_n      = rst_n;
    assign gpio_vif.clk      = clk;  assign gpio_vif.rst_n      = rst_n;
    assign dma_vif.clk       = clk;  assign dma_vif.rst_n       = rst_n;
    assign wdt_vif.clk       = clk;  assign wdt_vif.rst_n       = rst_n;
    assign systimer_vif.clk  = clk;  assign systimer_vif.rst_n  = rst_n;

    // =========================================================================
    // DUT: UART — axi_uart_top
    // AXI ports tied idle; only serial pins connected to interface
    // =========================================================================
    axi_uart_top uart_dut (
        .fixed_clk_i        (clk),
        .axi_aclk_i         (clk),
        .axi_aresetn_i      (rst_n),
        .axi_awid_i         (12'b0),  .axi_awaddr_i  (5'b0),
        .axi_awvalid_i      (1'b0),   .axi_awready_o (),
        .axi_wdata_i        (32'b0),  .axi_wstrb_i   (4'b0),
        .axi_wvalid_i       (1'b0),   .axi_wready_o  (),
        .axi_bid_o          (),       .axi_bresp_o   (),
        .axi_bvalid_o       (),       .axi_bready_i  (1'b1),
        .axi_arid_i         (12'b0),  .axi_araddr_i  (5'b0),
        .axi_arvalid_i      (1'b0),   .axi_arready_o (),
        .axi_rid_o          (),       .axi_rdata_o   (),
        .axi_rresp_o        (),       .axi_rvalid_o  (),
        .axi_rready_i       (1'b1),
        .uart_rx_i          (uart_vif.uart_rx_i),
        .uart_tx_o          (uart_vif.uart_tx_o),
        .read_interrupt_o   (uart_vif.uart_read_irq_o)
    );

    // =========================================================================
    // DUT: GPIO — gpio_axi_wrapper
    // AXI ports tied idle; GPIO pad pins connected to interface
    // =========================================================================
    gpio_axi_wrapper #(
        .ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(8)
    ) gpio_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        // AXI4 Slave — idle
        .s_axi_awid         (8'b0),   .s_axi_awaddr  (32'b0),
        .s_axi_awlen        (8'b0),   .s_axi_awsize  (3'b0),
        .s_axi_awburst      (2'b0),   .s_axi_awlock  (1'b0),
        .s_axi_awcache      (4'b0),   .s_axi_awprot  (3'b0),
        .s_axi_awqos        (4'b0),   .s_axi_awregion(4'b0),
        .s_axi_awvalid      (1'b0),   .s_axi_awready (),
        .s_axi_wdata        (32'b0),  .s_axi_wstrb   (4'b0),
        .s_axi_wlast        (1'b1),   .s_axi_wvalid  (1'b0),
        .s_axi_wready       (),
        .s_axi_bid          (),       .s_axi_bresp   (),
        .s_axi_bvalid       (),       .s_axi_bready  (1'b1),
        .s_axi_arid         (8'b0),   .s_axi_araddr  (32'b0),
        .s_axi_arlen        (8'b0),   .s_axi_arsize  (3'b0),
        .s_axi_arburst      (2'b0),   .s_axi_arlock  (1'b0),
        .s_axi_arcache      (4'b0),   .s_axi_arprot  (3'b0),
        .s_axi_arqos        (4'b0),   .s_axi_arregion(4'b0),
        .s_axi_arvalid      (1'b0),   .s_axi_arready (),
        .s_axi_rid          (),       .s_axi_rdata   (),
        .s_axi_rresp        (),       .s_axi_rlast   (),
        .s_axi_rvalid       (),       .s_axi_rready  (1'b1),
        // GPIO pads — connected to interface
        .gpio_in_i          (gpio_vif.gpio_in_i),
        .gpio_out_o         (gpio_vif.gpio_out_o),
        .gpio_tx_en_o       (gpio_vif.gpio_tx_en_o),
        .gpio_irq_o         (gpio_vif.gpio_irq_o)
    );

    // =========================================================================
    // DUT: DMA — dma_axi_wrapper
    // All AXI ports tied idle; status/irq connected to interface
    // =========================================================================
    s_axil_mosi_t dma_csr_mosi_idle;
    s_axi_miso_t  dma_m_miso_idle;

    assign dma_csr_mosi_idle = '0;
    assign dma_m_miso_idle   = '0;

    dma_axi_wrapper #(.DMA_ID_VAL(0)) dma_dut (
        .clk                (clk),
        .rst                (~rst_n),
        .dma_csr_mosi_i     (dma_csr_mosi_idle),
        .dma_csr_miso_o     (),
        .dma_m_mosi_o       (),
        .dma_m_miso_i       (dma_m_miso_idle),
        .dma_done_o         (dma_vif.dma_done_o),
        .dma_error_o        (dma_vif.dma_error_o)
    );
    assign dma_vif.dma_irq_o = dma_vif.dma_done_o;

    // =========================================================================
    // DUT: WDT — ef_wdt32_axi_wrapper
    // AXI ports tied idle; timeout/irq outputs connected to interface
    // =========================================================================
    ef_wdt32_axi_wrapper #(
        .ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(8)
    ) wdt_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        // AXI4 Slave — idle
        .s_axi_awid         (8'b0),   .s_axi_awaddr  (32'b0),
        .s_axi_awlen        (8'b0),   .s_axi_awsize  (3'b0),
        .s_axi_awburst      (2'b0),   .s_axi_awlock  (1'b0),
        .s_axi_awcache      (4'b0),   .s_axi_awprot  (3'b0),
        .s_axi_awqos        (4'b0),   .s_axi_awregion(4'b0),
        .s_axi_awvalid      (1'b0),   .s_axi_awready (),
        .s_axi_wdata        (32'b0),  .s_axi_wstrb   (4'b0),
        .s_axi_wlast        (1'b1),   .s_axi_wvalid  (1'b0),
        .s_axi_wready       (),
        .s_axi_bid          (),       .s_axi_bresp   (),
        .s_axi_bvalid       (),       .s_axi_bready  (1'b1),
        .s_axi_arid         (8'b0),   .s_axi_araddr  (32'b0),
        .s_axi_arlen        (8'b0),   .s_axi_arsize  (3'b0),
        .s_axi_arburst      (2'b0),   .s_axi_arlock  (1'b0),
        .s_axi_arcache      (4'b0),   .s_axi_arprot  (3'b0),
        .s_axi_arqos        (4'b0),   .s_axi_arregion(4'b0),
        .s_axi_arvalid      (1'b0),   .s_axi_arready (),
        .s_axi_rid          (),       .s_axi_rdata   (),
        .s_axi_rresp        (),       .s_axi_rlast   (),
        .s_axi_rvalid       (),       .s_axi_rready  (1'b1),
        // Outputs — connected to interface
        .aes_done_pulse_i   (1'b0),
        .wdt_irq_o          (wdt_vif.wdt_irq_o),
        .wdt_nmi_o          (wdt_vif.wdt_nmi_o),
        .wdt_reset_o        (wdt_vif.wdt_reset_o),
        .wdt_timeout_o      (wdt_vif.wdt_timeout_o)
    );

    // =========================================================================
    // DUT: System Timer — timer_axi_wrapper
    // AXI ports tied idle; IRQ connected to interface
    // =========================================================================
    timer_axi_wrapper #(
        .ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(8)
    ) systimer_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        // AXI4 Slave — idle
        .s_axi_awid         (8'b0),   .s_axi_awaddr  (32'b0),
        .s_axi_awlen        (8'b0),   .s_axi_awsize  (3'b0),
        .s_axi_awburst      (2'b0),   .s_axi_awlock  (1'b0),
        .s_axi_awcache      (4'b0),   .s_axi_awprot  (3'b0),
        .s_axi_awqos        (4'b0),   .s_axi_awregion(4'b0),
        .s_axi_awvalid      (1'b0),   .s_axi_awready (),
        .s_axi_wdata        (32'b0),  .s_axi_wstrb   (4'b0),
        .s_axi_wlast        (1'b1),   .s_axi_wvalid  (1'b0),
        .s_axi_wready       (),
        .s_axi_bid          (),       .s_axi_bresp   (),
        .s_axi_bvalid       (),       .s_axi_bready  (1'b1),
        .s_axi_arid         (8'b0),   .s_axi_araddr  (32'b0),
        .s_axi_arlen        (8'b0),   .s_axi_arsize  (3'b0),
        .s_axi_arburst      (2'b0),   .s_axi_arlock  (1'b0),
        .s_axi_arcache      (4'b0),   .s_axi_arprot  (3'b0),
        .s_axi_arqos        (4'b0),   .s_axi_arregion(4'b0),
        .s_axi_arvalid      (1'b0),   .s_axi_arready (),
        .s_axi_rid          (),       .s_axi_rdata   (),
        .s_axi_rresp        (),       .s_axi_rlast   (),
        .s_axi_rvalid       (),       .s_axi_rready  (1'b1),
        // Timer Interrupt Output
        .timer_irq_o        (systimer_vif.timer_irq_o)
    );

    // =========================================================================
    // Config DB — set all virtual interfaces so drivers can retrieve them
    // =========================================================================
    initial begin
        uvm_config_db #(virtual uart_vip_if)::set     (null, "*", "uart_vif",     uart_vif);
        uvm_config_db #(virtual gpio_vip_if)::set     (null, "*", "gpio_vif",     gpio_vif);
        uvm_config_db #(virtual dma_vip_if)::set      (null, "*", "dma_vif",      dma_vif);
        uvm_config_db #(virtual wdt_vip_if)::set      (null, "*", "wdt_vif",      wdt_vif);
        uvm_config_db #(virtual systimer_vip_if)::set (null, "*", "systimer_vif", systimer_vif);
        run_test();   // +UVM_TESTNAME on command line
    end

    // =========================================================================
    // FSDB dump — all scopes in one dump file for single Verdi window
    // =========================================================================
    initial begin
        $fsdbDumpfile("dump.fsdb");
        // TB signals + all interfaces
        $fsdbDumpvars(0, tb_drv_test);
        // DUT internals — each IP hierarchy
        $fsdbDumpvars(0, tb_drv_test.uart_dut);
        $fsdbDumpvars(0, tb_drv_test.gpio_dut);
        $fsdbDumpvars(0, tb_drv_test.dma_dut);
        $fsdbDumpvars(0, tb_drv_test.wdt_dut);
        $fsdbDumpvars(0, tb_drv_test.systimer_dut);
        $fsdbDumpMDA();
        $fsdbDumpSVA();
    end

endmodule
