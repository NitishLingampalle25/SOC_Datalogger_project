`timescale 1ns/1ps
//=============================================================================
// aes_vip_sequences.sv
// AES VIP Sequences
//
// tc_aes_01_seq — Functional encrypt + verify
//   1. Write KEY[0..3] (FIPS-197 128-bit key, lower half)
//   2. Write TXTIN[0..3] (FIPS-197 plaintext)
//   3. Write AES_CTRL = 0x1 (START, 128-bit, encrypt)
//   4. Poll AES_STATUS until == 2 (DONE)
//   5. Read TXTOUT[0..3]
//   6. Assert each word matches FIPS-197 expected CT
//   7. Report result via scoreboard
//
// tc_aes_02_seq — Busy-write protection
//   1..3.  Same as TC_AES_01 (write KEY, PT, start engine)
//   4.     Immediately (next AXI cycle) attempt to overwrite
//          KEY[0] = 0xDEAD_BEEF and TXTIN[0] = 0xDEAD_BEEF while BUSY
//   5.     Poll AES_STATUS until == 2 (DONE)
//   6.     Read TXTOUT[0..3]
//   7.     Assert CT still matches FIPS-197 vector (writes were ignored)
//
// AES Register Map (base 0x4000_2000):
//   AES_CTRL    = base + 0x00
//   AES_STATUS  = base + 0x04
//   AES_KEY_0   = base + 0x10  (128-bit key: words 0..3 = KEY[0..3])
//   AES_KEY_1   = base + 0x14
//   AES_KEY_2   = base + 0x18
//   AES_KEY_3   = base + 0x1C
//   AES_TXTIN_0 = base + 0x30
//   AES_TXTIN_1 = base + 0x34
//   AES_TXTIN_2 = base + 0x38
//   AES_TXTIN_3 = base + 0x3C
//   AES_TXTOUT_0= base + 0x40  (read-only)
//   AES_TXTOUT_1= base + 0x44
//   AES_TXTOUT_2= base + 0x48
//   AES_TXTOUT_3= base + 0x4C
//
// FIPS-197 Test Vector (128-bit):
//   Key  = 2b7e1516_28aed2a6_abf71588_09cf4f3c
//   PT   = 6bc1bee2_2e409f96_e93d7e11_7393172a
//   CT   = 3925841d_02dc09fb_dc118597_196a0b32
//=============================================================================

//-----------------------------------------------------------------------------
// Base sequence — provides helper tasks used by both test sequences
//-----------------------------------------------------------------------------
class aes_vip_base_seq extends uvm_sequence #(aes_vip_item);

  `uvm_object_utils(aes_vip_base_seq)

  // AES register base address
  localparam bit [31:0] AES_BASE      = 32'h4000_2000;

  // Register offsets
  localparam bit [31:0] OFF_CTRL      = 32'h00;
  localparam bit [31:0] OFF_STATUS    = 32'h04;
  localparam bit [31:0] OFF_KEY_0     = 32'h10;
  localparam bit [31:0] OFF_KEY_1     = 32'h14;
  localparam bit [31:0] OFF_KEY_2     = 32'h18;
  localparam bit [31:0] OFF_KEY_3     = 32'h1C;
  localparam bit [31:0] OFF_TXTIN_0   = 32'h30;
  localparam bit [31:0] OFF_TXTIN_1   = 32'h34;
  localparam bit [31:0] OFF_TXTIN_2   = 32'h38;
  localparam bit [31:0] OFF_TXTIN_3   = 32'h3C;
  localparam bit [31:0] OFF_TXTOUT_0  = 32'h40;
  localparam bit [31:0] OFF_TXTOUT_1  = 32'h44;
  localparam bit [31:0] OFF_TXTOUT_2  = 32'h48;
  localparam bit [31:0] OFF_TXTOUT_3  = 32'h4C;

  // AES_STATUS values
  localparam bit [31:0] STATUS_IDLE   = 32'h0;
  localparam bit [31:0] STATUS_BUSY   = 32'h1;
  localparam bit [31:0] STATUS_DONE   = 32'h2;

  // AES_CTRL START bit
  localparam bit [31:0] CTRL_START    = 32'h1;  // bit0=START, bit1=MODE(0=128), bit2=DIR(0=enc)

  // FIPS-197 128-bit key words (KEY[0] = MS word)
  localparam bit [31:0] FIPS_KEY[4] = '{
    32'h2b7e_1516,
    32'h28ae_d2a6,
    32'habf7_1588,
    32'h09cf_4f3c
  };

  // FIPS-197 plaintext words
  localparam bit [31:0] FIPS_PT[4] = '{
    32'h6bc1_bee2,
    32'h2e40_9f96,
    32'he93d_7e11,
    32'h7393_172a
  };

  // FIPS-197 expected ciphertext words
  localparam bit [31:0] FIPS_CT[4] = '{
    32'h3925_841d,
    32'h02dc_09fb,
    32'hdc11_8597,
    32'h196a_0b32
  };

  // Scoreboard handle — sequences call report_ct() directly
  aes_vip_scoreboard sb;

  function new(string name = "aes_vip_base_seq");
    super.new(name);
  endfunction

  // -------------------------------------------------------------------------
  // do_write — sends a single write transaction item
  // -------------------------------------------------------------------------
  task do_write(input bit [31:0] addr, input bit [31:0] data);
    aes_vip_item item = aes_vip_item::type_id::create("wr_item");
    start_item(item);
    item.do_write = 1'b1;
    item.addr     = addr;
    item.wdata    = data;
    finish_item(item);
    `uvm_info("AES_SEQ",
      $sformatf("WRITE addr=0x%08h data=0x%08h resp=%02b",
        addr, data, item.resp),
      UVM_MEDIUM)
  endtask

  // -------------------------------------------------------------------------
  // do_read — sends a single read transaction item, returns rdata
  // -------------------------------------------------------------------------
  task do_read(input bit [31:0] addr, output bit [31:0] rdata);
    aes_vip_item item = aes_vip_item::type_id::create("rd_item");
    start_item(item);
    item.do_write = 1'b0;
    item.addr     = addr;
    finish_item(item);
    rdata = item.rdata;
    `uvm_info("AES_SEQ",
      $sformatf("READ  addr=0x%08h data=0x%08h resp=%02b",
        addr, rdata, item.resp),
      UVM_MEDIUM)
  endtask

  // -------------------------------------------------------------------------
  // poll_status — polls AES_STATUS until it equals target_status
  //   timeout_cycles: max polls before error (0 = unlimited, default 10000)
  // -------------------------------------------------------------------------
  task poll_status(
    input  bit [31:0] target_status,
    input  int        timeout_cycles = 10000
  );
    bit [31:0] status_val;
    int        count = 0;
    do begin
      do_read(AES_BASE + OFF_STATUS, status_val);
      count++;
      if (timeout_cycles > 0 && count >= timeout_cycles) begin
        `uvm_fatal("AES_SEQ",
          $sformatf("poll_status TIMEOUT after %0d reads — last status=0x%08h",
            count, status_val))
      end
    end while (status_val !== target_status);
    `uvm_info("AES_SEQ",
      $sformatf("AES_STATUS == 0x%08h after %0d poll(s)", status_val, count),
      UVM_LOW)
  endtask

  // -------------------------------------------------------------------------
  // write_key — writes FIPS KEY[0..3] to AES_KEY_0..3
  // -------------------------------------------------------------------------
  task write_key(input bit [31:0] key[4]);
    do_write(AES_BASE + OFF_KEY_0, key[0]);
    do_write(AES_BASE + OFF_KEY_1, key[1]);
    do_write(AES_BASE + OFF_KEY_2, key[2]);
    do_write(AES_BASE + OFF_KEY_3, key[3]);
  endtask

  // -------------------------------------------------------------------------
  // write_plaintext — writes FIPS PT[0..3] to AES_TXTIN_0..3
  // -------------------------------------------------------------------------
  task write_plaintext(input bit [31:0] pt[4]);
    do_write(AES_BASE + OFF_TXTIN_0, pt[0]);
    do_write(AES_BASE + OFF_TXTIN_1, pt[1]);
    do_write(AES_BASE + OFF_TXTIN_2, pt[2]);
    do_write(AES_BASE + OFF_TXTIN_3, pt[3]);
  endtask

  // -------------------------------------------------------------------------
  // read_ciphertext — reads TXTOUT[0..3] into ct[4]
  // -------------------------------------------------------------------------
  task read_ciphertext(output bit [31:0] ct[4]);
    do_read(AES_BASE + OFF_TXTOUT_0, ct[0]);
    do_read(AES_BASE + OFF_TXTOUT_1, ct[1]);
    do_read(AES_BASE + OFF_TXTOUT_2, ct[2]);
    do_read(AES_BASE + OFF_TXTOUT_3, ct[3]);
  endtask

  // -------------------------------------------------------------------------
  // check_ct — asserts each word against FIPS_CT, logs result
  // -------------------------------------------------------------------------
  function void check_ct(
    input bit [31:0] got[4],
    input string     tc_name
  );
    if (sb != null) begin
      sb.report_ct(got[0], got[1], got[2], got[3], tc_name);
    end else begin
      // Inline check when scoreboard not wired
      bit pass = (got[0] === FIPS_CT[0]) &&
                 (got[1] === FIPS_CT[1]) &&
                 (got[2] === FIPS_CT[2]) &&
                 (got[3] === FIPS_CT[3]);

      `uvm_info("AES_SEQ", $sformatf(
        "[%s] CT CHECK  Got: %08h %08h %08h %08h  Exp: %08h %08h %08h %08h  => %s",
        tc_name,
        got[0], got[1], got[2], got[3],
        FIPS_CT[0], FIPS_CT[1], FIPS_CT[2], FIPS_CT[3],
        pass ? "PASS" : "FAIL"),
        UVM_LOW)

      if (!pass)
        `uvm_error("AES_SEQ",
          $sformatf("[%s] Ciphertext mismatch!", tc_name))
    end
  endfunction

