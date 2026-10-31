class wdt_vip_agent extends uvm_agent;
wdt_vip_driver drv; wdt_vip_monitor mon; wdt_vip_sequencer seqr;
`uvm_component_utils(wdt_vip_agent)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); drv=wdt_vip_driver::type_id::create("drv",this); mon=wdt_vip_monitor::type_id::create("mon",this); seqr=wdt_vip_sequencer::type_id::create("seqr",this); endfunction
function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
endclass
