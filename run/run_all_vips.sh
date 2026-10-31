#!/bin/tcsh -f
# =============================================================================
# run_all_vips.sh  —  Compile and run each VIP testbench independently
# Usage: cd run/  &&  tcsh run_all_vips.sh
# =============================================================================

set BASE  = /home/student/Documents/SOC_Datalogger_project/TB_files/UVM_Arch_Files
set PLI   = /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64
set UVM   = /home/student/snps_tools_target/vcs/U-2023.03/etc/uvm-1.2
setenv LD_LIBRARY_PATH ${PLI}:${LD_LIBRARY_PATH}

set VIPS  = (uart dma gpio systimer wdt)
set PASS  = 0
set FAIL  = 0

foreach vip ($VIPS)
    echo ""
    echo "============================================================"
    echo " Compiling: ${vip}_vip"
    echo "============================================================"

    vcs -full64 -sverilog \
        -ntb_opts uvm-1.2 \
        -debug_access+all -kdb \
        -timescale=1ns/1ps \
        -P ${PLI}/novas.tab \
        -LDFLAGS -L${PLI} \
        -lnovas \
        +incdir+${UVM} \
        +incdir+${BASE}/${vip}_vip_uvm_tb \
        ${BASE}/${vip}_vip_uvm_tb/${vip}_vip_if.sv \
        ${BASE}/${vip}_vip_uvm_tb/${vip}_vip_pkg.sv \
        ${BASE}/${vip}_vip_uvm_tb/tb_top.sv \
        -o simv_${vip}_vip \
        -l compile_${vip}_vip.log

    if ($status != 0) then
        echo "*** COMPILE FAILED: ${vip}_vip ***"
        @ FAIL++
        continue
    endif

    echo ""
    echo "------------------------------------------------------------"
    echo " Simulating: ${vip}_vip_test"
    echo "------------------------------------------------------------"

    ./simv_${vip}_vip +UVM_TESTNAME=${vip}_vip_test \
                      +UVM_VERBOSITY=UVM_MEDIUM \
                      -l sim_${vip}_vip.log

    # Only fail if UVM_ERROR or UVM_FATAL count is non-zero
    set errs = `grep -E "UVM_ERROR\s*:\s*[1-9]|UVM_FATAL\s*:\s*[1-9]" sim_${vip}_vip.log | wc -l`
    if ($errs > 0) then
        echo "*** SIM FAILED: ${vip}_vip ***"
        @ FAIL++
    else
        echo "==> PASS: ${vip}_vip"
        @ PASS++
    endif
end

echo ""
echo "============================================================"
echo " RESULTS:  PASS=$PASS   FAIL=$FAIL"
echo "============================================================"