endclass : aes_vip_base_seq


//=============================================================================
// TC_AES_01 — Encrypt and verify ciphertext
//=============================================================================
class tc_aes_01_seq extends aes_vip_base_seq;

  `uvm_object_utils(tc_aes_01_seq)

  function new(string name = "tc_aes_01_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] ct[4];

    `uvm_info("AES_SEQ", "========== TC_AES_01 START ==========", UVM_LOW)

    // ------------------------------------------------------------------
    // Step 1: Write FIPS-197 128-bit key into KEY[0..3]
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 1: Writing KEY[0..3]", UVM_LOW)
    write_key(FIPS_KEY);

    // ------------------------------------------------------------------
    // Step 2: Write FIPS-197 plaintext into TXTIN[0..3]
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 2: Writing TXTIN[0..3]", UVM_LOW)
    write_plaintext(FIPS_PT);

    // ------------------------------------------------------------------
    // Step 3: Start AES engine (AES_CTRL = 0x1 → START, 128-bit, encrypt)
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 3: Writing AES_CTRL = 0x1 (START)", UVM_LOW)
    do_write(AES_BASE + OFF_CTRL, CTRL_START);

    // ------------------------------------------------------------------
    // Step 4: Poll AES_STATUS until DONE (== 2)
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 4: Polling STATUS until DONE", UVM_LOW)
    poll_status(STATUS_DONE);

    // ------------------------------------------------------------------
    // Step 5: Read back TXTOUT[0..3]
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 5: Reading TXTOUT[0..3]", UVM_LOW)
    read_ciphertext(ct);

    // ------------------------------------------------------------------
    // Step 6: Assert each word matches FIPS CT and report
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 6: Checking ciphertext against FIPS-197", UVM_LOW)
    check_ct(ct, "TC_AES_01");

    `uvm_info("AES_SEQ", "========== TC_AES_01 END ==========", UVM_LOW)
  endtask

endclass : tc_aes_01_seq


//=============================================================================
// TC_AES_02 — Busy-write protection test
//=============================================================================
class tc_aes_02_seq extends aes_vip_base_seq;

  `uvm_object_utils(tc_aes_02_seq)

  function new(string name = "tc_aes_02_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] ct[4];

    `uvm_info("AES_SEQ", "========== TC_AES_02 START ==========", UVM_LOW)

    // ------------------------------------------------------------------
    // Step 1: Write FIPS-197 key
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 1: Writing KEY[0..3] (FIPS-197)", UVM_LOW)
    write_key(FIPS_KEY);

    // ------------------------------------------------------------------
    // Step 2: Write FIPS-197 plaintext
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 2: Writing TXTIN[0..3] (FIPS-197)", UVM_LOW)
    write_plaintext(FIPS_PT);

    // ------------------------------------------------------------------
    // Step 3: Start AES engine
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 3: Writing AES_CTRL = 0x1 (START)", UVM_LOW)
    do_write(AES_BASE + OFF_CTRL, CTRL_START);

    // ------------------------------------------------------------------
    // Step 4: Immediately attempt to corrupt KEY[0] and TXTIN[0] while BUSY
    // The DUT's busy-write protection must silently ignore these writes.
    // We don't poll for busy first — we fire immediately to maximize the
    // chance of hitting the engine mid-computation.
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ",
      "Step 4: Attempting spurious writes (KEY[0]=0xDEADBEEF, TXTIN[0]=0xDEADBEEF) while BUSY",
      UVM_LOW)
    do_write(AES_BASE + OFF_KEY_0,   32'hDEAD_BEEF);
    do_write(AES_BASE + OFF_TXTIN_0, 32'hDEAD_BEEF);

    // ------------------------------------------------------------------
    // Step 5: Wait for AES_STATUS == DONE
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 5: Polling STATUS until DONE", UVM_LOW)
    poll_status(STATUS_DONE);

    // ------------------------------------------------------------------
    // Step 6: Read back TXTOUT[0..3]
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ", "Step 6: Reading TXTOUT[0..3]", UVM_LOW)
    read_ciphertext(ct);

    // ------------------------------------------------------------------
    // Step 7: Assert CT still matches FIPS vector (spurious writes ignored)
    // ------------------------------------------------------------------
    `uvm_info("AES_SEQ",
      "Step 7: Verifying CT matches FIPS-197 (busy-write protection check)",
      UVM_LOW)
    check_ct(ct, "TC_AES_02");

    `uvm_info("AES_SEQ", "========== TC_AES_02 END ==========", UVM_LOW)
  endtask

endclass : tc_aes_02_seq
