//
// A simple interface for testing the fifo
//

interface fifoif #(busw=32,entries=31)();
    reg clk,rst;
    reg push;
    reg full;
    reg [busw-1:0] datain;
    reg pull;
    reg empty;
    reg [busw-1:0] dataout;

modport fif(input clk, input rst,input push, output full,
    input datain,input pull, output empty, output dataout);




endinterface : fifoif
