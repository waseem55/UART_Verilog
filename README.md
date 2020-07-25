# UART_Verilog
A UART interface module that takes a data element as input, it gets latched when o_tx_rdy is 1 and 
i_tx_dv is pulsed, the module then sends the data element on the UART TX line.
The module outputs any data element recieved from RX line and pulses the o_rx_dv port.
    Parameter            possible Values                    Default
    Baud Rate            (9600, 19200, 115200, others)      115200
    Number of Data Bits  (7, 8, others)                     8
    Parity Bit           Off                                OFF
    Stop Bits            1                                  1
    Flow Control         None                               None
