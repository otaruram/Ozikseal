// ============================================================================
// OzikSeal — Top-Level FPGA Wrapper
// ============================================================================
// Module:  OzikSeal_Top
// Purpose: Top-level design for the DE10-Nano FPGA board. Integrates:
//          1. UART RX — receives claim payload bytes from host PC
//          2. SHA-256 Core — computes cryptographic hash (TT07 baseline)
//          3. UART TX — transmits the 64-char hex hash back to host PC
//
// Data Flow:
//   ┌──────────┐    byte    ┌───────────────┐   hash    ┌──────────┐
//   │ UART RX  │ ────────► │ SHA-256 Core   │ ───────► │ UART TX  │
//   │ (serial) │           │ (TT07 Peruri)  │          │ (serial) │
//   └──────────┘           └───────────────┘           └──────────┘
//
// Protocol:
//   - Host sends UTF-8 payload bytes terminated by newline (0x0A).
//   - FPGA accumulates bytes, feeds them to SHA-256 on newline.
//   - FPGA transmits the 64-character hex digest followed by newline.
//
// Pin Mapping (DE10-Nano):
//   CLOCK_50  → PIN_V11   (50 MHz oscillator)
//   KEY[0]    → PIN_AH17  (Active-low reset button)
//   UART_RX   → PIN_AG13  (GPIO_0[0] — USB-UART RX)
//   UART_TX   → PIN_AF13  (GPIO_0[1] — USB-UART TX)
//
// Author: OzikSeal Team
// ============================================================================

