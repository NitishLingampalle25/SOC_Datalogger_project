-sverilog
+define+RV_BUILD_AXI4
# RV_PHYSICAL strips out the generate-if width-check guards in beh_lib.sv
# (rvdffiee, rvdfflie, rvdffpcie).  Without it VCS elaborates the else-branch
# $error() even when the condition is satisfied, causing EEST at elaboration.
+define+RV_PHYSICAL

# ----------------- Include Directories -----------------
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/include
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/snapshots/default
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Cores-VeeR-EL2/design/include
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/inc

# ----------------- VeeR EL2 Core (el2_pkg package MUST be first) -----------------
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
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v

# ----------------- AES IP Core -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes/aes_rcon.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes/aes_sbox.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes/aes_inv_sbox.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes/aes_key_expand_128.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes/aes_cipher_top.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes/aes_inv_cipher_top.v

# ----------------- AES VeeR Adapter (32-to-128 bit AXI4 bridge) -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/aes_veer_adapter.v

# ----------------- DMA Controller (packages first, then RTL) -----------------
# Packages must precede the modules that import them
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/inc/amba_axi_pkg.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/inc/dma_utils_pkg.sv

# rggen register-file primitives (csr_dma.v is generated from these)
# +incdir covers rggen_rtl_macros.vh and rggen_clog2.vh used by csr_dma.v
+incdir+/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_mux.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_or_reducer.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_address_decoder.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_adapter_common.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_axi4lite_skid_buffer.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_axi4lite_bridge.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_axi4lite_adapter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_bit_field.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_bit_field_w01trg.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_bit_field_counter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_register_common.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_default_register.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_external_register.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_indirect_register.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/rggen-verilog-rtl/rggen_maskable_register.v

# Generated CSR register file (instantiates rggen primitives above)
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/csr_dma.v

# DMA functional RTL
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/dma_fifo.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/dma_fsm.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/dma_streamer.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/dma_axi_if.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/dma_func_wrapper.sv
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/DMA/dma_axi_wrapper.sv

# ----------------- AXI Interconnect & Bridge -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/priority_encoder.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/arbiter.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/axi_interconnect.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/Interconnect/axi_interconnect_wrap_2x6.v
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/axi4_to_axilite_bridge.v

# ----------------- SoC Top-Level: VeeR2 + DMA + AES + UART Integrated -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/RTL_files/veer2_dma_aes_uart.v

# ----------------- Testbench -----------------
/home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/TB_files/veer2_dma_aes_uart_tb.sv
