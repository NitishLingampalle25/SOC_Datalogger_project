// =============================================================================
// uart_directed_run.f  —  VCS filelist for standalone directed UART test
//
// Compile:
//   vcs -full64 -sverilog -f uart_directed_run.f \
//       -debug_access+all -kdb -lca -o simv_directed 2>&1 | tee compile.log
//
// Simulate:
//   ./simv_directed 2>&1 | tee sim.log
//
// Waveform:
//   verdi -ssf dump.fsdb &
// =============================================================================

// ---------------- Global timescale --------------------------------------------
-timescale=1ns/1ps

// ---------------- Include paths -----------------------------------------------
+incdir+/home/student/Documents/SOC_Datalogger_project/axi-lite_uart-ipcore-develop/src/include

// ---------------- RTL DUT files -----------------------------------------------
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_internal_fifo.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_parity_bit_compute.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_receiver.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_transmitter.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_controller.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_uart_top.v

// ---------------- Testbench files ---------------------------------------------
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/test/soc_top_tb_test_uart.sv