module OzikSeal_Top (
    input  wire CLOCK_50,       // 50 MHz system clock
    input  wire KEY_N,          // Active-low reset (directly active-low)
    input  wire UART_RX,        // Serial input from host
    output wire UART_TX         // Serial output to host
);

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam CLKS_PER_BIT = 434;      // 50MHz / 115200 baud
    localparam MAX_MSG_LEN  = 512;      // Max payload length in bytes
    localparam HASH_HEX_LEN = 64;       // SHA-256 hex digest length

    // -----------------------------------------------------------------------
    // Internal Signals
    // -----------------------------------------------------------------------

    // Reset (active-high derived from active-low push button)
    wire w_rst_n = KEY_N;

    // UART RX interface
    wire [7:0] w_rx_byte;
    wire       w_rx_valid;

    // UART TX interface
    reg        r_tx_valid;
    reg  [7:0] r_tx_byte;
    wire       w_tx_active;
    wire       w_tx_done;

    // Message buffer — accumulates incoming payload bytes
    reg [7:0]  r_msg_buffer [0:MAX_MSG_LEN-1];
    reg [9:0]  r_msg_index;              // Current write position

    // SHA-256 computation (simplified inline for demo)
    // In production, this would instantiate the TT07 SHA-256 hard IP core.
    // For this boilerplate, we use a simple hash accumulator to demonstrate
    // the data flow. Replace with: tt07_sha256 sha_core (...) ;
    reg [255:0] r_hash_result;
    reg         r_hash_ready;

    // TX state machine for sending the 64-char hex response
    reg [6:0]  r_tx_hex_index;           // 0..63 hex chars + newline
    reg        r_tx_sending;
    reg [2:0]  r_tx_state;

    localparam TX_IDLE    = 3'd0;
    localparam TX_SEND    = 3'd1;
    localparam TX_WAIT    = 3'd2;
    localparam TX_NEWLINE = 3'd3;
    localparam TX_DONE    = 3'd4;

    // -----------------------------------------------------------------------
    // UART RX Instance
    // -----------------------------------------------------------------------
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_rx (
        .i_clk        (CLOCK_50),
        .i_rst_n      (w_rst_n),
        .i_rx_serial  (UART_RX),
        .o_rx_byte    (w_rx_byte),
        .o_rx_valid   (w_rx_valid)
    );

    // -----------------------------------------------------------------------
    // UART TX Instance
    // -----------------------------------------------------------------------
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_tx (
        .i_clk        (CLOCK_50),
        .i_rst_n      (w_rst_n),
        .i_tx_valid   (r_tx_valid),
        .i_tx_byte    (r_tx_byte),
        .o_tx_serial  (UART_TX),
        .o_tx_active  (w_tx_active),
        .o_tx_done    (w_tx_done)
    );

    // -----------------------------------------------------------------------
    // Helper Function: Convert 4-bit nibble to ASCII hex character
    // -----------------------------------------------------------------------
    function [7:0] nibble_to_hex;
        input [3:0] nibble;
        begin
            if (nibble < 4'd10)
                nibble_to_hex = 8'h30 + {4'd0, nibble};  // '0' - '9'
            else
                nibble_to_hex = 8'h61 + {4'd0, nibble} - 8'd10;  // 'a' - 'f'
        end
    endfunction

    // -----------------------------------------------------------------------
    // RX Path: Accumulate bytes and trigger hash on newline
    // -----------------------------------------------------------------------
    // NOTE: The hash computation below is a STRUCTURAL PLACEHOLDER.
    // In the actual DE10-Nano deployment, this section is replaced with
    // the instantiation of the Peruri TT07 SHA-256 hardware IP core:
    //
    //   tt07_sha256 sha_core (
    //       .clk      (CLOCK_50),
    //       .rst_n    (w_rst_n),
    //       .data_in  (message_block),
    //       .start    (hash_trigger),
    //       .hash_out (r_hash_result),
    //       .done     (r_hash_ready)
    //   );
    //
    // The placeholder below uses a simple XOR-shift accumulation to
    // demonstrate the complete data flow through UART RX → processing → TX.
    // -----------------------------------------------------------------------
    integer i;

    always @(posedge CLOCK_50) begin
        if (!w_rst_n) begin
            r_msg_index  <= 10'd0;
            r_hash_result <= 256'd0;
            r_hash_ready  <= 1'b0;
        end else begin
            r_hash_ready <= 1'b0;

            if (w_rx_valid) begin
                if (w_rx_byte == 8'h0A) begin
                    // Newline received → trigger hash computation
                    // Placeholder: XOR-shift accumulation of buffered bytes
                    // This generates a deterministic 256-bit result from input
                    r_hash_result <= 256'd0;
                    for (i = 0; i < MAX_MSG_LEN; i = i + 1) begin
                        if (i[9:0] < r_msg_index) begin
                            r_hash_result <= r_hash_result ^ 
                                ({248'd0, r_msg_buffer[i]} << ((i % 32) * 8));
                        end
                    end
                    r_hash_ready <= 1'b1;
                    r_msg_index  <= 10'd0;
                end else if (r_msg_index < MAX_MSG_LEN) begin
                    // Store byte in message buffer
                    r_msg_buffer[r_msg_index] <= w_rx_byte;
                    r_msg_index <= r_msg_index + 10'd1;
                end
            end
        end
    end

    // -----------------------------------------------------------------------
    // TX Path: Serialize the 256-bit hash as 64 ASCII hex chars + newline
    // -----------------------------------------------------------------------
    wire [3:0] w_current_nibble;
    // Hash is transmitted MSB-first: nibble index 0 = hash[255:252]
    assign w_current_nibble = r_hash_result[255 - (r_tx_hex_index * 4) -: 4];

    always @(posedge CLOCK_50) begin
        if (!w_rst_n) begin
            r_tx_state     <= TX_IDLE;
            r_tx_hex_index <= 7'd0;
            r_tx_sending   <= 1'b0;
            r_tx_valid     <= 1'b0;
            r_tx_byte      <= 8'd0;
        end else begin
            r_tx_valid <= 1'b0;  // Default: deassert valid

            case (r_tx_state)

                TX_IDLE: begin
                    r_tx_hex_index <= 7'd0;
                    if (r_hash_ready) begin
                        r_tx_state   <= TX_SEND;
                        r_tx_sending <= 1'b1;
                    end
                end

                TX_SEND: begin
                    if (!w_tx_active) begin
                        // Load the next hex character and trigger TX
                        r_tx_byte  <= nibble_to_hex(w_current_nibble);
                        r_tx_valid <= 1'b1;
                        r_tx_state <= TX_WAIT;
                    end
                end

                TX_WAIT: begin
                    if (w_tx_done) begin
                        if (r_tx_hex_index < HASH_HEX_LEN - 1) begin
                            r_tx_hex_index <= r_tx_hex_index + 7'd1;
                            r_tx_state     <= TX_SEND;
                        end else begin
                            // All 64 hex chars sent → send newline
                            r_tx_state <= TX_NEWLINE;
                        end
                    end
                end

                TX_NEWLINE: begin
                    if (!w_tx_active) begin
                        r_tx_byte  <= 8'h0A;  // Newline character
                        r_tx_valid <= 1'b1;
                        r_tx_state <= TX_DONE;
                    end
                end

                TX_DONE: begin
                    if (w_tx_done) begin
                        r_tx_sending <= 1'b0;
                        r_tx_state   <= TX_IDLE;
                    end
                end

                default: r_tx_state <= TX_IDLE;

            endcase
        end
    end

endmodule
