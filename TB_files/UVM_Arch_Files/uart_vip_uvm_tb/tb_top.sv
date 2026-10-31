
import uvm_pkg::*; `include "uvm_macros.svh"
import uart_vip_pkg::*;
module tb_top;
  logic clk, rst_n;
  initial clk = 0; always #5 clk = ~clk;
  initial begin rst_n = 0; repeat(10) @(posedge clk); rst_n = 1; end
  uart_vip_if vif();
  assign vif.clk   = clk;  assign vif.rst_n  = rst_n;
  assign vif.uart_tx_o       = 1'b1;
  assign vif.uart_rx_i       = 1'b1;
  assign vif.uart_read_irq_o = 1'b0;
  initial begin
    uvm_config_db#(virtual uart_vip_if)::set(null,"*","uart_vif",vif);
    run_test("uart_vip_test");
  end
endmodule
