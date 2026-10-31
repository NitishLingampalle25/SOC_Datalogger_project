class wdt_vip_item extends uvm_sequence_item;

  bit wdt_irq_o;
  bit wdt_reset_o;

  `uvm_object_utils(wdt_vip_item)

  function new(string name="wdt_vip_item"); super.new(name); endfunction
endclass
