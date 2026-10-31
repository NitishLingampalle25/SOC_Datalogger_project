
import uvm_pkg::*; `include "uvm_macros.svh"
import dma_vip_pkg::*;
module tb_top;
  logic clk, rst_n;
  initial clk = 0; always #5 clk = ~clk;
  initial begin rst_n = 0; repeat(10) @(posedge clk); rst_n = 1; end
  dma_vip_if vif();
  assign vif.clk    = clk;  assign vif.rst_n   = rst_n;
  assign vif.dma_done_o  = 1'b0;
  assign vif.dma_error_o = 1'b0;
  assign vif.dma_irq_o   = 1'b0;
  initial begin
    uvm_config_db#(virtual dma_vip_if)::set(null,"*","dma_vif",vif);
    run_test("dma_vip_test");
  end
endmodule
