class dma_vip_test extends uvm_test;
dma_vip_env env;
`uvm_component_utils(dma_vip_test)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); env=dma_vip_env::type_id::create("env",this); endfunction
endclass
