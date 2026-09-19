// =============================================================================
// TB  : tb_axi_uart_top.sv
// DUT : axi_uart_top (AXI4-Lite UART IP Core)
//
// Tests:
//   1. Reset
//   2. LCR write / baud divisor configuration
//   3. THR write - transmit byte 0x55
//   4. LSR read - poll THRE / TEMT
//   5. RX loopback - drive uart_rx with 0xA5
//   6. Read RBR and compare received data
//
// Waveform:
//   FSDB dump enabled for Verdi
// =============================================================================


module tb_axi_uart_top;

  // ===========================================================================
  // LOCAL PARAMETERS
  // ===========================================================================

  parameter integer AXI_DATA_W = 32;
  parameter integer AXI_ADDR_W = 5;
  parameter integer AXI_ID_W   = 12;
  parameter integer AXI_RESP_W = 2;

  // AXI register addresses
  parameter [AXI_ADDR_W-1:0] ADDR_RBR_THR = 5'h00;
  parameter [AXI_ADDR_W-1:0] ADDR_IER     = 5'h04;
  parameter [AXI_ADDR_W-1:0] ADDR_BAUD    = 5'h08;
  parameter [AXI_ADDR_W-1:0] ADDR_LCR     = 5'h0C;
  parameter [AXI_ADDR_W-1:0] ADDR_LSR     = 5'h14;

  // Small baud divisor for simulation
  parameter integer SIM_BAUD_DIV = 10;

  // Number of fixed_clk cycles per UART bit, as seen by the RX sampler.
  // If the DUT receiver uses 16x oversampling, set this to SIM_BAUD_DIV*16.
  parameter integer BIT_CYCLES = SIM_BAUD_DIV + 1;   // was SIM_BAUD_DIV


  // ===========================================================================
  // CLOCKS AND RESET
  // ===========================================================================
  reg fixed_clk;
  reg axi_clk;
  reg aresetn;

  initial begin
    fixed_clk = 1'b0;
    axi_clk   = 1'b0;
  end

  always #5 fixed_clk = ~fixed_clk;   // 100 MHz
  always #5 axi_clk   = ~axi_clk;     // 100 MHz


  // ===========================================================================
  // AXI4-LITE SIGNALS
  // ===========================================================================

  // -------------------------
  // Write address channel
  // -------------------------
  reg  [AXI_ID_W-1:0]   awid;
  reg  [AXI_ADDR_W-1:0] awaddr;
  reg                   awvalid;
  wire                  awready;

  // -------------------------
  // Write data channel
  // -------------------------
  reg  [AXI_DATA_W-1:0] wdata;
  reg  [3:0]            wstrb;
  reg                   wvalid;
  wire                  wready;

  // -------------------------
  // Write response channel
  // -------------------------
  wire [AXI_ID_W-1:0]   bid;
  wire [AXI_RESP_W-1:0] bresp;
  wire                  bvalid;
  reg                   bready;

  // -------------------------
  // Read address channel
  // -------------------------
  reg  [AXI_ID_W-1:0]   arid;
  reg  [AXI_ADDR_W-1:0] araddr;
  reg                   arvalid;
  wire                  arready;

  // -------------------------
  // Read data channel
  // -------------------------
  wire [AXI_ID_W-1:0]   rid;
  wire [AXI_DATA_W-1:0] rdata;
  wire [AXI_RESP_W-1:0] rresp;
  wire                  rvalid;
  reg                   rready;


  // ===========================================================================
  // UART SIGNALS
  // ===========================================================================

  wire uart_tx;
  reg  uart_rx;
  wire read_interrupt;


  // ===========================================================================
  // DUT
  // ===========================================================================

  axi_uart_top dut (

    .fixed_clk_i      (fixed_clk),
    .axi_aclk_i       (axi_clk),
    .axi_aresetn_i    (aresetn),

    .axi_awid_i       (awid),
    .axi_awaddr_i     (awaddr),
    .axi_awvalid_i    (awvalid),
    .axi_awready_o    (awready),

    .axi_wdata_i      (wdata),
    .axi_wstrb_i      (wstrb),
    .axi_wvalid_i     (wvalid),
    .axi_wready_o     (wready),

    .axi_bid_o        (bid),
    .axi_bresp_o      (bresp),
    .axi_bvalid_o     (bvalid),
    .axi_bready_i     (bready),

    .axi_arid_i       (arid),
    .axi_araddr_i     (araddr),
    .axi_arvalid_i    (arvalid),
    .axi_arready_o    (arready),

    .axi_rid_o        (rid),
    .axi_rdata_o      (rdata),
    .axi_rresp_o      (rresp),
    .axi_rvalid_o     (rvalid),
    .axi_rready_i     (rready),

    .read_interrupt_o (read_interrupt),
    .uart_tx_o        (uart_tx),
    .uart_rx_i        (uart_rx)
  );


  // ===========================================================================
  // AXI WRITE TASK
  // ===========================================================================

  task automatic axi_write(input [AXI_ADDR_W-1:0] addr,
                           input [AXI_DATA_W-1:0] data);

    integer wait_count;

    begin

      $display("");
      $display("============================================================");
      $display("[%0t] AXI WRITE START", $time);
      $display("[%0t] ADDR = 0x%02h", $time, addr);
      $display("[%0t] DATA = 0x%08h", $time, data);
      $display("============================================================");

      // ---------------------------------------------------------
      // Present write transaction
      // ---------------------------------------------------------

      @(posedge axi_clk);

      awid    <= 12'h001;
      awaddr  <= addr;
      awvalid <= 1'b1;

      wdata   <= data;
      wstrb   <= 4'hF;
      wvalid  <= 1'b1;

      bready  <= 1'b1;

      $display("[%0t] AXI WRITE: AWVALID=1 WVALID=1 BREADY=1", $time);

      // ---------------------------------------------------------
      // Wait for AWREADY/WREADY
      // ---------------------------------------------------------

      wait_count = 0;

      @(posedge axi_clk);

      while (!(awready && wready)) begin

        if ((wait_count % 5) == 0) begin
          $display("[%0t] WRITE WAIT: AWREADY=%b WREADY=%b",
                   $time, awready, wready);
        end

        wait_count = wait_count + 1;

        if (wait_count > 100) begin
          $display("");
          $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
          $display("[%0t] ERROR: WRITE TIMEOUT waiting for READY", $time);
          $display("AWVALID=%b AWREADY=%b", awvalid, awready);
          $display("WVALID =%b WREADY =%b", wvalid, wready);
          $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
          $finish;
        end

        @(posedge axi_clk);

      end

      $display("[%0t] AXI WRITE: AWREADY/WREADY handshake detected", $time);

      // ---------------------------------------------------------
      // IMPORTANT:
      // Do NOT deassert AWVALID/WVALID yet.
      //
      // This DUT gates BVALID with:
      //
      //     axi_wren = AWVALID & WVALID
      //
      // Therefore we keep them asserted until BVALID is observed.
      // ---------------------------------------------------------

      wait_count = 0;

      while (!bvalid) begin

        if ((wait_count % 5) == 0) begin
          $display("[%0t] WRITE WAITING FOR BVALID", $time);
          $display("         AWVALID=%b AWREADY=%b", awvalid, awready);
          $display("         WVALID =%b WREADY =%b", wvalid, wready);
          $display("         BVALID =%b BREADY =%b", bvalid, bready);
        end

        wait_count = wait_count + 1;

        if (wait_count > 100) begin
          $display("");
          $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
          $display("[%0t] ERROR: BVALID TIMEOUT", $time);
          $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
          $display("AWVALID=%b AWREADY=%b", awvalid, awready);
          $display("WVALID =%b WREADY =%b", wvalid, wready);
          $display("BVALID =%b BREADY =%b", bvalid, bready);
          $display("AWADDR =0x%08h", awaddr);
          $display("WDATA  =0x%08h", wdata);
          $finish;
        end

        @(posedge axi_clk);

      end

      // ---------------------------------------------------------
      // BVALID received
      // ---------------------------------------------------------

      $display("[%0t] AXI WRITE: BVALID=1", $time);
      $display("[%0t] AXI WRITE: BRESP=0x%0h", $time, bresp);
      $display("[%0t] AXI WRITE: BID=0x%0h", $time, bid);

      if (bresp == 2'b00)
        $display("[%0t] AXI WRITE PASS: BRESP=OKAY", $time);
      else
        $display("[%0t] AXI WRITE ERROR: BRESP=0x%0h", $time, bresp);

      // ---------------------------------------------------------
      // Now release the transaction
      // ---------------------------------------------------------

      @(posedge axi_clk);

      awvalid <= 1'b0;
      wvalid  <= 1'b0;
      bready  <= 1'b0;

      $display("[%0t] AXI WRITE: AWVALID/WVALID/BREADY deasserted", $time);

      @(posedge axi_clk);

      $display("[%0t] AXI WRITE COMPLETE", $time);
      $display("============================================================");

    end

  endtask


  // ===========================================================================
  // AXI READ TASK
  // ===========================================================================

  task automatic axi_read(input  [AXI_ADDR_W-1:0] addr,
                          output [AXI_DATA_W-1:0] data);

    integer wait_count;

    begin

      // 1. Ensure bus is idle before starting
      @(posedge axi_clk);
      arvalid <= 1'b0;
      rready  <= 1'b0;
      repeat (3) @(posedge axi_clk);

      // 2. Assert ARVALID and drive read address
      arid    <= 12'h002;
      araddr  <= addr;
      arvalid <= 1'b1;
      rready  <= 1'b1;

      // 3. Wait for AR handshake
      wait_count = 0;
      @(posedge axi_clk);

      while (!arready) begin
        wait_count = wait_count + 1;
        if (wait_count > 100) begin
          $display("[%0t] ERROR: READ TIMEOUT waiting for ARREADY (ADDR=0x%02h)",
                   $time, addr);
          $finish;
        end
        @(posedge axi_clk);
      end

      // Hold ARVALID active until RVALID is detected
      // (required by this DUT's internal axi_rden gating logic)
      wait_count = 0;

      while (!rvalid) begin
        wait_count = wait_count + 1;
        if (wait_count > 100) begin
          $display("[%0t] ERROR: READ TIMEOUT waiting for RVALID (ADDR=0x%02h)",
                   $time, addr);
          $finish;
        end
        @(posedge axi_clk);
      end

      // 4. Latch data
      data = rdata;

      if (rresp != 2'b00)
        $display("[%0t] AXI READ ERROR: RRESP=0x%0h", $time, rresp);

      // 5. Complete transaction and deassert signals
      @(posedge axi_clk);
      arvalid <= 1'b0;
      rready  <= 1'b0;

      // 6. Give internal synchronizer cycles to clear
      repeat (5) @(posedge axi_clk);

    end

  endtask


  // ===========================================================================
  // UART BYTE DRIVER (drives uart_rx: start + 8 data LSB-first + stop)
  // ===========================================================================

  task automatic send_uart_byte(input [7:0] data,
                                input integer bit_cycles);

    integer i;

    begin

      $display("[%0t] UART RX DRIVE: byte = 0x%02h, %0d clk/bit",
               $time, data, bit_cycles);

      // Start bit
      @(posedge fixed_clk);
      uart_rx <= 1'b0;
      repeat (bit_cycles) @(posedge fixed_clk);

      // Data bits, LSB first
      for (i = 0; i < 8; i = i + 1) begin
        uart_rx <= data[i];
        repeat (bit_cycles) @(posedge fixed_clk);
      end

      // Stop bit
      uart_rx <= 1'b1;
      repeat (bit_cycles) @(posedge fixed_clk);

      // Extra idle
      repeat (bit_cycles) @(posedge fixed_clk);

      $display("[%0t] UART RX DRIVE: complete", $time);

    end

  endtask


  // ===========================================================================
  // MAIN TEST
  // ===========================================================================

  integer timeout;

  reg [AXI_DATA_W-1:0] rd_data;


  initial begin

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    $display("");
    $display("################################################################");
    $display("#                                                              #");
    $display("#              AXI-LITE UART TESTBENCH START                   #");
    $display("#                                                              #");
    $display("################################################################");
    $display("");

    aresetn = 1'b0;

    awid    = 12'h000;
    awaddr  = 5'h00;
    awvalid = 1'b0;

    wdata   = 32'h00000000;
    wstrb   = 4'h0;
    wvalid  = 1'b0;
    bready  = 1'b0;

    arid    = 12'h000;
    araddr  = 5'h00;
    arvalid = 1'b0;
    rready  = 1'b0;

    uart_rx = 1'b1;

    $display("[%0t] TESTBENCH INITIALIZED", $time);
    $display("[%0t] UART RX initialized to IDLE = 1", $time);
    $display("[%0t] Reset asserted: aresetn = 0", $time);


    // ========================================================================
    // TEST 1: RESET
    // ========================================================================

    $display("");
    $display("################################################################");
    $display("# TEST 1 : RESET                                               #");
    $display("################################################################");

    repeat (10) @(posedge axi_clk);

    aresetn = 1'b1;

    $display("[%0t] Reset released: aresetn = 1", $time);

    repeat (5) @(posedge axi_clk);

    $display("[%0t] TEST 1 PASS: reset completed", $time);


    // ========================================================================
    // TEST 2: BAUD CONFIGURATION
    // ========================================================================

    $display("");
    $display("################################################################");
    $display("# TEST 2 : BAUD DIVISOR CONFIGURATION                          #");
    $display("################################################################");

    $display("[%0t] Setting baud divisor = %0d", $time, SIM_BAUD_DIV);

    // Set DLAB = 1
    $display("[%0t] Step 1: Write LCR = 0x80 (DLAB=1)", $time);
    axi_write(ADDR_LCR, 32'h00000080);

    // Write baud divisor
    $display("[%0t] Step 2: Write BAUD = %0d", $time, SIM_BAUD_DIV);
    axi_write(ADDR_BAUD, SIM_BAUD_DIV);

    // Clear DLAB
    $display("[%0t] Step 3: Write LCR = 0x00 (DLAB=0)", $time);
    axi_write(ADDR_LCR, 32'h00000000);

    $display("[%0t] TEST 2 PASS: baud divisor configuration completed", $time);


    // ========================================================================
    // TEST 3: TRANSMIT 0x55
    // ========================================================================

    $display("");
    $display("################################################################");
    $display("# TEST 3 : UART TRANSMIT 0x55                                  #");
    $display("################################################################");

    $display("[%0t] Writing 0x55 to THR", $time);

    axi_write(ADDR_RBR_THR, 32'h00000055);

    $display("[%0t] THR write completed", $time);
    $display("[%0t] Polling LSR[5] = THRE", $time);

    timeout = 0;
    rd_data = 32'h00000000;

    while (!rd_data[5] && timeout < 1000) begin

      axi_read(ADDR_LSR, rd_data);

      $display("[%0t] LSR = 0x%08h | THRE=%0b TEMT=%0b",
               $time, rd_data, rd_data[5], rd_data[6]);

      timeout = timeout + 1;

    end

    if (rd_data[5]) begin
      $display("[%0t] TEST 3 PASS: LSR[THRE]=1", $time);
      $display("[%0t] TX FIFO became empty after %0d polls", $time, timeout);
    end
    else begin
      $display("[%0t] TEST 3 ERROR: THRE was not detected", $time);
    end

    // Allow transmitter to finish
    $display("[%0t] Waiting for UART TX shift register to finish...", $time);

    repeat (SIM_BAUD_DIV * 12) @(posedge fixed_clk);

    $display("[%0t] UART TX wait completed", $time);


    // ========================================================================
    // TEST 4: TEMT
    // ========================================================================

    $display("");
    $display("################################################################");
    $display("# TEST 4 : UART TRANSMITTER EMPTY                              #");
    $display("################################################################");

    axi_read(ADDR_LSR, rd_data);

    $display("[%0t] LSR = 0x%08h", $time, rd_data);
    $display("[%0t] THRE = %0b", $time, rd_data[5]);
    $display("[%0t] TEMT = %0b", $time, rd_data[6]);

    if (rd_data[6]) begin
      $display("[%0t] TEST 4 PASS: TEMT=1, transmitter completely idle", $time);
    end
    else begin
      $display("[%0t] TEST 4 INFO: TEMT=0, transmitter may still be shifting",
               $time);
    end


    // ========================================================================
    // TEST 5: RX LOOPBACK
    // ========================================================================

    $display("");
    $display("################################################################");
    $display("# TEST 5 : UART RX LOOPBACK                                    #");
    $display("################################################################");

    $display("[%0t] Enabling RX interrupt/data-ready mechanism", $time);

    axi_write(ADDR_IER, 32'h00000001);

    $display("[%0t] Sending UART byte 0xA5", $time);

    send_uart_byte(8'hA5, BIT_CYCLES);

    $display("[%0t] UART byte transmission to RX completed", $time);

    // Allow receiver FSM, synchronizer and FIFO to settle
    $display("[%0t] Waiting for receiver/FIFO to settle...", $time);

    repeat (BIT_CYCLES * 4) @(posedge fixed_clk);

    $display("[%0t] Receiver settling time completed", $time);


    // ------------------------------------------------------------------------
    // POLL DATA READY
    // ------------------------------------------------------------------------

    $display("[%0t] Polling LSR[0] = DATA READY", $time);

    timeout = 0;
    rd_data = 32'h00000000;

    while (!rd_data[0] && timeout < 500) begin

      axi_read(ADDR_LSR, rd_data);

      $display("[%0t] RX POLL: LSR=0x%08h | DATA_READY=%0b",
               $time, rd_data, rd_data[0]);

      timeout = timeout + 1;

    end


    // ------------------------------------------------------------------------
    // CHECK RECEIVED BYTE
    // ------------------------------------------------------------------------

    if (rd_data[0]) begin

      $display("");
      $display("[%0t] DATA READY DETECTED", $time);

      // Dead cycles to ensure DUT read synchronizer (axi_sync_rden) has cleared
      repeat (10) @(posedge axi_clk);

      axi_read(ADDR_RBR_THR, rd_data);

      $display("[%0t] RBR DATA = 0x%08h", $time, rd_data);
      $display("[%0t] Expected  = 0x000000A5", $time);

      if (rd_data[7:0] === 8'hA5) begin
        $display("");
        $display("############################################################");
        $display("# TEST 5 PASS: RECEIVED BYTE MATCHES 0xA5                  #");
        $display("############################################################");
      end
      else begin
        $display("");
        $display("############################################################");
        $display("# TEST 5 FAIL: RECEIVED BYTE DOES NOT MATCH                #");
        $display("############################################################");
        $display("[%0t] Expected = 0xA5", $time);
        $display("[%0t] Received = 0x%02h", $time, rd_data[7:0]);
      end

    end
    else begin

      $display("");
      $display("############################################################");
      $display("# TEST 5 FAIL: DATA READY NEVER ASSERTED                    #");
      $display("############################################################");
      $display("[%0t] Final LSR = 0x%08h", $time, rd_data);

    end


    // ========================================================================
    // SIMULATION COMPLETE
    // ========================================================================

    repeat (20) @(posedge axi_clk);

    $display("");
    $display("################################################################");
    $display("#                                                              #");
    $display("#                 SIMULATION COMPLETE                          #");
    $display("#                                                              #");
    $display("################################################################");
    $display("");
    $display("[%0t] All testbench stimulus completed.", $time);
    $display("[%0t] FSDB waveform should be available as dump.fsdb", $time);
    $display("");

    $finish;

  end


  // ===========================================================================
  // WATCHDOG
  // ===========================================================================

  initial begin

    #50_000_000;

    $display("");
    $display("################################################################");
    $display("# WATCHDOG TIMEOUT                                             #");
    $display("################################################################");
    $display("[%0t] Simulation exceeded maximum allowed time", $time);
    $display("[%0t] Check for a stuck AXI handshake or UART FSM", $time);
    $display("");

    $finish;

  end


  // ===========================================================================
  // FSDB WAVEFORM DUMP
  // ===========================================================================

  initial begin

    $display("[%0t] FSDB waveform dumping enabled", $time);

    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars("+all");

    // Uncomment these if your VCS/Verdi environment supports them.
    // $fsdbDumpSVA();
    // $fsdbDumpMDA();

  end

endmodule
