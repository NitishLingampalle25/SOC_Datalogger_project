class systimer_vip_agent extends uvm_agent;
systimer_vip_driver drv; systimer_vip_monitor mon; systimer_vip_sequencer seqr;
`uvm_component_utils(systimer_vip_agent)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); drv=systimer_vip_driver::type_id::create("drv",this); mon=systimer_vip_monitor::type_id::create("mon",this); seqr=systimer_vip_sequencer::type_id::create("seqr",this); endfunction
function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
endclass
