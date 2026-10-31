class uart_vip_agent extends uvm_agent;
uart_vip_driver drv; uart_vip_monitor mon; uart_vip_sequencer seqr;
`uvm_component_utils(uart_vip_agent)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); drv=uart_vip_driver::type_id::create("drv",this); mon=uart_vip_monitor::type_id::create("mon",this); seqr=uart_vip_sequencer::type_id::create("seqr",this); endfunction
function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
endclass
