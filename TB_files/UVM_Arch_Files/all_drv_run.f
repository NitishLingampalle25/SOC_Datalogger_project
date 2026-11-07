// =============================================================================
// all_drv_run.f — VCS filelist for combined all-VIP driver testbench
//
// Compile:
//   vcs -full64 -sverilog -ntb_opts uvm -debug_access+all -kdb \
//       -f all_drv_run.f -o simv 2>&1 | tee compile.log
//
// Simulate:
//   ./simv +UVM_TESTNAME=uart_test +UVM_VERBOSITY=UVM_MEDIUM 2>&1 | tee sim.log
//
// Waveform (all 6 IPs in one window):
//   verdi -ssf dump.fsdb &
// =============================================================================

// ---------------- Global timescale + debug ------------------------------------
-timescale=1ns/1ps
-debug_access+all+reverse
-kdb

// ---------------- Include paths -----------------------------------------------
// UART header files
+incdir+/home/student/Documents/SOC_Datalogger_project/axi-lite_uart-ipcore-develop/src/include
// DMA header files
+incdir+/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/inc
+incdir+/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl
// GPIO register interface headers
+incdir+/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO/register_interface
// gpio_reg_top.sv uses `include "common_cells/assertions.svh" so point to GPIO/ (parent)
+incdir+/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO
// VIP package include dirs
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/gpio_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/dma_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/wdt_vip_uvm_tb
+incdir+/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/systimer_vip_uvm_tb

// =============================================================================
// RTL DUT files
// =============================================================================

// --- UART ---
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_internal_fifo.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_parity_bit_compute.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_receiver.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_transmitter.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/uart_controller.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/uart/rtl/axi_uart_top.v

// --- GPIO ---
/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO/gpio_reg_pkg.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO/prim_subreg.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO/gpio_input_stage.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO/gpio_reg_top.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/GPIO/gpio.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/gpio_axi_wrapper.v

// --- DMA ---
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/inc/amba_axi_pkg.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/inc/dma_utils_pkg.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_mux.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_or_reducer.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_address_decoder.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_adapter_common.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_axi4lite_skid_buffer.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_axi4lite_bridge.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_axi4lite_adapter.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_bit_field.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_bit_field_w01trg.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_bit_field_counter.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_register_common.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_default_register.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_external_register.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_indirect_register.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/rggen-verilog-rtl/rggen_maskable_register.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/csr_dma.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/dma_fifo.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/dma_fsm.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/dma_streamer.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/dma_axi_if.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/dma_func_wrapper.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/DMA/dma_axi_wrapper.sv

// --- WDT ---
/home/student/Documents/SOC_Datalogger_project/RTL_files/WDT/EF_WDT32.v
/home/student/Documents/SOC_Datalogger_project/RTL_files/WDT/ef_wdt32_axi_wrapper.v

// --- System Timer ---
/home/student/Documents/SOC_Datalogger_project/RTL_files/System_Timer/timer_core.sv
/home/student/Documents/SOC_Datalogger_project/RTL_files/timer_axi_wrapper.v

// =============================================================================
// VIP interface files (one per VIP)
// =============================================================================
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/gpio_vip_uvm_tb/gpio_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/dma_vip_uvm_tb/dma_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/wdt_vip_uvm_tb/wdt_vip_if.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/systimer_vip_uvm_tb/systimer_vip_if.sv

// =============================================================================
// VIP package files (each package includes its own classes)
// =============================================================================
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/uart_vip_uvm_tb/uart_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/gpio_vip_uvm_tb/gpio_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/dma_vip_uvm_tb/dma_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/wdt_vip_uvm_tb/wdt_vip_pkg.sv
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/systimer_vip_uvm_tb/systimer_vip_pkg.sv

// =============================================================================
// Top-level testbench
// =============================================================================
/home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files/tb_drv_test.sv
