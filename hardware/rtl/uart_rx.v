// ============================================================================
// OzikSeal — UART Receiver Module
// ============================================================================
// Module:  uart_rx
// Purpose: Receives serial data from the host PC via UART protocol.
//          Converts serial bitstream into parallel 8-bit bytes.
//
// Configuration:
//   - Baud Rate:  115200 bps (configurable via CLKS_PER_BIT parameter)
//   - Data Bits:  8
//   - Stop Bits:  1
//   - Parity:     None
//   - Flow Ctrl:  None
//
// Protocol Timing (115200 baud @ 50MHz clock):
//   CLKS_PER_BIT = 50,000,000 / 115,200 ≈ 434 clock cycles per bit
//
//   ┌─────┐     ┌───┐───┐───┐───┐───┐───┐───┐───┐     ┌─────┐
//   │ IDLE│START│ D0│ D1│ D2│ D3│ D4│ D5│ D6│ D7│STOP │ IDLE│
//   │  1  │  0  │   │   │   │   │   │   │   │   │  1  │  1  │
//   └─────┘     └───┘───┘───┘───┘───┘───┘───┘───┘     └─────┘
//
// Author: OzikSeal Team
// ============================================================================

module uart_rx #(
    parameter CLKS_PER_BIT = 434    // 50MHz / 115200 baud = ~434
)(
    input  wire       i_clk,        // System clock (50 MHz)
    input  wire       i_rst_n,      // Active-low synchronous reset
    input  wire       i_rx_serial,  // Serial input from UART line
    output reg  [7:0] o_rx_byte,    // Received parallel byte
    output reg        o_rx_valid    // Pulses HIGH for 1 clock when byte ready
);

    // -----------------------------------------------------------------------
    // State Machine States
    // -----------------------------------------------------------------------
    localparam STATE_IDLE  = 3'b000;  // Waiting for start bit
    localparam STATE_START = 3'b001;  // Validating start bit
    localparam STATE_DATA  = 3'b010;  // Receiving 8 data bits
    localparam STATE_STOP  = 3'b011;  // Validating stop bit
    localparam STATE_DONE  = 3'b100;  // Output valid byte

    // -----------------------------------------------------------------------
    // Internal Registers
    // -----------------------------------------------------------------------
    reg [2:0]  r_state;              // Current FSM state
    reg [15:0] r_clk_count;          // Clock counter for bit timing
    reg [2:0]  r_bit_index;          // Current bit index (0-7)
    reg [7:0]  r_rx_byte;           // Shift register for incoming bits

    // -----------------------------------------------------------------------
    // Double-register the incoming serial signal to avoid metastability
    // -----------------------------------------------------------------------
    reg r_rx_sync_0;
    reg r_rx_sync_1;

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_rx_sync_0 <= 1'b1;
            r_rx_sync_1 <= 1'b1;
        end else begin
            r_rx_sync_0 <= i_rx_serial;
            r_rx_sync_1 <= r_rx_sync_0;
        end
    end

    // -----------------------------------------------------------------------
    // UART RX State Machine
    // -----------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            // Reset all registers to default
            r_state     <= STATE_IDLE;
            r_clk_count <= 16'd0;
            r_bit_index <= 3'd0;
            r_rx_byte   <= 8'd0;
            o_rx_byte   <= 8'd0;
            o_rx_valid  <= 1'b0;
        end else begin
            // Default: valid flag is only high for one cycle
            o_rx_valid <= 1'b0;

            case (r_state)

                // -----------------------------------------------------------
                // IDLE: Wait for the start bit (falling edge → logic LOW)
                // -----------------------------------------------------------
                STATE_IDLE: begin
                    r_clk_count <= 16'd0;
                    r_bit_index <= 3'd0;

                    if (r_rx_sync_1 == 1'b0) begin
                        // Detected potential start bit → move to validation
                        r_state <= STATE_START;
                    end
                end

                // -----------------------------------------------------------
                // START: Sample at the middle of the start bit to confirm
                // -----------------------------------------------------------
                STATE_START: begin
                    if (r_clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        // We're at the midpoint of the start bit
                        if (r_rx_sync_1 == 1'b0) begin
                            // Confirmed start bit → begin data reception
                            r_clk_count <= 16'd0;
                            r_state     <= STATE_DATA;
                        end else begin
                            // False alarm (glitch) → back to idle
                            r_state <= STATE_IDLE;
                        end
                    end else begin
                        r_clk_count <= r_clk_count + 16'd1;
                    end
                end

                // -----------------------------------------------------------
                // DATA: Sample each of the 8 data bits at their midpoints
                // -----------------------------------------------------------
                STATE_DATA: begin
                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 16'd1;
                    end else begin
                        // Midpoint reached — sample the bit (LSB first)
                        r_clk_count          <= 16'd0;
                        r_rx_byte[r_bit_index] <= r_rx_sync_1;

                        if (r_bit_index < 3'd7) begin
                            r_bit_index <= r_bit_index + 3'd1;
                        end else begin
                            // All 8 bits received → check stop bit
                            r_bit_index <= 3'd0;
                            r_state     <= STATE_STOP;
                        end
                    end
                end

                // -----------------------------------------------------------
                // STOP: Wait for the stop bit (logic HIGH)
                // -----------------------------------------------------------
                STATE_STOP: begin
                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 16'd1;
                    end else begin
                        // Stop bit period complete → output the byte
                        r_clk_count <= 16'd0;
                        r_state     <= STATE_DONE;
                    end
                end

                // -----------------------------------------------------------
                // DONE: Assert valid flag for one clock cycle
                // -----------------------------------------------------------
                STATE_DONE: begin
                    o_rx_byte  <= r_rx_byte;
                    o_rx_valid <= 1'b1;
                    r_state    <= STATE_IDLE;
                end

                default: r_state <= STATE_IDLE;

            endcase
        end
    end

endmodule
