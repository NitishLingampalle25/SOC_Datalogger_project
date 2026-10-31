
import uvm_pkg::*; `include "uvm_macros.svh"
import gpio_vip_pkg::*;
module tb_top;
  logic clk, rst_n;
  initial clk = 0; always #5 clk = ~clk;
  initial begin rst_n = 0; repeat(10) @(posedge clk); rst_n = 1; end
  gpio_vip_if vif();
  assign vif.clk        = clk;  assign vif.rst_n     = rst_n;
  assign vif.gpio_out_o   = 32'h0;
  assign vif.gpio_tx_en_o = 32'h0;
  assign vif.gpio_in_i    = 32'hABCD1234;
  assign vif.gpio_irq_o   = 1'b0;
  initial begin
    uvm_config_db#(virtual gpio_vip_if)::set(null,"*","gpio_vif",vif);
    run_test("gpio_vip_test");
  end
endmodule
