  wvAddSignal tb_soc_top.clk
  wvAddSignal tb_soc_top.rst_l
  wvAddSignal tb_soc_top.dut.veer_inst.trace_rv_i_valid_ip
  wvAddSignal tb_soc_top.dut.veer_inst.trace_rv_i_address_ip
  wvAddSignal tb_soc_top.dut.veer_inst.trace_rv_i_insn_ip
  wvAddSignal tb_soc_top.uart_tx_o
  wvAddSignal tb_soc_top.uart_read_irq_o
  wvAddSignal tb_soc_top.aes_busy_o
  wvAddSignal tb_soc_top.aes_done_o
  wvAddSignal tb_soc_top.aes_irq_o
  wvAddSignal tb_soc_top.dma_done_o
  wvAddSignal tb_soc_top.dma_error_o
  wvAddSignal tb_soc_top.gpio_out_o
  wvAddSignal tb_soc_top.timer_irq_o
  wvAddSignal tb_soc_top.wdt_irq_o
  wvZoomFit
  EOF
  
  verdi -ssf tb_soc_top.fsdb -play add_signals.tcl &






exit




