/******************************************************************************
*
* Module: Private - Test bench For Arithmatic Logic Unit ' ALU ' Block 
*
* File Name: ALU_Test.sv
*
* Description:  this file is used for Testing the Arithmatic Logic Unit
*               Block , ALU is the fundamental building block of the processor
*               which is responsible for carrying out the arithmetic, logic functions          
*
* Author: Mohamed A. Eladawy
*
*******************************************************************************/

//************************ Simulation Commands *******************************//
//vlib work
//vmap work work
//vlog -coveropt 3 +cover +acc design.sv tb.sv
//vsim -coverage -vopt work.tb -c -do "coverage save -onexit -directive -codeAll alu_cov.ucdb; run -all"
//******************************************************************************//


class transaction ; 

// This is the base transaction object Container that will be used 
// in the environment to initiate new transactions and // capture transactions at DUT interface
 rand bit [3:0]   a   ;
 rand bit [3:0]   b   ;
 rand bit [1:0]   op  ;
 bit              c   ; 
 bit [3:0]        out ; 
 
// This function allows us to print contents of the data packet
// so that it is easier to track in a logfile 

      function void print(input string name = " " ); 
	  
	  $display (" a =%0d b =%Od c =%Od op=%Od out = %Od  ", a, b, op, c, out); 
      
	  endfunction 
	  
	  function void copy ( transaction item ) ;
	  
	  this.a = item.a ; 
	  this.b = item.b ; 
	  this.c = item.c ; 
	  this.op= item.op;
	  this.out = item.out ; 
	  
	 endfunction 

endclass 

/*******************************************************************************/

class generator ; 

int     i                     ;
string name                   ;
int     loob_Variable = 10000 ; 
event   drv_done              ;
mailbox drv_mbx               ; 
transaction  t  ;

   covergroup ALU_IN ;
       IN_1: coverpoint {t.a,t.b,t.op} {bins low = {0};
                             bins high = {1023};
                             bins rest[] = {[1:1022]};}

   endgroup


    function new(input string name = "GENERATOR");   //constructor
        this.name = name     ;
        this.t    = new  ;  
        this.drv_mbx = new   ; 
        ALU_IN = new;
    endfunction

task run();

for (i = 0 ; i<loob_Variable ; i++ ) begin 
 
 //transaction item = new ; 
 t.randomize() ; 
 ALU_IN.sample();
 $display (" [Generator] Loop:%0d/%0d create next item", i+1 ,loob_Variable ) ; 
 drv_mbx.put(t);
 $display (" [Generator] Wait for driver to be done" ); 
  @(drv_done);

   end 
  
 endtask 

endclass 

/*******************************************************************************/
class driver; 

virtual      Dut_if m_Dut_vif     ; 
virtual      CLK_if m_CLK_vif     ;
transaction  item                 ; 
string name                       ;
event        drv_done             ;
mailbox      drv_mbx              ; 

    function new(input string name = "DRIVER");
        this.name = name   ;
        this.drv_mbx = new ;
    endfunction


task run();
 $display (" [Driver] starting ..."); 
//*******************************************************************************//
// Try to get a new transaction every time and then assign 
// transaction contents to the interface. But do this only if the 
// design is ready to accept new transactions 
//*******************************************************************************//
forever begin 
transaction item; 
$display (" [Driver] waiting for item ...");
drv_mbx.get(item);
@(posedge m_CLK_vif.tb_clk); 
item.print("DRIVER")         ;
 m_Dut_vif.a    <= item.a    ; 
 m_Dut_vif.b    <= item.b    ; 
 m_Dut_vif.op   <= item.op   ; 
 ->drv_done                  ; 
      end
   endtask
 endclass 

//*******************************************************************************//
// The monitor has a virtual interface handle with which it can monitor 
// the events happening on the interface. It sees new transactions and then
// captures information into a packet and sends it to the scoreboard 
// using another mailbox. 
//*******************************************************************************//
class monitor;
virtual      Dut_if m_Dut_vif_monitor  ; 
virtual      CLK_if m_CLK_vif_monitor  ;
string name                            ;
mailbox      scb_mbs                   ;         // Mailbox connected to scoreboard 


    function new(input string name = "MONITOR");//constructor
        this.name = name;
        this.scb_mbs = new;
    endfunction


