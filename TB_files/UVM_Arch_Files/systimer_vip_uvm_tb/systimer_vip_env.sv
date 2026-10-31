class systimer_vip_env extends uvm_env;
systimer_vip_agent agent; systimer_vip_scoreboard sb;
`uvm_component_utils(systimer_vip_env)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); agent=systimer_vip_agent::type_id::create("agent",this); sb=systimer_vip_scoreboard::type_id::create("sb",this); endfunction
endclass
