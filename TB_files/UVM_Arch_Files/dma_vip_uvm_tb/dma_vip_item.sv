class dma_vip_item extends uvm_sequence_item;

  bit dma_done_o;
  bit dma_error_o;
  bit dma_irq_o;

  `uvm_object_utils(dma_vip_item)

  function new(string name="dma_vip_item"); super.new(name); endfunction
endclass
