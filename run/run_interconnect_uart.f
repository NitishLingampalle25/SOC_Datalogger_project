// VCS filelist for: AXI Interconnect + UART integration
// =============================================================================
// Run from:  /home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/run/
//
// Compile (errors + warnings printed to terminal AND saved in compile.log):
//   vcs -full64 -sverilog -l compile.log -f run_interconnect_uart.f -o simv_ic_uart
//
// Simulate:
//   ./simv_ic_uart -l sim.log
//
// Check error/warning count after compile:
//   grep -cE "^Error"   compile.log
//   grep -cE "^Warning" compile.log
//
// With Verdi waveforms (requires Verdi license):
//   vcs -full64 -sverilog -debug_access+all -kdb -l compile.log \
//       -f run_interconnect_uart.f -o simv_ic_uart
//   ./simv_ic_uart +fsdb+delta -verdi &
// =============================================================================

// ---- Include directories ----
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/include

// ---- Timescale stub  (listed first so all files inherit it) ----
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/timescale.v

// ---- AXI Interconnect RTL ----
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/priority_encoder.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/arbiter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/axi_interconnect.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/axi_interconnect_wrap_2x6.v

// ---- UART IP RTL (timescale now embedded in each file) ----
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v

// ---- Integration glue ----
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/axi4_to_axilite_bridge.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/axi_interconnect_uart_top.v

// ---- Testbench ----
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/TB_files/tb_interconnect_uart.sv
