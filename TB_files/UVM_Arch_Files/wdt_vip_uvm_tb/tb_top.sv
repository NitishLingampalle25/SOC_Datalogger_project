
import uvm_pkg::*; `include "uvm_macros.svh"
import wdt_vip_pkg::*;
module tb_top;
  logic clk, rst_n;
  initial clk = 0; always #5 clk = ~clk;
  initial begin rst_n = 0; repeat(10) @(posedge clk); rst_n = 1; end
  wdt_vip_if vif();
  assign vif.clk       = clk;  assign vif.rst_n    = rst_n;
  assign vif.wdt_irq_o   = 1'b0;
  assign vif.wdt_reset_o = 1'b0;
  initial begin
    uvm_config_db#(virtual wdt_vip_if)::set(null,"*","wdt_vif",vif);
    run_test("wdt_vip_test");
  end
endmodule