task run(); $display (" [Monitor] starting ..."); 
//*******************************************************************************//
// Check forever at every clock edge to see if there is a 
// valid transaction and if yes, capture info into a class
// object and send it to the scoreboard when the transaction
// is over.
//*******************************************************************************//
 forever begin
 transaction item_monitor = new() ;  
 @(posedge m_CLK_vif_monitor.tb_clk);
 #1;
 item_monitor.a   = m_Dut_vif_monitor.a     ; 
 item_monitor.b   = m_Dut_vif_monitor.b     ;
 item_monitor.c   = m_Dut_vif_monitor.c     ;
 item_monitor.op  = m_Dut_vif_monitor.op    ;
 item_monitor.out = m_Dut_vif_monitor.out   ;
 item_monitor.print("Monitor");
 scb_mbs.put(item_monitor); 
       end
    endtask 
 endclass 
//*******************************************************************************//
// The scoreboard is responsible to check data integrity. Since the desigin 
// simple adds and xor and &  inputs to give sum and carry, scoreboard helps to check if 
// output has changed for given set of inputs based on expected logic 
//*******************************************************************************//
typedef bit [10] A_B_OP;
class scoreboard ; 


mailbox scb_mbs   ; 
int Num_pass = 0  ;
int Num_fail = 0  ;
string name       ;
A_B_OP index      ; 
int bugs[A_B_OP] ;

   function new(input string name = "SCO");//constructor
        this.name = name     ;
        this.scb_mbs = new   ;    
    endfunction

