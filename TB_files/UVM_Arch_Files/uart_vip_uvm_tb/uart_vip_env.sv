// =============================================================================
// uart_vip_env.sv — UVM environment for UART VIP
// Contains one agent and one scoreboard.
// Wires agent.mon.ap → sb.ap in connect_phase.
// =============================================================================
class uart_vip_env extends uvm_env;

  uart_vip_agent      agent;
  uart_vip_scoreboard sb;

  `uvm_component_utils(uart_vip_env)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  // ---------------------------------------------------------------------------
  // build_phase: construct agent and scoreboard
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = uart_vip_agent::type_id::create("agent", this);
    sb    = uart_vip_scoreboard::type_id::create("sb",    this);
  endfunction

  // ---------------------------------------------------------------------------
  // connect_phase: monitor analysis port → scoreboard
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.ap);
  endfunction

endclass
