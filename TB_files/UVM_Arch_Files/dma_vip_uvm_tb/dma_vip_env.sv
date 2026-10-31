class dma_vip_env extends uvm_env;
dma_vip_agent agent; dma_vip_scoreboard sb;
`uvm_component_utils(dma_vip_env)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); agent=dma_vip_agent::type_id::create("agent",this); sb=dma_vip_scoreboard::type_id::create("sb",this); endfunction
endclass
