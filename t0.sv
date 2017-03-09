//
//
//
class fifo_seq_item extends uvm_sequence_item;
	
	logic clk,rst;
	logic push;
	logic full;
	logic [31:0]busw = 275, entries = 167;
	rand logic [busw:0]datain;
	logic pull;
	logic empty;
	logic[busw:0]dataout;
	bit err, flag_push,flag_pull;
	logic [31:0] cnt;
	realtime time_fifo;
	int waiting;

	enum {Reset,fifoPush, fifoFull, fifoPushW, fifoPull, fifoEmpty, fifoPullW}cmd;

	`uvm_object_utils_begin(fifo_seq_item)
		`uvm_field_int(clk,UVM_ALL_ON|UVM_NOCOMPARE)
    	`uvm_field_int(rst,UVM_ALL_ON|UVM_NOCOMPARE)
    	`uvm_field_int(push,UVM_ALL_ON|UVM_NOCOMPARE)
    	`uvm_field_int(pull,UVM_ALL_ON|UVM_NOCOMPARE)
    	`uvm_field_int(empty, UVM_ALL_ON)
    	`uvm_field_int(full, UVM_ALL_ON)
    	`uvm_field_int(dataout,UVM_ALL_ON)
    	`uvm_field_int(datain,UVM_ALL_ON|UVM_NOCOMPARE)
	`uvm_object_utils_end

	function new (string name = "fifo_seq_item");
		super.new(name);
	endfunction

endclass: fifo_seq_item

//------------------------------------------------------------------------------------------------------------------------------------

class fifo_base_seq extends uvm_sequence#(fifo_seq_item);

	`uvm_object_utils(fifo_base_seq)

	fifo_seq_item req;
	enum {Reset,fifoPush, fifoFull, fifoPushW, fifoPull, fifoEmpty, fifoPullW}cmd;
	int rep = 10;

	function new (string name = "fifo_base_seq");
		super.new(name);
	endfunction

	task pre_body(seq_rst,pushPreBody, pullPreBody, [31:0]datain, waiting, cmd);
		begin
			req = fifo_seq_item::type_id::create("req");
			start_item(req);
			req.push    = pushPreBody;
			req.pull    = pullPreBody;
			req.datain  = datain;
			req.rst     = seq_rst;
			req.waiting = waiting;
			req.cmd     = cmd;
			finish_item(req);
		end
	endtask : pre_body

	task body();
		begin
			pre_body(1,0,0,0,0,reset);
			`uvm_info("Entries",$sformatf("Entries %d",req.entries),UVM_LOW);
			repeat(1) 
			begin 
				pre_body(0,1,0,$random,2,fifoPush);
			end
			repeat(1) 
			begin 
				pre_body(0,0,1,0,2,fifoPull); 
			end
			repeat (50) 
			begin 
				pre_body(0,$random,0,$random,$urandom_range(1,5),fifoPush);  
        		pre_body(0,0,$random,$random,$urandom_range(1,5),fifoPull); 
        	end

        	//checking FIFO full status

        	repeat(req.entries) 
        	begin 
        		pre_body(0,1,0,$random,2,fifoPush); 
        	end        
        	repeat(1)
        	begin 
        		pre_body(0,1,0,$random,2,fifoFull); 
        		end           
        	pre_body(0,1,0,$random,2,fifoPush);
        	repeat(1) 
        	begin  
        		pre_body(0,0,1,0,2,fifoPull); 
        	end
        	pre_body(0,1,0,$random,2,fifoPush);

        	//Checking FIFO emptyy status

        	repeat(req.entries)  
        		begin 
        			pre_body(0,1,0,$random,2,fifoPush); 
        		end   
      		repeat(req.enteries+1)  
      		begin 
      			pre_body(0,0,1,$random,2,fifoPull); 
      		end           
      		repeat(1)  
      		begin 
      			pre_body(0,0,1,$random,2,fifoEmpty); 
      		end  
       		pre_body(0,0,1,$random,2,fifoPull);
        	repeat(1) 
        	begin  
        		pre_body(0,0,1,0,2,fifoPull); 
        	end
        	pre_body(0,0,1,$random,2,fifoPull);
        	repeat (50) 
        	begin 
        		pre_body(0,$random,0,$random,$urandom_range(1,5),fifoPush);  
        		pre_body(0,0,$random,$random,$urandom_range(1,5),fifoPull); 
        	end  
        	repeat (50) 
        	begin 
        		pre_body(0,$random,0,$random,$urandom_range(1,5),fifoPush);  
        		pre_body(0,0,$random,$random,$urandom_range(1,5),fifoPull); 
        	end 
        end
    endtask : body

