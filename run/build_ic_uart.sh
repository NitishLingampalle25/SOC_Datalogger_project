#!/bin/bash
# =============================================================================
# build_ic_uart.sh  —  Clean compile + simulate for AXI Interconnect + UART
# Run from:  /home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/run/
# Usage   :  bash build_ic_uart.sh
# =============================================================================

set -e   # stop on first error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================================"
echo " Step 1: Removing stale build artefacts"
echo "============================================================"
rm -f  simv_ic_uart
rm -f  compile.log
rm -f  sim.log
rm -f  tb_interconnect_uart.vcd
rm -rf simv_ic_uart.daidir
rm -rf csrc_ic_uart

echo "============================================================"
echo " Step 2: Compiling"
echo "============================================================"
vcs -full64 -sverilog \
    -l compile.log \
    -Mdir csrc_ic_uart \
    -f run_interconnect_uart.f \
    -o simv_ic_uart \
    +lint=TFIPC-L

COMPILE_ERRORS=$(grep -cE "^Error" compile.log 2>/dev/null || true)
COMPILE_WARNS=$(grep -cE "^Warning" compile.log 2>/dev/null || true)

echo ""
echo "------------------------------------------------------------"
echo " Compile result:  Errors = $COMPILE_ERRORS  Warnings = $COMPILE_WARNS"
echo "------------------------------------------------------------"

if [ "$COMPILE_ERRORS" -gt 0 ]; then
    echo " COMPILATION FAILED — see compile.log for details"
    grep "^Error" compile.log
    exit 1
fi

echo ""
echo "============================================================"
echo " Step 3: Running simulation"
echo "============================================================"
./simv_ic_uart -l sim.log

echo ""
echo "------------------------------------------------------------"
echo " Simulation finished — see sim.log"
echo "------------------------------------------------------------"
