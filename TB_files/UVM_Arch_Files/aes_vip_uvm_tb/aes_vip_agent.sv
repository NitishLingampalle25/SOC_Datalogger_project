`timescale 1ns/1ps
//=============================================================================
// aes_vip_agent.sv
// AES VIP Agent — active agent encapsulating driver, sequencer, and monitor
//=============================================================================

class aes_vip_agent extends uvm_agent;

  `uvm_component_utils(aes_vip_agent)

  // Sub-components
  aes_vip_driver    driver;
  aes_vip_sequencer sequencer;
  aes_vip_monitor   monitor;

  // Analysis port forwarded from monitor (env connects to scoreboard)
  uvm_analysis_port #(aes_vip_item) ap;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "aes_vip_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // build_phase — always active (is_active == UVM_ACTIVE)
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Always create monitor (passive or active)
    monitor = aes_vip_monitor::type_id::create("monitor", this);

    // Create driver + sequencer only for active agent
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = aes_vip_driver::type_id::create("driver", this);
      sequencer = aes_vip_sequencer::type_id::create("sequencer", this);
    end

    // Expose monitor's analysis port at agent level
    ap = new("ap", this);
  endfunction

  // -------------------------------------------------------------------------
  // connect_phase — wire driver ↔ sequencer, forward monitor ap
  // -------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);

    // Forward monitor's analysis port to agent's ap
    monitor.ap.connect(ap);
  endfunction

endclass : aes_vip_agent