endclass: fifo_base_seq

//-------------------------------------------------------------------------------------------------------------------------------------

class fifo_tx_sequencer extends uvm_sequencer #(fifo_seq_item);

	`uvm_component_utils(fifo_tx_sequencer)

		function new (string name, uvm_component parent);
			super.new(name,parent);
		endfunction : new

endclass: fifo_tx_sequencer

//-------------------------------------------------------------------------------------------------------------------------------------

class fifo_tx_driver extends uvm_driver #(fifo_seq_item)
	
	
	`uvm_component_utils(fifo_tx_driver)

	fifo_seq_item req, req1, req2;
	//Virtual Interface declaration
	virtual fifoif vif;
	enum {Reset,fifoPush, fifoFull, fifoPushW, fifoPull, fifoEmpty, fifoPullW}cmd;


	function new (string name = "fifo_tx_driver", uvm_component parent = null);
			super.new(name,parent);
	endfunction : new

	function void connect_phase(uvm_phase phase);
		if (!uvm_config_db #(virtual fifoif)::get (null, "uvm_test_top", "fifoif", this.vif)) begin
			`uvm_error ("NOVIF", "Virtual Interface for FIFO not found!!")
		end
	endfunction: connect_phase

	task run_phase (uvm_phase phase);
		vif.rst <= 0;
		fork
			forever
				begin
					seq_item_port.get_next_item(req);

					case(req.cmd)
						reset: begin
								#1
								vif.push <= 0;
								vif.pull <= 0;
								vif.rst  <= 1;
								vif.datain <= req.datain;
								repeat(3) @(posedge vif.clk) #1;
								vif.rst  <= 0;
								@(posedge vif.clk) #1;
							   end
						fifoPush: begin
									vif.datain <= $random;
									if(req.waiting != 0) repeat (req.waiting) @(posedge vif.clk) #1;
									else if (req.waiting == 0) repeat(1) @(posedge vif.clk) #1;
									else @(posedge vif.clk) #1;
									vif.push <= req.push;
									vif.datain <= req.datain;
									@(posedge vif.clk) #1
									vif.push <= 0;
								   end
						fifoFull: begin
									if(vif.full !== req.full)
									begin
										req1 = new();
										req1.full <= req.full;
										req1.time_fifo <= $realtime;
										req1.err <= 1;
									end
								  end
						fifoPushW: begin
									if(vif.full == 1)
									begin
										if(vif.full == 0)
										begin
                                  			 `uvm_info("Push operation waiting", $sformatf("%t Driver: Push + wait, cmd %d",$realtime,req.cmd),UVM_LOW);                   
                                    		  vif.datain <= $random;
                                    		  repeat(req.waiting) @(posedge vif.clk) #1;
                                    		  vif.push   <= req.push;
                                    		  vif.datain <= req.datain;
                                    		  @(posedge vif.clk) #1
                                    		  vif.push <= 0;
                                    		end
                                    	end
                                    end
                        fifoPull: begin
                        			if(req.waiting != 0) repeat(req.waiting) @(posedge vif.clk) #1;
                        			else if (req.waiting == 0) repeat (1) @(posedge vif.clk) #1;
                        			else @(posedge vif.clk) #1;
                        			vif.pull <= req.pull;
                        			@(posedge vif.clk) #1;
                        			vif.pull <= 0;
                        		  end
                        fifoEmpty: begin
                        			if(vif.empty! == req.empty)
                        			begin
                        				req2 = new();
                        				req2.empty = req.empty;
                        				req.time_fifo = $realtime;
                        				req2.err = 1;
                        			end
                        		   end
                        fifoPullW: begin
                        			if(vif.empty == 1)
                        			begin
                        				if(vif.empty == 0)
                        				begin
                        					`uvm_info("Pull operation waiting", $sformatf("%t Driver: Pull + wait, cmd %d",$realtime,req.cmd),UVM_LOW);
                        					vif.pull <= req.pull;
                        					@(posedge vif.clk) #1;
                        					vif.pull <= 0;
                        				end
                        			end
                        		end
                    endcase	
                seq_item_port.item_done();
            end
		join
	endtask: run_phase

endclass: fifo_tx_driver

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class fifo_tx_monitor extends uvm_monitor;

	virtual fifoif ann;

	//Analysis port
	uvm_analysis_port #(fifo_seq_item) afx;
	fifo_seq_item req;

	`uvm_component_utils(fifo_tx_monitor)

	function new(string name = fifo_tx_monitor, uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		begin
			afx = new("afx", this);
		end
	endfunction: build_phase

	function void connect_phase (uvm_phase phase);
		if (!uvm_config_db #(virtual fifoif)::get(null, "uvm_test_top", "fifoif", this.ann)) begin
		`uvm_error("connect", "fifo interface not found!!")	
		end
	endfunction: connect_phase

	task run_phase(uvm_phase phase);
		fork

		forever begin @(posedge ann.clock))
			req = new();
			if(ann.rst)
			begin
				req.datain = ann.datain;
				req.push   = ann.push;
				req.cnt    = 0;
			end
			if(ann.push == 1 && ann.full!= 1)
			begin
				req.datain = ann.datain;
				req.push   = ann.push;
				req.full   = ann.full;
				afx.write(req);
			end
			req.push_flag = 0;
		end
	join_none
		end
	
	endtask : run_phase

endclass : fifo_tx_monitor

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class fifo_rx_monitor extends uvm_monitor;

	virtual fifoif ann;
	logic [31:0] pullcount;
	
	//Analysis port
	uvm_analysis_port #(fifo_seq_item) afx;
	fifo_seq_item req;

	`uvm_component_utils(fifo_rx_monitor)

	function new(string name = "fifo_rx_monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		begin
			afx = new ("afx", thin);
		end
	endfunction: build_phase

	function void connect_phase(uvm_phase phase);
		if (!uvm_config_db #(virtual fifoif)::get(null, "uvm_test_top", "fifoif", this.ann)) begin
			`uvm_error("connect", "fifo interface not found!!")
		end
	endfunction: connect_phase;

	task run_phase(uvm_phase phase);
		begin
			fork
				forever begin
					@(posedge (ann.clk));
					req = new();
					if (ann.pull === 1 && ann.empty !== 1)
					begin
						req.dataout = ann.dataout;
						req.pull 	= ann.pull;
						req.full	= ann.full;
						req.empty	= ann.empty;
						afx.write(req);
					end
					req.pull_full = 0;
				end
			join_none
		end

	endtask: run_phase

endclass : fifo_rx_monitor


//-----------------------------------------------------------------------------------------------------------------------------------------------
class fifo_sb extends uvm_scoreboard;
	uvm_tlm_analysis_fifo #(fifo_seq_item) ae_inp;
	uvm_tlm_analysis_fifo #(fifo_seq_item) ae_res;

	fifo_seq_item req, response;
	int count = 0;

	`uvm_component_utils(fifo_sb)

	function new(string name = "fifo_scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		begin
			ae_inp = new("ae_inp", this);
			ae_res = new("ae_res", this);
		end
	endfunction : build_phase

	task run_phase(uvm_phase phase);
		fork
			forever begin
				ae_inp.get(req);
				ae_res.get(response);

				if(req.push == 1 && req.full!= 1)
				begin
					count++;
					`uvm_info("push",$sformatf("Count Incr push %d",count),UVM_LOW)
				end
				`uvm_info("Information", $sformatf("Pull %h empty %h", req.push, response.empty), UVM_LOW)

				if(response.pull == 1 && response.empty != 1)
				begin
					count = count1-1;
					`uvm_info("Pull", $sformatf("Counter Decrements and pulls %d",count), UVM_LOW)
				end

				if(req.datain != response.dataout)
				begin
					`uvm_error("Oh no!", $sformatf("Expected %h, but got %h", req.datain, repsonse.dataout))
				end

				else if(req.datain == response.dataout)
				`uvm_info("Scoreboard works!", $sformatf("Expected %h, but got %h", req.datain, repsonse.dataout), UVM_LOW)
				end

				if (count == req.entries)
				begin
					if(response.full == 1)
						`uvm_error("Fifo Full!", $sformatf("Expected data received %h", response.full))
					else
					`uvm_info("Correct", $sformatf("Expected data %h received at %t", $realtime, response.full), UVM_LOW)
				end

				if(count == 0)
				begin
					if(response.empty == 1)
						`uvm_error("Fifo Full!", $sformatf("Expected data received %h", response.empty))
					else
					`uvm_info("Correct", $sformatf("Expected data %h received at %t", $realtime, response.full), UVM_LOW)
				end
			end
		join_none
	
	endtask : run_phase

endclass : fifo_sb

//----------------------------------------------------------------------------------------------------------------------------------------

class fifo_agent extends uvm_agent;

	fifo_tx_driver driver1;
	fifo_seq_item packet_seq;
	fifo_tx_sequencer seqr;
	fifo_tx_monitor monitor;
	fifo_rx_monitor resmon;
	fifo_sb scoreboard;

	`uvm_component_utils_begin(fifo_agent)
    `uvm_field_object(driver1,UVM_ALL_ON)
    `uvm_field_object(packet_seq,UVM_ALL_ON)
    `uvm_field_object(seqr,UVM_ALL_ON)
    `uvm_field_object(monitor,UVM_ALL_ON)
    `uvm_field_object(resmon,UVM_ALL_ON)
  `uvm_component_utils_end

  function void build_phase(uvm_phase phase);
   begin
    super.build_phase(phase);
    packet_seq = fifo_seq_item::type_id::create("packet_seq",this);
    seqr = fifo_seqr::type_id::create("seqr",this);
    driver1 = fifo_tx_driver::type_id::create("fifo_tx_driver",this);
    monitor = fifo_tx_monitor::type_id::create("fifo_rx_monitor",this);
    resmon = fifo_rx_monitor::type_id::create("fifo_tx_monitor",this);
    scoreboard = fifo_sb::type_id::create("fifo_sb",this);
   end
  endfunction: build_phase;


  function void connect_phase(uvm_phase phase);
   	driver1.seq_item_port.connect(seqr.seq_item_export);
   	monitor.afx.connect(scoreboard.ae_inp.analysis_export);
   	resmon.afx.connect(scoreboard.ae_res.analysis_export);
  endfunction: connect_phase;
 
 
 task run_phase(uvm_phase phase);
	phase.raise_objection(this, "start of test");
	test_seq.start(seqr);
	phase.drop_objection(this, "end of test");
 endtask: run_phase; 

 function new(string name = "fifo_agent", uvm_component parent = null);
    super.new(name,parent);
 endfunction
 
 endclass: fifo_agent

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class fifo_env extends uvm_env;

	agent1 agnt;
	`uvm_component_utils_begin(env1)
	`uvm_field_object(agnt,UVM_ALL_ON)
	`uvm_component_utils_end

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agnt = agent1::type_id::create("agnt",this);
	endfunction: build_phase;

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
	endfunction: connect_phase;

	function new(string name="env1", uvm_component parent=null);
		super.new(name,parent);
	endfunction: new;

endclass: fifo_env

//------------------------------------------------------------------------------------------

class fifo_test extends uvm_test;
	env1 environ;
	`uvm_component_utils_begin(fifo_test)
	`uvm_field_object(environ,UVM_ALL_ON)
	`uvm_component_utils_end

	function new(string name = "fifo_test", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		environ = env1::type_id::create("env1",this);
	endfunction: build_phase

endclass: fifo_test








