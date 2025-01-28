`define CYCLE_TIME 10
`timescale 1ns/10ps
module PATTERN(
    // Output Signals
    clk,
    rst_n,
    in_valid,
    inst,
    // Input Signals
    out_valid,
    inst_addr
);

//================================================================
//   Input and Output Declaration                         
//================================================================

output reg clk,rst_n,in_valid;
output reg [31:0] inst;

input wire out_valid;
input wire [31:0] inst_addr;

//================================================================
// parameters & integer
//================================================================

integer pat_num = 1000, out_max_latency = 10, seed = 64;
integer i, t, pat, out_counter;
integer golden_inst_addr;        // ************** Program Counter ************* //
integer instruction [999:0];     // ******** Instruction (from inst.txt) ******* //
integer opcode, rs, rt, rd, shamt, func, address, immediate;
integer golden_r [31:0];         // *********** Gloden answer for Reg ********** //
integer mem [4095:0];            // ******** Data Memory (from mem.txt) ******** //

//================================================================
// clock setting
//================================================================

real CYCLE = `CYCLE_TIME;

always #(CYCLE/2.0) clk = ~clk;

//================================================================
// initial
//================================================================

initial begin
    // read data mem & instrction
    $readmemh("instruction.txt", instruction);
    $readmemh("mem.txt", mem);

    // initialize control signal
    rst_n = 1'b1;
    in_valid = 1'b0;
    // initial variable
    golden_inst_addr = 0;
    for(i = 0; i < 32; i = i + 1)begin
        golden_r[i] = 0;
    end
    // inst=X
    inst = 32'bX;
    // reset check task
    reset_check_task;
    // generate random idle clk
	t = $random(seed) % 3 + 1'b1;
	repeat(t) @(negedge clk);
    // main pattern
	for(pat = 0; pat < pat_num; pat = pat + 1)begin
		input_task;
		out_valid_wait_task;
        check_ans_task;
	end
    $display("************************************************************");
    check_memory_task;
    display_pass_task;
end

//================================================================
// task
//================================================================

// reset check task
task reset_check_task; begin
    // force clk
    force clk = 0;

    // generate reset signal
    #CYCLE; rst_n = 1'b0;
    #CYCLE; rst_n = 1'b1;

    // check output signal=0
    if(out_valid !== 1'b0 || inst_addr !== 32'd0)begin
        $display("************************************************************");
        $display("*  Output signal should be 0 after initial RESET  at %8t   *",$time);
        $display("************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    // check r
    for(i = 0; i < 32; i = i + 1)begin
        if(My_SP.r[i] !== 32'd0)begin
            $display("************************************************************");     
            $display("*  Register r should be 0 after initial RESET  at %8t      *",$time);
            $display("************************************************************");
            repeat(2) #CYCLE;
            $finish;
        end
    end

    // release clk
    #CYCLE; release clk;
end endtask

// input task
task input_task; begin
    // inst = ? ,in_valid = 1
    inst = instruction[golden_inst_addr >> 2];
    in_valid = 1'b1;
    @(negedge clk);

    // inst = x ,in_valid = 0
    inst = 32'bX;
    in_valid = 1'b0;
end endtask

// out_valid wait task
task out_valid_wait_task; begin 
    // out_counter
    out_counter = 0;

    // check out_counter
    while(!out_valid)begin
        // out_counter++
        out_counter = out_counter+1;
        if(out_counter == out_max_latency)begin
            $display("***************************************************");     
            $display("*   the execution cycles are more than 10 cycles  *",$time);
            $display("***************************************************");
            repeat(2) @(negedge clk);
            $finish;
        end
        @(negedge clk);
    end
end endtask

// check_ans_task
task check_ans_task; begin
    // answer calculate
    // Decode Instruction
    opcode    = instruction[golden_inst_addr>>2][31:26];
    rs        = instruction[golden_inst_addr>>2][25:21];
    rt        = instruction[golden_inst_addr>>2][20:16];
    rd        = instruction[golden_inst_addr>>2][15:11];
    shamt     = instruction[golden_inst_addr>>2][10:6];
    func      = instruction[golden_inst_addr>>2][5:0];
    immediate = instruction[golden_inst_addr>>2][15:0];
    address   = instruction[golden_inst_addr>>2][25:0];
    // Execute instuction
    case (opcode)
        // ================ R-Type ================
        6'b000000: begin
            case (func)
                6'b000000: golden_r[rd] = golden_r[rs] & golden_r[rt];        // and (0x00)
                6'b000001: golden_r[rd] = golden_r[rs] | golden_r[rt];        // or  (0x01)
                6'b000010: golden_r[rd] = golden_r[rs] + golden_r[rt];        // add (0x02)
                6'b000011: golden_r[rd] = golden_r[rs] - golden_r[rt];        // sub (0x03)
                6'b000100: golden_r[rd] = (golden_r[rs] < golden_r[rt])? 1:0; // slt (0x04)
                6'b000101: golden_r[rd] = golden_r[rs] << shamt;              // sll (0x05)
                6'b000110: golden_r[rd] = ~(golden_r[rs] | golden_r[rt]);     // nor (0x06)
                6'b000111: golden_inst_addr = golden_r[rs];                   // jr  (0x07)
                default: ;
            endcase
        end
        // ================ I-Type ================
        6'b000001: golden_r[rt] = golden_r[rs] & {16'b0, immediate[15:0]};                      // andi (0x01)
        6'b000010: golden_r[rt] = golden_r[rs] | {16'b0, immediate[15:0]};                      // ori  (0x02)
        6'b000011: golden_r[rt] = golden_r[rs] + {{16{immediate[15]}}, immediate[15:0]};        // addi (0x03)
        6'b000100: golden_r[rt] = golden_r[rs] - {{16{immediate[15]}}, immediate[15:0]};        // subi (0x04)
        6'b000101: golden_r[rt] = mem[{{16{immediate[15]}}, immediate[15:0]} + golden_r[rs]];   // lw   (0x05)
        6'b000110: mem[golden_r[rs] + {{16{immediate[15]}}, immediate[15:0]}] = golden_r[rt];   // sw   (0x06)
        6'b000111: begin
            if (golden_r[rs] == golden_r[rt]) golden_inst_addr = golden_inst_addr + 4 + {{14{immediate[15]}}, immediate[15:0], 2'b00}; // beq (0x07)
            else golden_inst_addr = golden_inst_addr + 4;
        end
        6'b001000: begin
            if (golden_r[rs] != golden_r[rt]) golden_inst_addr = golden_inst_addr + 4 + {{14{immediate[15]}}, immediate[15:0], 2'b00}; // bne (0x08)
            else golden_inst_addr = golden_inst_addr + 4;
        end
        6'b001001: golden_r[rt] = immediate << 16;                              // lui (0x09)
        // ================ J-Type ================
        6'b001010: golden_inst_addr = {golden_inst_addr[31:28], address << 2};  // j   (0x0A)
        6'b001011: begin                                  
            golden_r[31] = golden_inst_addr + 4;
            golden_inst_addr = {golden_inst_addr[31:28], address << 2};         // jal (0x0B)
        end
        default: ;
    endcase
    // Get next instruction address for those not branch instructions
    if (opcode != 6'b000111 && opcode != 6'b001000 && opcode != 6'b001011 && opcode != 6'b001010 && !(opcode == 6'b000000 && func == 6'b000111)) begin
        golden_inst_addr = golden_inst_addr + 4;
    end
    // Check register
    for(i=0;i<32;i=i+1)begin
        if(My_SP.r[i] !== golden_r[i])begin
            display_fail_task;
            $display("-------------------------------------------------------------------");
            $display("*                        PATTERN NO.%4d 	                        *",pat);
            $display("*                   register [%2d]  error 	                    *",i);
            $display("*          answer should be : %d , your answer is : %d            *",golden_r[i],My_SP.r[i]);
            $display("-------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
    end

    if(inst_addr !== golden_inst_addr)begin        
        display_fail_task;
        $display("-------------------------------------------------------------------");
        $display("*                        PATTERN NO.%4d 	                        *",pat);
        $display("*                          inst_addr  error 	                    *");
        $display("*          answer should be : %d , your answer is : %d            *",golden_inst_addr,inst_addr);
        $display("-------------------------------------------------------------------");
        repeat(2) @(negedge clk);
        $finish;
    end

    @(negedge clk);
end endtask

// check_memory_task
task check_memory_task; begin
    // check memory
    for(i = 0; i < 4096; i = i + 1)begin
        if(My_MEM.mem[i] !== mem[i])begin
            display_fail_task;
            $display("------------------------------------------------------------------");
            $display("*                        PATTERN NO.%4d 	                       *",pat);
            $display("*                     MEM [%4d]  error     	                   *",i);
            $display("*          answer should be : %d , your answer is : %d           *",mem[i],My_MEM.mem[i]);
            $display("------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
    end
end endtask

// display fail task
task display_fail_task; begin

        $display("\n");
        $display("        ----------------------------               ");
        $display("        --                        --       |\__||  ");
        $display("        --  OOPS!!                --      / X,X  | ");
        $display("        --                        --    /_____   | ");
        $display("        --  \033[0;31mSimulation Failed!!\033[m   --   /^ ^ ^ \\  |");
        $display("        --                        --  |^ ^ ^ ^ |w| ");
        $display("        ----------------------------   \\m___m__|_|");
        $display("\n");
end endtask

// display pass task
task display_pass_task; begin
        $display("\n");
        $display("        ----------------------------               ");
        $display("        --                        --       |\__||  ");
        $display("        --  Congratulations !!    --      / O.O  | ");
        $display("        --                        --    /_____   | ");
        $display("        --  \033[0;32mSimulation PASS!!\033[m     --   /^ ^ ^ \\  |");
        $display("        --                        --  |^ ^ ^ ^ |w| ");
        $display("        ----------------------------   \\m___m__|_|");
        $display("\n");
		repeat(2) @(negedge clk);
		$finish;
end endtask

endmodule