// =============================================================================
// uart_vip_agent.sv — UVM agent for UART VIP
// Active agent: instantiates driver, monitor, and sequencer.
// Driver seq_item_port is connected to sequencer seq_item_export.
// Monitor analysis port is left open for the env to connect to scoreboard.
// =============================================================================
class uart_vip_agent extends uvm_agent;

  uart_vip_driver    drv;
  uart_vip_monitor   mon;
  uart_vip_sequencer seqr;

  `uvm_component_utils(uart_vip_agent)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct all sub-components
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = uart_vip_driver::type_id::create("drv",  this);
    mon  = uart_vip_monitor::type_id::create("mon",  this);
    seqr = uart_vip_sequencer::type_id::create("seqr", this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: wire driver to sequencer
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
