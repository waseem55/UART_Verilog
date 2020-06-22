/*--------------------------------------------------------------------------------
Author: Waseem Orphali 
Create Date: 06/20/2020
Module Name: UART
Project Name: UART_Verilog
Target Devices: Artix A7
Description: 
This module takes one byte as input and sends it on the
UART TX line when input DV is pulsed and outputs the
byte recieved from RX line and pulses the output DV.
Baud rate is a parameter

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
    parameter CLEANUP       = 3'b100)

//--------------------------- Ports ------------------------------
    (
    input               i_clk,
    input               i_rx,
    output  reg [ELEMENT_SIZE-1:0]   o_rx_data,
    output  reg         o_rx_dv,
    output  reg         o_tx,
    input       [ELEMENT_SIZE-1:0]   i_tx_data,
    input               i_tx_dv,
    output  reg         o_tx_rdy
    );
    
    reg [2:0] rx_state      = 0;
    reg [2:0] tx_state      = 0;
    
//---------------------- RX State Machine Signals ----------------------    
    reg [BIT_INDEX_SIZE-1:0] rx_bit_index   = 0;
    reg [9:0]                rx_clk_count   = 0;
    reg [ELEMENT_SIZE-1:0]   rx_data        = 0;

//---------------------- TX State Machine Signals ----------------------    
    reg [BIT_INDEX_SIZE-1:0] tx_bit_index   = 0;
    reg [9:0]                tx_clk_count   = 0;
    reg [ELEMENT_SIZE-1:0]   tx_data        = 0;
    
//------------------------- RX Operation -------------------------------
        
    always @(posedge i_clk) begin
        o_rx_dv <= 0;
        
        case (rx_state)
            
            IDLE: begin
                rx_bit_index <= 0;
                rx_clk_count <= 0;
                rx_data <= 0;
                if (~i_rx)
                    rx_state <= START_BIT;
                else
                    rx_state <= IDLE;
            end
            
            START_BIT: begin
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
            
            DATA_BITS: begin
                if (rx_clk_count < CLKS_PER_BIT-1) begin
                    rx_clk_count <= rx_clk_count + 1;
                    rx_state <= DATA_BITS;
                end
                else begin
                    rx_clk_count <= 0;
                    rx_data[rx_bit_index] <= i_rx;
                    if (rx_bit_index < BIT_INDEX_SIZE-1) begin
                        rx_bit_index <= rx_bit_index + 1;
                        rx_state <= DATA_BITS;
                    end
                    else begin
                        o_rx_dv <= 1;
                        o_rx_data <= rx_data;
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
    
    
//------------------------- TX Operation -------------------------------
    
    always @(posedge i_clk) begin
        o_tx_rdy <= 0;
        
        case(tx_state)
        
            IDLE: begin
                tx_bit_index <= 0;
                tx_clk_count <= 0;
                o_tx <= 1;
                o_tx_rdy <= 1;
                if (i_tx_dv) begin
                    o_tx_rdy <= 0;
                    o_tx <= 0;
                    tx_data <= i_tx_data;
                    tx_state <= START_BIT;
                end
                else
                    tx_state <= IDLE;
            end
            
            START_BIT: begin
                if (tx_clk_count < CLKS_PER_BIT -1) begin
                    tx_clk_count <= tx_clk_count + 1;
                    tx_state <= START_BIT;
                    o_tx <= 0;
                end
                else begin
                    tx_clk_count <= 0;
                    tx_state <= DATA_BITS;
                    o_tx <= tx_data[0];
                end
            end
            
            DATA_BITS: begin
                o_tx <= tx_data[tx_bit_index];
                if (tx_clk_count < CLKS_PER_BIT -1) begin
                    tx_clk_count <= tx_clk_count + 1;
                    tx_state <= DATA_BITS;
                end
                else begin
                    tx_clk_count <= 0;
                    if (tx_bit_index < BIT_INDEX_SIZE-1) begin
                        tx_bit_index <= tx_bit_index + 1;
                        tx_state <= DATA_BITS;
                    end
                    else begin
                        tx_bit_index <= 0;
                        tx_state <= STOP_BIT;
                        o_tx <= 1;
                    end
                end
            end
            
            STOP_BIT: begin
                o_tx <= 1;
                if (tx_clk_count < CLKS_PER_BIT -1) begin
                    tx_clk_count <= tx_clk_count + 1;
                    tx_state <= STOP_BIT;
                end
                else begin
                    tx_clk_count <= 0;
                    tx_state <= CLEANUP;
                end
            end
            
            CLEANUP: begin
                o_tx <= 1;
                tx_state <= IDLE;
            end
            
            default:
                tx_state <= IDLE;
        endcase
    end      
    
endmodule
