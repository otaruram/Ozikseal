// ============================================================================
// OzikSeal — UART Transmitter Module
// ============================================================================
// Module:  uart_tx
// Purpose: Transmits parallel 8-bit bytes as serial UART data back to
//          the host PC. Used to send the SHA-256 hash result.
//
// Configuration:
//   - Baud Rate:  115200 bps (configurable via CLKS_PER_BIT parameter)
//   - Data Bits:  8
//   - Stop Bits:  1
//   - Parity:     None
//
// Interface:
//   To transmit a byte, assert i_tx_valid HIGH for one clock cycle with
//   the byte on i_tx_byte. The module will serialize and transmit it.
//   o_tx_active goes HIGH during transmission. o_tx_done pulses when done.
//
// Author: OzikSeal Team
// ============================================================================

module uart_tx #(
    parameter CLKS_PER_BIT = 434    // 50MHz / 115200 baud = ~434
)(
    input  wire       i_clk,        // System clock (50 MHz)
    input  wire       i_rst_n,      // Active-low synchronous reset
    input  wire       i_tx_valid,   // Pulse HIGH to start transmission
    input  wire [7:0] i_tx_byte,    // Byte to transmit
    output reg        o_tx_serial,  // Serial output to UART line
    output reg        o_tx_active,  // HIGH while transmitting
    output reg        o_tx_done     // Pulses HIGH for 1 clock when done
);

    // -----------------------------------------------------------------------
    // State Machine States
    // -----------------------------------------------------------------------
    localparam STATE_IDLE  = 3'b000;  // Line idle (HIGH)
    localparam STATE_START = 3'b001;  // Sending start bit (LOW)
    localparam STATE_DATA  = 3'b010;  // Sending 8 data bits (LSB first)
    localparam STATE_STOP  = 3'b011;  // Sending stop bit (HIGH)
    localparam STATE_DONE  = 3'b100;  // Transmission complete

    // -----------------------------------------------------------------------
    // Internal Registers
    // -----------------------------------------------------------------------
    reg [2:0]  r_state;              // Current FSM state
    reg [15:0] r_clk_count;          // Clock counter for bit timing
    reg [2:0]  r_bit_index;          // Current bit index (0-7)
    reg [7:0]  r_tx_byte;           // Latched copy of byte to transmit

    // -----------------------------------------------------------------------
    // UART TX State Machine
    // -----------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            // Reset: idle state, line HIGH
            r_state     <= STATE_IDLE;
            r_clk_count <= 16'd0;
            r_bit_index <= 3'd0;
            r_tx_byte   <= 8'd0;
            o_tx_serial <= 1'b1;    // UART idle = HIGH
            o_tx_active <= 1'b0;
            o_tx_done   <= 1'b0;
        end else begin
            // Default: done flag is only high for one cycle
            o_tx_done <= 1'b0;

            case (r_state)

                // -----------------------------------------------------------
                // IDLE: Wait for transmission request
                // -----------------------------------------------------------
                STATE_IDLE: begin
                    o_tx_serial <= 1'b1;    // Line idle = HIGH
                    o_tx_active <= 1'b0;
                    r_clk_count <= 16'd0;
                    r_bit_index <= 3'd0;

                    if (i_tx_valid == 1'b1) begin
                        // Latch the byte and begin transmission
                        r_tx_byte   <= i_tx_byte;
                        o_tx_active <= 1'b1;
                        r_state     <= STATE_START;
                    end
                end

                // -----------------------------------------------------------
                // START: Send start bit (LOW) for one bit period
                // -----------------------------------------------------------
                STATE_START: begin
                    o_tx_serial <= 1'b0;    // Start bit = LOW

                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 16'd1;
                    end else begin
                        r_clk_count <= 16'd0;
                        r_state     <= STATE_DATA;
                    end
                end

                // -----------------------------------------------------------
                // DATA: Send 8 data bits, LSB first
                // -----------------------------------------------------------
                STATE_DATA: begin
                    o_tx_serial <= r_tx_byte[r_bit_index];

                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 16'd1;
                    end else begin
                        r_clk_count <= 16'd0;

                        if (r_bit_index < 3'd7) begin
                            r_bit_index <= r_bit_index + 3'd1;
                        end else begin
                            // All 8 bits sent → send stop bit
                            r_bit_index <= 3'd0;
                            r_state     <= STATE_STOP;
                        end
                    end
                end

                // -----------------------------------------------------------
                // STOP: Send stop bit (HIGH) for one bit period
                // -----------------------------------------------------------
                STATE_STOP: begin
                    o_tx_serial <= 1'b1;    // Stop bit = HIGH

                    if (r_clk_count < CLKS_PER_BIT - 1) begin
                        r_clk_count <= r_clk_count + 16'd1;
                    end else begin
                        r_clk_count <= 16'd0;
                        r_state     <= STATE_DONE;
                    end
                end

                // -----------------------------------------------------------
                // DONE: Signal completion, return to idle
                // -----------------------------------------------------------
                STATE_DONE: begin
                    o_tx_done   <= 1'b1;
                    o_tx_active <= 1'b0;
                    r_state     <= STATE_IDLE;
                end

                default: r_state <= STATE_IDLE;

            endcase
        end
    end

endmodule
