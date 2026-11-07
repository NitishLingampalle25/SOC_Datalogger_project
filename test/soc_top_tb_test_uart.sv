
import uvm_pkg::*;

`include "uvm_macros.svh"


logic clk;
logic rst_n;

initial 
     begin
	clk=0;
	always #5 clk=~clk;

end 


initial
begin
	rst_n=0;
	#50 rst_n=1;
end

// physical Interface declaration

uart_vip_if vif();


//connect clk and reset 

assign vif.clk = clk;
assign vif.rst_n =rst_n;

uart_dut dut (
        .clk             (vif.clk),
        .rst_n           (vif.rst_n),
        .awaddr          (vif.awaddr),
        .awvalid         (vif.awvalid),
        .awready         (vif.awready),
        .wdata           (vif.wdata),
        .wvalid          (vif.wvalid),
        .wready          (vif.wready),
        .bresp           (vif.bresp),
        .bvalid          (vif.bvalid),
        .bready          (vif.bready),
        .araddr          (vif.araddr),
        .arvalid         (vif.arvalid),
        .arready         (vif.arready),
        .rdata           (vif.rdata),
        .rresp           (vif.rresp),
        .rvalid          (vif.rvalid),
        .rready          (vif.rready),
        .uart_rx_i       (vif.uart_rx_i),
        .uart_tx_o       (vif.uart_tx_o),
        .uart_read_irq_o (vif.uart_read_irq_o)
    );

initial
begin
	uvm_config_db #(virtual uart_vip_if):: set(null, "*", "vif", vif);

	run_test();
end

initial
begin
	$fsdbDumpfile("dump.fsdb");
	$fsdbDumpvars("+all");
	$fsdbDumpMDA();
	$fsdbDumpSVA();

end

endmodule


 
