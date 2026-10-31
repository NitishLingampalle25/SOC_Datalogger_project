// =============================================================================
// run_uvm_top.f  —  UVM SoC tb_top (setup test, no DUT RTL needed)
//
// Compile:
//   cd /home/student/Documents/SOC_Datalogger_project/run
//   vcs -full64 -sverilog -debug_access+all -kdb \
//       -P /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64/novas.tab \
//       -LDFLAGS "-L/home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64 -lnovas" \
//       -l compile_uvm_top.log -f run_uvm_top.f -o simv_uvm_top
//
// Simulate (setup test — just checks UVM env builds):
//   export LD_LIBRARY_PATH=/home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64:$LD_LIBRARY_PATH
//   ./simv_uvm_top +UVM_TESTNAME=uart_vip_test +UVM_VERBOSITY=UVM_MEDIUM -l sim_uvm_top.log
// =============================================================================

-sverilog
-timescale=1ns/1ps

// UVM 1.2 macros include path (for `include "uvm_macros.svh" inside packages)
// NOTE: -ntb_opts uvm-1.2 must be passed on the vcs command line, not here
+incdir+/home/student/snps_tools_target/vcs/U-2023.03/etc/uvm-1.2

// ---- VIP include directories ------------------------------------------------
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/dma_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/gpio_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/systimer_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/wdt_vip_uvm_tb

// ---- VIP interfaces (must be before packages) --------------------------------
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/dma_vip_uvm_tb/dma_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/gpio_vip_uvm_tb/gpio_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/systimer_vip_uvm_tb/systimer_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/wdt_vip_uvm_tb/wdt_vip_if.sv

// ---- VIP packages (each `include's its own classes) -------------------------
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/dma_vip_uvm_tb/dma_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/gpio_vip_uvm_tb/gpio_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/systimer_vip_uvm_tb/systimer_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/wdt_vip_uvm_tb/wdt_vip_pkg.sv

// ---- Top-level TB -----------------------------------------------------------
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/tb_soc_uvm_top.sv
