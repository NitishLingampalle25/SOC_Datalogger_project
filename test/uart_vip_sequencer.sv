// =============================================================================
// uart_vip_sequencer.sv — UVM sequencer for UART VIP
// Thin wrapper; no custom logic needed — UVM base class handles arbitration.
// =============================================================================
class uart_vip_sequencer extends uvm_sequencer #(uart_vip_item);
  `uvm_component_utils(uart_vip_sequencer)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

endclass
