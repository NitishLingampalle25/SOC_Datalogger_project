class gpio_vip_item extends uvm_sequence_item;

  rand bit [31:0] gpio_in_i;
  bit [31:0] gpio_out_o;
  bit [31:0] gpio_tx_en_o;
  bit gpio_irq_o;

  `uvm_object_utils(gpio_vip_item)

  function new(string name="gpio_vip_item"); super.new(name); endfunction
endclass
