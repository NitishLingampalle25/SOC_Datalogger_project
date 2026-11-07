`timescale 1ns/1ps
// =============================================================================
// gpio_vip_agent.sv — UVM agent for GPIO VIP
//
// Active agent:
//   - driver    : drives gpio_in_i stimulus onto the virtual interface
//   - monitor   : passively samples gpio_out_o, gpio_tx_en_o, gpio_irq_o
//   - sequencer : arbitrates sequence items from test sequences to the driver
//
// The monitor's analysis port (mon.ap) is left exposed so the env can
// connect it to the scoreboard.
// =============================================================================
class gpio_vip_agent extends uvm_agent;

  gpio_vip_driver    drv;
  gpio_vip_monitor   mon;
  gpio_vip_sequencer seqr;

  `uvm_component_utils(gpio_vip_agent)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase — construct sub-components
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = gpio_vip_driver::type_id::create("drv",  this);
    mon  = gpio_vip_monitor::type_id::create("mon",  this);
    seqr = gpio_vip_sequencer::type_id::create("seqr", this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase — wire driver TLM port to sequencer export
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
