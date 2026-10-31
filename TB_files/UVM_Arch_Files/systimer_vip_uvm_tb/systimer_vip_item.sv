class systimer_vip_item extends uvm_sequence_item;

  bit timer_irq_o;

  `uvm_object_utils(systimer_vip_item)

  function new(string name="systimer_vip_item"); super.new(name); endfunction
endclass
