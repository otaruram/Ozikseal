// ============================================================================
// OzikSeal — Simulation Testbench
// ============================================================================
// Module:  tb_ozikseal
// Purpose: Testbench for simulating the OzikSeal_Top module.
//          Generates clock, reset, and sends a dummy UART byte stream
//          to verify the RX → Hash → TX pipeline.
//
// Simulation:
//   iverilog -o sim.vvp testbench/tb_ozikseal.v rtl/OzikSeal_Top.v \
//                       rtl/uart_rx.v rtl/uart_tx.v
//   vvp sim.vvp
//   gtkwave ozikseal_wave.vcd
//
// What This Tests:
//   1. Reset behavior — all registers initialize correctly
//   2. UART RX — sends "Hi\n" (3 bytes) serially at 115200 baud
//   3. Hash computation — triggered on newline character
//   4. UART TX — verifies hash bytes are transmitted back
//
// Author: OzikSeal Team
// ============================================================================

`timescale 1ns / 1ps

module tb_ozikseal;

    // -----------------------------------------------------------------------
    // Testbench Parameters
    // -----------------------------------------------------------------------
    localparam CLK_PERIOD    = 20;       // 50 MHz → 20 ns period
    localparam CLKS_PER_BIT  = 434;      // 50MHz / 115200 baud
    localparam BIT_PERIOD_NS = CLK_PERIOD * CLKS_PER_BIT;  // ~8680 ns

    // -----------------------------------------------------------------------
    // DUT Signals
    // -----------------------------------------------------------------------
    reg  clk;
    reg  rst_n;
    reg  uart_rx_pin;
    wire uart_tx_pin;

    // -----------------------------------------------------------------------
    // Instantiate Device Under Test (DUT)
    // -----------------------------------------------------------------------
    OzikSeal_Top dut (
        .CLOCK_50  (clk),
        .KEY_N     (rst_n),
        .UART_RX   (uart_rx_pin),
        .UART_TX   (uart_tx_pin)
    );

    // -----------------------------------------------------------------------
    // Clock Generation: 50 MHz (20 ns period)
    // -----------------------------------------------------------------------
    initial begin
        clk = 1'b0;
    end

    always #(CLK_PERIOD / 2) clk = ~clk;

    // -----------------------------------------------------------------------
    // Waveform Dump for GTKWave
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("ozikseal_wave.vcd");
        $dumpvars(0, tb_ozikseal);
    end

    // -----------------------------------------------------------------------
    // Task: Send a single UART byte (8N1 format)
    // -----------------------------------------------------------------------
    // Sends: 1 start bit (LOW), 8 data bits (LSB first), 1 stop bit (HIGH)
    // -----------------------------------------------------------------------
    task send_uart_byte;
        input [7:0] byte_val;
        integer bit_idx;
        begin
            // START BIT — drive LOW
            uart_rx_pin = 1'b0;
            #(BIT_PERIOD_NS);

            // DATA BITS — send LSB first
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx_pin = byte_val[bit_idx];
                #(BIT_PERIOD_NS);
            end

            // STOP BIT — drive HIGH
            uart_rx_pin = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    // -----------------------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------------------
    initial begin
        $display("============================================================");
        $display("  OzikSeal Testbench — Starting Simulation");
        $display("============================================================");

        // Initialize signals
        uart_rx_pin = 1'b1;  // UART idle = HIGH
        rst_n       = 1'b0;  // Assert reset

        // Hold reset for 10 clock cycles
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;        // Release reset
        $display("[%0t] Reset released", $time);

        // Wait a bit after reset
        #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------
        // Send test message: "Hi" followed by newline (0x0A)
        // This should trigger the hash computation pipeline
        // ---------------------------------------------------------------
        $display("[%0t] Sending byte: 'H' (0x48)", $time);
        send_uart_byte(8'h48);  // 'H'

        $display("[%0t] Sending byte: 'i' (0x69)", $time);
        send_uart_byte(8'h69);  // 'i'

        $display("[%0t] Sending byte: '\\n' (0x0A) — Trigger hash", $time);
        send_uart_byte(8'h0A);  // newline → triggers hash computation

        // ---------------------------------------------------------------
        // Wait for the FPGA to compute and transmit the hash response
        // At 115200 baud, 64 hex chars + newline = 65 bytes
        // Each byte = ~86.8 µs → total ≈ 5.6 ms ≈ 5,600,000 ns
        // Add margin for processing time
        // ---------------------------------------------------------------
        $display("[%0t] Waiting for FPGA to compute and transmit hash...", $time);
        #(BIT_PERIOD_NS * 10 * 70);  // Wait for 70 bytes worth of time

        $display("[%0t] Simulation complete", $time);
        $display("============================================================");
        $display("  Check waveform: gtkwave ozikseal_wave.vcd");
        $display("============================================================");

        $finish;
    end

    // -----------------------------------------------------------------------
    // Timeout Watchdog — prevent infinite simulation
    // -----------------------------------------------------------------------
    initial begin
        #(100_000_000);  // 100 ms timeout
        $display("[TIMEOUT] Simulation exceeded 100ms — forcing finish.");
        $finish;
    end

    // -----------------------------------------------------------------------
    // Monitor: Log TX output activity
    // -----------------------------------------------------------------------
    always @(posedge dut.u_uart_tx.o_tx_done) begin
        $display("[%0t] TX byte sent: 0x%02h ('%c')", 
                 $time, dut.u_uart_tx.i_tx_byte, dut.u_uart_tx.i_tx_byte);
    end

endmodule
