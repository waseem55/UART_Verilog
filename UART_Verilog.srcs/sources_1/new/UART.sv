/*--------------------------------------------------------------------------------
Author: Waseem Orphali 
Create Date: 06/20/2020
Module Name: UART
Project Name: UART_Verilog
Target Devices: Artix A7
Description: 
This module takes a data element as input, it gets latched when o_tx_rdy is 1 and 
i_tx_dv is pulsed, the module then sends the data element on the UART TX line.
The module outputs any data element recieved from RX line and pulses the o_rx_dv port.

    Parameter            possible Values                    Default
    Baud Rate            (9600, 19200, 115200, others)      115200
    Number of Data Bits  (7, 8, others)                     8
    Parity Bit           Off                                OFF
    Stop Bits            1                                  1
    Flow Control         None                               None

--------------------------------------------------------------------------------*/


module UART #(

//--------------------- Timing parameters ----------------------
// BAUD_RATE: bits per second
// CLK_FREQ: input clk frequency Hz
// HALF_CLKS_PER_BIT: used to sample at middle of bit for maximum stability 

    parameter BAUD_RATE         = 115200,
    parameter CLK_FREQ          = 100_000_000,
    parameter CLKS_PER_BIT      = CLK_FREQ / BAUD_RATE,     // = 868 for default values
    parameter HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2,         // = 434 for default values
    parameter ELEMENT_SIZE      = 8,                        // data transaction size
    parameter BIT_INDEX_SIZE    = 3,                        // 2^3 = ELEMENT SIZE

//----------------------- FSM states --------------------------
    parameter IDLE          = 3'b000,
    parameter START_BIT     = 3'b001,
    parameter DATA_BITS     = 3'b010,
    parameter STOP_BIT      = 3'b011,
    parameter CLEANUP       = 3'b100
    )

//--------------------------- Ports ------------------------------
    (
    input               i_clk,
    input               i_rx,                               // RX line
    output  wire [ELEMENT_SIZE-1:0]  o_rx_data,             // data element received from RX line
    output  reg         o_rx_dv,                            // pulsed for 1 cycle when an element is received
    output  reg         o_tx,                               // TX line
    input       [ELEMENT_SIZE-1:0]   i_tx_data,             // data element to be sent on TX line
    input               i_tx_dv,                            // should be pulsed once to start TX operation when the module is ready
    output  reg         o_tx_rdy                            // set to 1 when not busy sending a data element, 0 otherwise
    );
    
    reg [2:0] rx_state      = 0;
    reg [2:0] tx_state      = 0;
    
//---------------------- RX State Machine Signals ----------------------    
    reg [BIT_INDEX_SIZE-1:0] rx_bit_index   = 0;
    reg [9:0]                rx_clk_count   = 0;
    reg [ELEMENT_SIZE-1:0]   rx_data        = 0;
    reg                      rx_dv          = 0;

//---------------------- TX State Machine Signals ----------------------    
    reg [BIT_INDEX_SIZE-1:0] tx_bit_index   = 0;
    reg [9:0]                tx_clk_count   = 0;
    reg [ELEMENT_SIZE-1:0]   tx_data        = 0;
    reg                      tx             = 1;
    reg                      tx_rdy         = 0;
    
//------------------------- RX Operation -------------------------------
        
    always @(posedge i_clk) begin
        rx_dv <= 0;
        
        case (rx_state)
            
            IDLE: begin             // wait for start bit
                rx_bit_index <= 0;
                rx_clk_count <= 0;
                if (~i_rx)
                    rx_state <= START_BIT;
                else
                    rx_state <= IDLE;
            end
            
            START_BIT: begin        // check the start bit
                if (rx_clk_count < HALF_CLKS_PER_BIT-1) begin
                    rx_clk_count <= rx_clk_count + 1;
                    rx_state <= START_BIT;
                end
                else begin
                    rx_clk_count <= 0;
                    if (~i_rx)
                        rx_state <= DATA_BITS;
                    else
                        rx_state <= IDLE;
                end
            end
            
            DATA_BITS: begin        // receive data bits
                if (rx_clk_count < CLKS_PER_BIT-1) begin
                    rx_clk_count <= rx_clk_count + 1;
                    rx_state <= DATA_BITS;
                end
                else begin
                    rx_clk_count <= 0;
                    rx_data[rx_bit_index] <= i_rx;
                    if (rx_bit_index < ELEMENT_SIZE-1) begin
                        rx_bit_index <= rx_bit_index + 1;
                        rx_state <= DATA_BITS;
                    end
                    else begin
                        rx_dv <= 1;
                        rx_bit_index <= 0;
                        rx_state <= STOP_BIT;
                    end
                end 
            end
            
            STOP_BIT: begin         // wait for stop bit
                if (rx_clk_count < CLKS_PER_BIT-1) begin
                    rx_clk_count <= rx_clk_count + 1;
                    rx_state <= STOP_BIT;
                end
                else begin
                    rx_clk_count <= 0;
                    rx_state <= CLEANUP;
                end
            end
            
            CLEANUP: begin          // stay here for 1 clk cycle
                rx_state <= IDLE;
            end
            
            default:
                rx_state <= IDLE;
                
        endcase
    end
    
    assign o_rx_data = rx_data;
    assign o_rx_dv   = rx_dv;
    
//------------------------- TX Operation -------------------------------
    
    always @(posedge i_clk) begin
        tx_rdy <= 0;
        
        case(tx_state)
        
            IDLE: begin             // tx_rdy is set to 1, wait for tx_dv
                tx_bit_index <= 0;
                tx_clk_count <= 0;
                tx <= 1;
                tx_rdy <= 1;
                if (i_tx_dv) begin
                    tx_rdy <= 0;
                    tx <= 0;
                    tx_data <= i_tx_data;
                    tx_state <= START_BIT;
                end
                else
                    tx_state <= IDLE;
            end
            
            START_BIT: begin        // sending start bit
                if (tx_clk_count < CLKS_PER_BIT -1) begin
                    tx_clk_count <= tx_clk_count + 1;
                    tx_state <= START_BIT;
                    tx <= 0;
                end
                else begin
                    tx_clk_count <= 0;
                    tx_state <= DATA_BITS;
                    tx <= tx_data[0];
                end
            end
            
            DATA_BITS: begin        // sending data bits
                tx <= tx_data[tx_bit_index];
                if (tx_clk_count < CLKS_PER_BIT -1) begin
                    tx_clk_count <= tx_clk_count + 1;
                    tx_state <= DATA_BITS;
                end
                else begin
                    tx_clk_count <= 0;
                    if (tx_bit_index < ELEMENT_SIZE-1) begin
                        tx_bit_index <= tx_bit_index + 1;
                        tx_state <= DATA_BITS;
                    end
                    else begin
                        tx_bit_index <= 0;
                        tx_state <= STOP_BIT;
                        tx <= 1;
                    end
                end
            end
            
            STOP_BIT: begin         // sending stop bit
                tx <= 1;
                if (tx_clk_count < CLKS_PER_BIT -1) begin
                    tx_clk_count <= tx_clk_count + 1;
                    tx_state <= STOP_BIT;
                end
                else begin
                    tx_clk_count <= 0;
                    tx_state <= CLEANUP;
                end
            end
            
            CLEANUP: begin          // set o_tx to idle at 1 and go back to IDLE state
                tx <= 1;
                tx_state <= IDLE;
            end
            
            default:
                tx_state <= IDLE;
        endcase
    end      
    
    assign o_tx = tx;
    assign o_tx_rdy = tx_rdy;
endmodule
