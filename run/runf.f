-sverilog
+define+RV_BUILD_AXI4
+define+RV_PHYSICAL

# ----------------- Include Directories -----------------
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/include
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/snapshots/default
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/include

# ----------------- Global timescale stub (MUST be first in the filelist) ---------
# Sets `timescale 1ns/1ps for the entire compilation unit.
# VCS LRM rule: any module with `timescale requires ALL preceding
# modules to also have one. Listing this stub first satisfies that rule
# for every file that follows (VeeR SV files have no timescale; UART/
# Interconnect .v files do – without this stub VCS throws ITSFM errors).
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/timescale.v

# ----------------- VeeR EL2 Core (el2_pkg package MUST be second) ----------------
# el2_def.sv defines el2_pkg (which contains el2_param_t struct).
# It must be compiled before any file that does 'import el2_pkg::*'
# or includes el2_param.vh (which uses el2_param_t).
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/include/el2_def.sv

# ----------------- VeeR EL2 Core (lib / packages) -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/el2_assert.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_mubi_pkg.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/el2_mem_if.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/el2_prim_generic_buf.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/el2_prim_buf.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/beh_lib.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/mem_lib.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/el2_lib.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/ahb_to_axi4.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lib/axi4_to_ahb.sv

# ----------------- VeeR EL2 Core (DMI) -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dmi/dmi_mux.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dmi/dmi_wrapper.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dmi/dmi_jtag_to_core_sync.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dmi/rvjtag_tap.v

# ----------------- VeeR EL2 Core (sub-blocks) -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_aln_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_compress_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_ifc_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_bp_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_ic_mem.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_mem_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu_iccm_mem.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/ifu/el2_ifu.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec_decode_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec_gpr_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec_ib_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec_pmp_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec_tlu_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec_trigger.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dec/el2_dec.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/exu/el2_exu_alu_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/exu/el2_exu_mul_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/exu/el2_exu_div_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/exu/el2_exu.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_clkdomain.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_addrcheck.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_lsc_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_stbuf.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_buffer.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_intf.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_ecc.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_mem.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_ctl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/lsu/el2_lsu_trigger.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/dbg/el2_dbg.sv

# ----------------- VeeR EL2 Core (top-level) -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_lockstep_pkg.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_veer_lockstep.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_mem.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_pic_ctrl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_dma_ctrl.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_pmp.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_veer.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/el2_veer_wrapper.sv

# ----------------- UART IP Core -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v

# ----------------- AXI Interconnect & Bridge -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/priority_encoder.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/arbiter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/axi_interconnect.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/axi_interconnect_wrap_2x6.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/axi_interconnect_uart_top.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/axi4_to_axilite_bridge.v

# ----------------- Top Wrapper & TB -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/veer_wrapper_uart_integrated.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/TB_files/veer_integrated_uart_adapter_tb.sv
