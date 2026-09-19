# TCAS SOC Project – Error Log
## Project: TCAS_SOC_project (Nitish_161 | Sem 7)
---

## Format
Each entry records: error code, description, root cause, fix applied, and
which files were touched.

---

## Error Log

---

### [E001] — 2026-09-19 | Session 1

**Tool:** VCS (Synopsys VCS simulation compiler)
**Error Code:** `NTSFM` — No `timescale for module

**Full Message (representative):**
```
Error-[NTSFM] No `timescale for module
/home/.../axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v, 27
  Module "axi_internal_fifo" does not have `timescale but previous module(s) do.
```

**Affected Modules:**
- `axi_internal_fifo`
- `uart_controller`
- `uart_parity_bit_compute`
- `uart_receiver`
- `uart_transmitter`
- `axi_uart_top`

**Root Cause:**
The UART IP source files (from `axi-lite_uart-ipcore-develop/src/rtl/`) do not
contain an explicit `` `timescale `` directive.  
VCS policy: if *any* previously-compiled module in the session has a
`` `timescale `` (the AXI interconnect files do), then all subsequent modules
that omit it trigger `NTSFM`.

**Fix Applied:**
- Created a shared timescale stub: `RTL_files/timescale.v`
  ```verilog
  `timescale 1ns / 1ps
  ```
- Listed this stub as the **first** source file in `run/run_interconnect_uart.f`,
  before any other RTL file. VCS propagates this timescale to all subsequent
  modules that lack their own.

**Files Modified:**
- `RTL_files/timescale.v` — **Created** (new stub)
- `run/run_interconnect_uart.f` — Updated to list `timescale.v` first

**Decision:** Upstream IP files were NOT modified. This is intentional — the
stub approach is non-invasive and preserves the original IP.

---

### [E002] — 2026-09-19 | Session 1

**Tool:** VCS (Synopsys VCS simulation compiler)
**Error Code:** `SVS` — SystemVerilog construct in non-SV mode

**Full Message:**
```
Error-[SVS] SystemVerilog construct
/home/.../TB_files/tb_interconnect_uart.sv, 462
tb_interconnect_uart
  Unsized literal constants are only supported in SystemVerilog.
  You must use SystemVerilog mode to enable support for this feature.
```

**Affected File:** `TB_files/tb_interconnect_uart.sv`, line 462

**Root Cause:**
The zero initialisation `rd = '0` uses the SV *unsized literal* syntax.
Even though the filelist uses `-sverilog`, VCS reported this as an error
during parsing because the `.sv` compile mode was not consistently applied
at that point.

The SV unsized zero literal `'0` is only valid in full SystemVerilog mode.
The plain Verilog equivalent is an explicit replicated constant.

**Fix Applied:**
Replaced the SV-only syntax with standard Verilog:
```verilog
// Before (SV only):
rd = '0;

// After (Verilog-compatible):
rd = {DATA_W{1'b0}};
```

**Files Modified:**
- `TB_files/tb_interconnect_uart.sv` — line 462, one occurrence replaced

---

*Log maintained by Kiro AI assistant. Append new entries as errors are encountered.*

---

### [E003] — 2026-09-19 | Session 1 (follow-up)

**Tool:** VCS (Synopsys VCS simulation compiler)
**Error Code:** `NTSFM` — persistent after stub-file approach

**Full Message (representative):**
```
Error-[NTSFM] No `timescale for module
.../axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v, 27
  Module "axi_internal_fifo" does not have `timescale but previous module(s) do.
```
(Same error repeated for all 6 UART source files.)

**Root Cause (revised from E001):**
The previous fix (a separate `timescale.v` stub listed first in the filelist)
did not work because **VCS resets the timescale context at every file
boundary**. A `timescale directive in one file does NOT carry into the next
file. The directive must be present physically inside each source file.

**Fix Applied:**
Added `` `timescale 1ns / 1ps `` directly into each of the 6 UART IP source
files, inserted on the line immediately before their `` `default_nettype none ``
directive (line 21 in every file).

Pattern replaced in each file:
```verilog
// Before:
 * -----------------------------------------------------------------------------*/

`default_nettype none

// After:
 * -----------------------------------------------------------------------------*/

`timescale 1ns / 1ps
`default_nettype none
```

