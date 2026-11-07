// run_soc_uvm.f — VCS filelist for full SoC UVM testbench
// Usage:
//   vcs -full64 -sverilog +define+UVM_NO_DEPRECATED \
//       -f run/run_soc_uvm.f -o simv_soc_uvm
// Run:
//   ./simv_soc_uvm +UVM_TESTNAME=tc_uart_01_test +UVM_VERBOSITY=UVM_MEDIUM

// UVM library (adjust UVM_HOME to your installation)
+incdir+${UVM_HOME}/src
${UVM_HOME}/src/uvm_pkg.sv

// ---- Interfaces (must precede packages) ------------------------------------
+incdir+TB_files/UVM_Arch_Files/uart_vip_uvm_tb
TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv

+incdir+TB_files/UVM_Arch_Files/dma_vip_uvm_tb
TB_files/UVM_Arch_Files/dma_vip_uvm_tb/dma_vip_if.sv

+incdir+TB_files/UVM_Arch_Files/gpio_vip_uvm_tb
TB_files/UVM_Arch_Files/gpio_vip_uvm_tb/gpio_vip_if.sv

+incdir+TB_files/UVM_Arch_Files/systimer_vip_uvm_tb
TB_files/UVM_Arch_Files/systimer_vip_uvm_tb/systimer_vip_if.sv

+incdir+TB_files/UVM_Arch_Files/wdt_vip_uvm_tb
TB_files/UVM_Arch_Files/wdt_vip_uvm_tb/wdt_vip_if.sv

// ---- VIP Packages ----------------------------------------------------------
TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_pkg.sv
TB_files/UVM_Arch_Files/dma_vip_uvm_tb/dma_vip_pkg.sv
TB_files/UVM_Arch_Files/gpio_vip_uvm_tb/gpio_vip_pkg.sv
TB_files/UVM_Arch_Files/systimer_vip_uvm_tb/systimer_vip_pkg.sv
TB_files/UVM_Arch_Files/wdt_vip_uvm_tb/wdt_vip_pkg.sv

// ---- SoC-level package + top -----------------------------------------------
TB_files/UVM_Arch_Files/soc_uvm_pkg.sv
TB_files/UVM_Arch_Files/tb_soc_uvm_top.sv