task run();
forever begin 
transaction item, Golden_item ;
scb_mbs.get(item)     ; 
item.print("Scoreboard"); 
// Copy contents from received packet into a new packet so
// just to get a and b. 
Golden_item = new()     ;
Golden_item.copy(item)  ; 
// Let us calculate the expected values in carry and out 
if (item.op == 2'b00)
 
    begin 
      index   = {item.a, item.b, item.op};
      {Golden_item.c, Golden_item.out} = Golden_item.a + Golden_item.b ;
        if (Golden_item.c != item.c || Golden_item.out != item.out)
            
			begin 
		    	$error( " [SCO] ADDING Test case Failed, Expected output and Carry is 'h%0h and 'h%0h but instead the output and carry is 'h%0h and 'h%0h",Golden_item.c,Golden_item.out,item.c,item.out) ;
                        if(!bugs.exists(index))
                        begin
                            bugs[index] = 1;
                        end                
                        Num_fail++ ;				
	
   
  
            end 
			
	    else 
		   
		    begin 
			$display( " [SCO] ADDING Test case PASSED");

			Num_pass++ ; 	
			end 
   end 

else if (item.op == 2'b01)
 
    begin 
      index   = {item.a, item.b, item.op};
      {Golden_item.c, Golden_item.out} = Golden_item.a ^ Golden_item.b ;
        if (Golden_item.c != item.c || Golden_item.out != item.out)
            
			begin 
		    	$error( "  [SCO] xor Test case Failed, Expected output and Carry is 'h%0h and 'h%0h but instead the output and carry is 'h%0h and 'h%0h",Golden_item.c,Golden_item.out,item.c,item.out) ;
                        if(!bugs.exists(index))
                        begin
                            bugs[index] = 1;
                        end                
                        Num_fail++ ;				
	
   
  
            end 
			
	    else 
		   
		    begin 
			$display( "  [SCO] xor Test case PASSED");

			Num_pass++ ; 	
			end 
   end 

else if (item.op == 2'b10)
 
    begin 
      index   = {item.a, item.b, item.op};
      {Golden_item.c, Golden_item.out} = Golden_item.a & Golden_item.b ;
        if (Golden_item.c != item.c || Golden_item.out != item.out)
            
			begin 
		    	$error( "  [SCO] anding Test case Failed, Expected output and Carry is 'h%0h and 'h%0h but instead the output and carry is 'h%0h and 'h%0h",Golden_item.c,Golden_item.out,item.c,item.out) ;
                        if(!bugs.exists(index))
                        begin
                            bugs[index] = 1;
                        end                
                        Num_fail++ ;				
	
   
  
            end 
			
	    else 
		   
		    begin 
			$display(, "  [SCO] anding Test case PASSED");

			Num_pass++ ; 	
			end 
   end 
else if  (item.op == 2'b11)
 
    begin 
      index   = {item.a, item.b, item.op};
      {Golden_item.c, Golden_item.out} = Golden_item.a | Golden_item.b ;
        if (Golden_item.c != item.c || Golden_item.out != item.out)
            
			begin 
		    	$error( "  [SCO] Or Test case Failed, Expected output and Carry is 'h%0h and 'h%0h but instead the output and carry is 'h%0h and 'h%0h",Golden_item.c,Golden_item.out,item.c,item.out) ;
                        if(!bugs.exists(index))
                        begin
                            bugs[index] = 1;
                        end                
                        Num_fail++ ;				
	
   
  
            end 
			
	    else 
		   
		    begin 
			$display( "  [SCO] Or Test case PASSED");

			Num_pass++ ; 	
			end 
   end 
       end
    endtask
endclass
//*******************************************************************************//
// Lets say that the environnent class was already there, and generator is
// a new component that needs to be included in the ENV.
//*******************************************************************************//
 class env; 
 generator  g    ; // Generate transactions 
 driver     d    ; // Driver to design 
 monitor    m    ; // Monitor from design
 scoreboard s    ; // Scoreboard connected to monitor
 mailbox scb_mbs ; // Top level mailbox for SCB 
 virtual      Dut_if m_Dut_vif_env  ; 
 virtual      CLK_if m_CLK_vif_env  ;
 event drv_done  ; 
 mailbox drv_mbx ;  
 function new();
   
   d = new ; 
   m = new ; 
   s = new ; 
   scb_mbs = new(); 
   g = new ; 
   drv_mbx = new  ;

 endfunction 
virtual task run(); // Connect virtual interface handles 
 d.m_Dut_vif         = m_Dut_vif_env  ;
 m.m_Dut_vif_monitor = m_Dut_vif_env  ;
 d.m_CLK_vif         = m_CLK_vif_env  ;
 m.m_CLK_vif_monitor = m_CLK_vif_env  ; 
// Connect mailboxes between each component
 d.drv_mbx = drv_mbx   ;
 g.drv_mbx = drv_mbx   ; 
 m.scb_mbs = scb_mbs   ;
 s.scb_mbs = scb_mbs   ;
// Connect event handles 
d.drv_done = drv_done  ;
g.drv_done = drv_done  ; 
//*******************************************************************************//
// Start all components - a fork join any is used because
// the stimulus is generated by the generator and we want the
// simulation to exit only when the generator has finished 
// creating all transactions. Until then all Other components 
// have to run in the background.
//*******************************************************************************// 
fork 
 s.run();
 d.run();
 m.run(); 
 g.run(); 
    join_any 
    $display("*************************** simulation Finished ***************************");
    $display("NUMBER OF PASSES: %0d",s.Num_pass);
    $display("NUMBER OF FAILS: %0d",s.Num_fail);
    $display("input coverage is %.2f%%",g.ALU_IN.get_coverage());  
    $display("Unique bugs are equal to %0d",s.bugs.size());
    endtask
 endclass 
//*******************************************************************************//
// The test can instantiate any environment. In this test, we are using 
// an environment without the generator and hence the stimulus should be 
// written in the test. 
//*******************************************************************************//
class test ;
env e           ; 
scoreboard s    ; 
int Num_pass = 0;
int Num_fail = 0;
mailbox drv_mbx ; 
function new()  ; 

drv_mbx = new() ; 
e = new(); 
s = new  ; 
endfunction 
virtual task run(); 
e.d.drv_mbx = drv_mbx ;
e.run()     ;
    //get_data_scoreboard();

 endtask
 endclass 

interface Dut_if();
logic    [3:0]    a;
logic    [3:0]    b;
logic    [1:0]    op;
logic             c;
logic    [3:0]    out;
endinterface

interface CLK_if();
logic tb_clk;
initial tb_clk = 0;

always #10 tb_clk =~ tb_clk;
endinterface


module tb () ; 
 
  bit tb_clk ; 
  test t     ;
  CLK_if  m_CLK_if () ; 
  Dut_if  m_Dut_if () ; 

  ALU Test_Trial ( .a(m_Dut_if.a)     ,
                   .b(m_Dut_if.b)     ,
                   .op(m_Dut_if.op)   ,
                   .c(m_Dut_if.c)     ,
                   .out(m_Dut_if.out)); 
  

    initial begin
       
        t = new;
        t.e.m_Dut_vif_env = m_Dut_if;
        t.e.m_CLK_vif_env = m_CLK_if;
        t.run();
        $finish;
    end
endmodule
//*******************************************************************************//
//*******************************************************************************//