**Verified by:**
```
grep -n "timescale" .../axi-lite_uart-ipcore-develop/src/rtl/*.v
```
Output confirmed `timescale 1ns / 1ps` at line 21 in all 6 files.

**Files Modified:**
- `axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v`
- `axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v`
- `axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v`
- `axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v`
- `axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v`
- `axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v`

**Lesson learned:** Never rely on a separate timescale stub file in VCS.
Always embed `timescale inside every source file that needs it.

---

*Log maintained by Kiro AI assistant. Append new entries as errors are encountered.*

---

### [E004] — 2026-09-19 | Session 1

**Tool:** VCS
**Error Code / Warning:** `TFIPC` — Too few instance port connections

**Full Message:**
```
Warning-[TFIPC] Too few instance port connections
/home/.../RTL_files/axi_interconnect_uart_top.v, 386
  The above instance has fewer port connections than the module definition.
```

**Affected Instance:** `u_interconnect` (axi_interconnect_wrap_2x6)

**Root Cause:**
The m01–m05 tie-off section in the instantiation only connected the
**input** ports of the master interfaces (awready, wready, bid, bresp,
bvalid, arready, rid, rdata, rresp, rlast, rvalid). The interconnect
wrapper also has **output** ports on those master channels (awid, awaddr,
awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awuser,
awvalid, wdata, wstrb, wlast, wuser, wvalid, bready, arid, araddr, arlen,
arsize, arburst, arlock, arcache, arprot, arqos, arregion, aruser, arvalid,
rready) — 32 outputs per master port — which were all missing from the port map.

**Fix Applied:**
- Removed the separate tieoff wire declarations and assign statements for
  m01–m05 from the module body.
- In the instantiation port map, connected all **output** ports of m01–m05
  to `()` (open/undriven — safe since the outputs are simply discarded).
- Connected all **input** ports of m01–m05 with inline literals directly:
  ready signals → `1'b1`, valid/data/id signals → `0`, rlast → `1'b1`.

**Files Modified:**
- `RTL_files/axi_interconnect_uart_top.v`

---

### [E005] — 2026-09-19 | Session 1

**Tool:** VCS
**Error Code:** `SIOB` (Warning) + `NMCM` (Error)

**Full Messages:**
```
Warning-[SIOB] Select index out of bounds
  "s_axi_awid[11:0]"  — declared bounds [7:0]

