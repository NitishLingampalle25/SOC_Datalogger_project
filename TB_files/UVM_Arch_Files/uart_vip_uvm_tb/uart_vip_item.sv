class uart_vip_item extends uvm_sequence_item;

  rand bit uart_rx_i;
  bit uart_tx_o;
  bit uart_read_irq_o;

  `uvm_object_utils(uart_vip_item)

  function new(string name="uart_vip_item"); super.new(name); endfunction
endclass
