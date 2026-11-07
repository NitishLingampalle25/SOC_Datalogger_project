// =============================================================================
// uart_tb_run.f — VCS filelist for UART UVM testbench
//
// Compile:
//   vcs -full64 -sverilog -ntb_opts uvm-1.2 \
//       -f uart_tb_run.f \
//       -debug_access+all -kdb -lca \
//       -o simv 2>&1 | tee compile.log
//
// Simulate:
//   ./simv +UVM_TESTNAME=uart_test +UVM_VERBOSITY=UVM_MEDIUM 2>&1 | tee sim.log
//
// Waveform:
//   verdi -ssf dump.fsdb &
// =============================================================================

// ---------------- Global timescale --------------------------------------------
-timescale=1ns/1ps

// ---------------- Debug access (needed for DUT internal signal visibility) ---
-debug_access+all+reverse
-kdb

// ---------------- Include paths -----------------------------------------------
+incdir+/home/student/Documents/SOC_Datalogger_project/axi-lite_uart-ipcore-develop/src/include
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb

// ---------------- RTL DUT files -----------------------------------------------
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_internal_fifo.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_parity_bit_compute.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_receiver.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_transmitter.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_controller.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_uart_top.v

// ---------------- TB files (interface → package → top) -----------------------
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_tb_top.sv
