import uvm_pkg::*;
`include "uvm_macros.svh"
import uart_vip_pkg::*;

module tb_top;

  logic clk, rst_n;

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;
  end

  uart_vip_if vif();

  assign vif.clk   = clk;
  assign vif.rst_n = rst_n;

  // DUT instantiation
  axi_uart_top dut (
    .fixed_clk_i    (vif.clk),
    .axi_aclk_i     (vif.clk),
    .axi_aresetn_i  (vif.rst_n),

    // AXI Write Address
    .axi_awid_i     (4'b0),
    .axi_awaddr_i   (vif.awaddr),
    .axi_awvalid_i  (vif.awvalid),
    .axi_awready_o  (vif.awready),

    // AXI Write Data
    .axi_wdata_i    (vif.wdata),
    .axi_wstrb_i    (vif.wstrb),
    .axi_wvalid_i   (vif.wvalid),
    .axi_wready_o   (vif.wready),

    // AXI Write Response
    .axi_bid_o      (),
    .axi_bresp_o    (vif.bresp),
    .axi_bvalid_o   (vif.bvalid),
    .axi_bready_i   (vif.bready),

    // AXI Read Address
    .axi_arid_i     (4'b0),
    .axi_araddr_i   (vif.araddr),
    .axi_arvalid_i  (vif.arvalid),
    .axi_arready_o  (vif.arready),

    // AXI Read Data
    .axi_rid_o      (),
    .axi_rdata_o    (vif.rdata),
    .axi_rresp_o    (vif.rresp),
    .axi_rvalid_o   (vif.rvalid),
    .axi_rready_i   (vif.rready),

    // UART serial pins
    .uart_rx_i          (vif.uart_rx_i),
    .uart_tx_o          (vif.uart_tx_o),
    .read_interrupt_o   (vif.uart_read_irq_o)
  );

  // FSDB dump for Verdi
  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, tb_top);
    $fsdbDumpMDA();
    $fsdbDumpSVA();
  end

  initial begin
    uvm_config_db#(virtual uart_vip_if)::set(null, "*", "uart_vif", vif);
    run_test();   // test name passed via +UVM_TESTNAME at runtime
  end

endmodule
