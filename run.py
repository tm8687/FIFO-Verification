#!/usr/bin/python
import os

def moduleTopCreate(design):
  topFile = open("../Backup/top.sv","w")
  topFile.write("""
  //************************
  //   Top File
  //************************
  """.format(""))
  
  line = "`include \"../Backup/" + design + "\""
  topFile.write(line) 
  topFile.write("""

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
  
 """.format(""))
  
topFile.close()

topResultFile = open("final_result_7_9.txt","w")
for i in range(0,11,1):   #changing to 1 (0,11,1) 11->1
    if (i==0):
      file = "fifo.sv"
    else:
      file = "fifo" + str(i) + ".sv"
    moduleTopCreate(file)
    topResultFile = "test_fifo_7_9_" + str(i) + "_result.txt"
    cmd = "../Backup/sv_uvm top.sv | tee " + topResultFile
    os.system(cmd)
    res = open(topResultFile,"r")
    flag = "Fail"
    for line in res:
      if ("UVM_ERROR :    0" in line):
        flag = "Pa"
      if ("UVM_FATAL :    0" in line):
        flag = flag + ("ss")
    if (flag == "Pass"):
      flag = " Pass\n"
    else:
      flag = " Fail \n"
    
    res = open(topResultFile,"r")
    if flag == " Fail \n":
      for line in res:
        if "UVM_ERROR" in line:
          err_line = line
          l = topResultFile  + " --> " + flag[:-1] + " --> " + err_line + "\n"
          break
    else:      
      l = topResultFile  + " --> " + flag 
    
    topResultFile.write(l) 
topResultFile.close()
