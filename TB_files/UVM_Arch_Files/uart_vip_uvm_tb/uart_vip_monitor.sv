class uart_vip_monitor extends uvm_monitor;
virtual uart_vip_if vif;
uvm_analysis_port #(uart_vip_item) ap;
`uvm_component_utils(uart_vip_monitor)
function new(string n,uvm_component p); super.new(n,p); ap=new("ap",this); endfunction
endclass