Error-[NMCM] Negative multiconcat multiplier
  Source info: {(ID_WIDTH - 12) {1'b0}}
```
(Same pair repeated for s_axi_arid / rid.)

**Affected File:** `RTL_files/axi4_to_axilite_bridge.v`

**Root Cause:**
The bridge was instantiated with `IC_ID_WIDTH = 8` (the interconnect ID
width). The bridge code assumed `ID_WIDTH ≥ 12` (the UART's fixed 12-bit
ID width) and tried to:
- Slice `s_axi_awid[11:0]` — but the signal is only `[7:0]` → out of bounds.
- Pad with `{(ID_WIDTH-12){1'b0}}` — `8-12 = -4` → negative replication → illegal.

**Fix Applied:**
Changed the direction of the width conversion:
```verilog
// Before (wrong — assumed IC ID >= 12):
assign m_axi_awid = s_axi_awid[11:0];         // OOB
assign s_axi_bid  = {{(ID_WIDTH-12){1'b0}}, m_axi_bid};  // negative mult

// After (correct — IC ID < 12, zero-pad upward):
assign m_axi_awid = {{(12-ID_WIDTH){1'b0}}, s_axi_awid};  // pad 8→12
assign s_axi_bid  = m_axi_bid[ID_WIDTH-1:0];               // truncate 12→8
```
Same pattern applied to arid/rid.

**Files Modified:**
- `RTL_files/axi4_to_axilite_bridge.v`

---

### [E006] — 2026-09-19 | Session 1

**Tool:** VCS
**Error Code:** `UST` — Undefined System Task Call

**Full Messages:**
```
Error-[UST] Undefined System Task Call
  tb_interconnect_uart.sv, 259 — '$fsdbDumpfile'
Error-[UST] Undefined System Task Call
  tb_interconnect_uart.sv, 260 — '$fsdbDumpvars'
```

**Root Cause:**
`$fsdbDumpfile` and `$fsdbDumpvars` are Verdi/FSDB-specific PLI tasks that
require the Novas/Verdi PLI library to be loaded at compile time
(`-debug_access` or explicit `-P novas.tab`). Without those flags they
are unknown system tasks and cause hard errors.

The TB had a conditional block:
```verilog
`ifdef VCS
  $fsdbDumpfile(...);
  $fsdbDumpvars(...);
`else
  $dumpfile(...);
  $dumpvars(...);
`endif
```
VCS defines the `VCS` macro by default, so the `ifdef` branch always took
the fsdb path — but the PLI library was not loaded.

**Fix Applied:**
Removed the `ifdef` block entirely. Replaced with unconditional standard
VCD dump calls that work with plain VCS and do not require any extra PLI:
```verilog
initial begin
  $dumpfile("tb_interconnect_uart.vcd");
  $dumpvars(0, tb_interconnect_uart);
end
```

**Files Modified:**
- `TB_files/tb_interconnect_uart.sv`

---

*Log maintained by Kiro AI assistant. Append new entries as errors are encountered.*

---

### [E007] — 2026-09-19 | Session 1 (runtime)

**Tool:** VCS Simulation Runtime
**Type:** Runtime `$error` + `$finish` — not a compile error

**Full Message:**
```
Error: ".../axi_interconnect.v", 231: tb_interconnect_uart.dut.u_interconnect.axi_interconnect_inst
Error: address width out of range (instance ...)
$finish called from file "axi_interconnect.v", line 232.
```

**Root Cause:**
`axi_interconnect.v` performs a runtime sanity check at time 0:
```verilog
if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || ...))
```
The interconnect **requires all non-zero address widths ≥ 12 bits** (4 KB
minimum aperture). `M00_ADDR_WIDTH` was set to `32'd5` (32 bytes — the
UART's actual register span), which is less than the minimum of 12.

**Fix Applied:**
Changed `M00_ADDR_WIDTH` from `32'd5` to `32'd12` in the interconnect
instantiation inside `axi_interconnect_uart_top.v`.

The UART IP (`axi_uart_top`) only decodes the lower 5 address bits
internally — giving it a 12-bit aperture in the address map simply means
addresses `[BASE+32 .. BASE+4095]` are unused / return SLVERR, which is
correct behaviour for a peripheral with a small register file.

The `UART_BASE_ADDR = 0x4000_0000` is already naturally aligned to far
more than 12 bits (it is 256 MB aligned), so no base address change was
needed.

**Files Modified:**
- `RTL_files/axi_interconnect_uart_top.v` — line 265: `M00_ADDR_WIDTH` 5 → 12

---

### [E008] — 2026-09-19 | Session 1 (usability)

**Issue:** Error and warning counts not visible after compilation

**Root Cause:**
The compile command did not include a `-l` (log) flag. VCS prints
all messages to stdout which can scroll off the screen. Without a log
file there is also no easy way to `grep` for counts.

**Fix Applied:**
Updated `run/run_interconnect_uart.f` comment header to document the
recommended compile command with `-l compile.log`:
```bash
vcs -full64 -sverilog -l compile.log -f run_interconnect_uart.f -o simv_ic_uart
```

After compiling, check error and warning counts with:
```bash
grep -cE "^Error"   compile.log
grep -cE "^Warning" compile.log
```

---

*Log maintained by Kiro AI assistant. Append new entries as errors are encountered.*

---

### [E007 — Follow-up] — 2026-09-19

**Issue:** Same runtime error persists after fix

**Root Cause:**
The `simv_ic_uart` binary was a stale artefact from the previous compile
(before `M00_ADDR_WIDTH` was changed from `32'd5` to `32'd12`). Running
`./simv_ic_uart` directly re-executes the old binary without picking up
the source change.

**Fix Applied:**
Created `run/build_ic_uart.sh` — a shell script that:
1. Removes stale `simv_ic_uart`, `compile.log`, `sim.log`, VCD, and csrc
   directories before every build.
2. Compiles with `vcs -full64 -sverilog -l compile.log +lint=TFIPC-L`.
3. Prints exact Error and Warning counts after compile.
4. Runs simulation only if compile succeeded.

**How to use from now on:**
```bash
cd /home/student/Nitish_161_SOC_sem7/TCAS_SOC_project/run
bash build_ic_uart.sh
```

---

*Log maintained by Kiro AI assistant.*
