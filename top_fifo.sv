`include "fifoif.sv"
import uvm_pkg::*;
`include "fifo_uvm.sv"

module top();

  logic [31:0] busw=7,enteries = 9;

  fifoif q();
  fifo #(32,32) f(q.fif);

  reg [31:0] exp[$];

  initial 
    begin
      q.clk=1;
      repeat(1000000)
      begin
        #5 q.clk=~q.clk;
      end
    end

  initial
    begin
      uvm_config_db#(virtual fifoif )::set(null, "uvm_test_top", "fifoif" ,q );
      run_test("fifo_test");
    end

  initial 
    begin
      $dumpfile("fifo.vpd");
      $dumpvars();
    end

endmodule : top
