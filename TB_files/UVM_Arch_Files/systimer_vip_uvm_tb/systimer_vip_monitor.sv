class systimer_vip_monitor extends uvm_monitor;
virtual systimer_vip_if vif;
uvm_analysis_port #(systimer_vip_item) ap;
`uvm_component_utils(systimer_vip_monitor)
function new(string n,uvm_component p); super.new(n,p); ap=new("ap",this); endfunction
endclass
