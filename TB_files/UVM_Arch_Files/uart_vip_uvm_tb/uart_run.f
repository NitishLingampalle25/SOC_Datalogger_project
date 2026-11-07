// =============================================================================
// uart_run.f  —  VCS compile filelist for UART VIP UVM Testbench
//
// Run from ANY directory using:
//   vcs -full64 -sverilog -ntb_opts uvm-1.2 \
//       -f /home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_run.f \
//       -debug_access+all -kdb -lca -o simv 2>&1 | tee compile.log
//
//   ./simv +UVM_TESTNAME=uart_vip_test +UVM_VERBOSITY=UVM_HIGH 2>&1 | tee sim.log
//   verdi -ssf dump.fsdb &
// =============================================================================

// ---------------- Global timescale --------------------------------------------
-timescale=1ns/1ps

// ---------------- Include paths -----------------------------------------------
+incdir+/home/student/Documents/SOC_Datalogger_project/axi-lite_uart-ipcore-develop/src/include
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb
-v /home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv

// ---------------- RTL DUT files -----------------------------------------------
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_internal_fifo.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_parity_bit_compute.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_receiver.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_transmitter.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_controller.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_uart_top.v

// ---------------- Testbench files (interface → package → top) -----------------
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/tb_top.sv
