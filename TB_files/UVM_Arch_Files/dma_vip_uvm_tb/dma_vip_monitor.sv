class dma_vip_monitor extends uvm_monitor;
virtual dma_vip_if vif;
uvm_analysis_port #(dma_vip_item) ap;
`uvm_component_utils(dma_vip_monitor)
function new(string n,uvm_component p); super.new(n,p); ap=new("ap",this); endfunction
endclass
