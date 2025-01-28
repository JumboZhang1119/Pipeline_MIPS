`define CYCLE_TIME 10
`timescale 1ns/10ps
module PATTERN_p(
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

integer execution_num = 1000, out_max_latency = 10, seed = 64;
integer i, t, latency, out_valid_counter, in_valid_counter;
integer golden_inst_addr_in, golden_inst_addr_out,pat; // ************** Program Counter ************* //
integer instruction [999:0];                           // ******** Instruction (from inst.txt) ******* //
integer opcode,rs,rt,rd,shamt,func,immediate, address;
integer golden_r [31:0];                               // *********** Gloden answer for Reg ********** //
integer mem [4095:0];                                  // ******** Data Memory (from mem.txt) ******** //

//================================================================
// clock setting
//================================================================

real CYCLE = `CYCLE_TIME;

always #(CYCLE/2.0) clk = ~clk;

//================================================================
// initial
//================================================================

integer jalpc, stage1_inst_addr, stage2_inst_addr, stage3_inst_addr, stage4_inst_addr, stage5_inst_addr, stage_inst_addr, new_rs_data, new_rt_data;
integer n_opcode, n_rs, n_rt, n_rd, n_shamt, n_func, n_imm;
reg stage_valid, stage2_valid, stage3_valid, stage4_valid, stage5_valid;

initial begin
    // read data mem & instrction
    $readmemh("instruction.txt", instruction);
    $readmemh("mem.txt", mem);

    // initialize control signal 
    rst_n = 1'b1;
    in_valid = 1'b0;

    // initial variable
    golden_inst_addr_in = 0;
    golden_inst_addr_out = 0;
    //*******************
    stage1_inst_addr = 4;
    //*******************
    in_valid_counter = 0;
    out_valid_counter = 0;
    latency = -1;
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
	while(out_valid_counter < execution_num)begin
		input_task;
        check_ans_task;
        @(negedge clk);
	end

    // check out_valid
    check_memory_and_out_valid;
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
        if(My_SP.r[i]!==32'd0)begin
            $display("************************************************************");     
            $display("*  Register r should be 0 after initial RESET  at %8t      *",$time);
            $display("************************************************************");
            repeat(2) #CYCLE;
            $finish;
        end
    end

    // release clk
    #CYCLE; release clk;

end
endtask

// input task
task input_task; begin

    // input
    if(in_valid_counter < execution_num)begin

        // check inst_addr        
        if(inst_addr !== golden_inst_addr_in)begin
            display_fail_task;
            $display("-------------------------------------------------------------------");
            $display("*                        PATTERN NO.%4d 	                        *",in_valid_counter);
            $display("*                          inst_addr  error 	                    *");
            $display("*                          opcode %d, inst %h                     *", opcode, inst);
            $display("*          answer should be : %d , your answer is : %d            *",golden_inst_addr_in,inst_addr);
            $display("-------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end

        // inst=? ,in_valid=1
        inst = instruction[golden_inst_addr_in>>2];
        in_valid = 1'b1;        
        // $display(" %h ", inst);

        // Pre-decoding for those branch instructions
        opcode = instruction[golden_inst_addr_in>>2][31:26];
        rs = instruction[golden_inst_addr_in>>2][25:21];
        rt = instruction[golden_inst_addr_in>>2][20:16];
		rd = instruction[golden_inst_addr_in>>2][15:11];
		shamt = instruction[golden_inst_addr_in>>2][10:6];
		func = instruction[golden_inst_addr_in>>2][5:0];
		immediate = instruction[golden_inst_addr_in>>2][15:0];
        address   = instruction[golden_inst_addr_in>>2][25:0];
        // Save current instruction address temporarily
        stage1_inst_addr = golden_inst_addr_in;
        // rs, rt data for branch instruction address calculation
        new_rs_data = golden_r[rs];
        new_rt_data = golden_r[rt];
        // For those rs, rt register should write before branch instruction calculation
        // (Which just calculate for pc, the actual write will start later)
        if (stage_valid) begin
            n_opcode = instruction[stage_inst_addr>>2][31:26];
            n_rs = instruction[stage_inst_addr>>2][25:21];
            n_rt = instruction[stage_inst_addr>>2][20:16];
		    n_rd = instruction[stage_inst_addr>>2][15:11];
		    n_shamt = instruction[stage_inst_addr>>2][10:6];
		    n_func = instruction[stage_inst_addr>>2][5:0];
		    n_imm = instruction[stage_inst_addr>>2][15:0];
            case (n_opcode)
                // ================ R-Type ================
                6'b000000: begin // R-type instructions
                    case (n_func)
                        6'b000000: begin
                            if (n_rd == rs) new_rs_data = golden_r[n_rs] & golden_r[n_rt];               // and (0x00)
                            else if (n_rd == rt) new_rt_data = golden_r[n_rs] & golden_r[n_rt];
                        end
                        6'b000001: begin
                            if (n_rd == rs) new_rs_data = golden_r[n_rs] | golden_r[n_rt];               // or  (0x01)
                            else if (n_rd == rt) new_rt_data = golden_r[n_rs] | golden_r[n_rt];
                        end
                        6'b000010: begin
                            if (n_rd == rs) new_rs_data = golden_r[n_rs] + golden_r[n_rt];               // add (0x02)
                            else if (n_rd == rt) new_rt_data = golden_r[n_rs] + golden_r[n_rt];
                        end
                        6'b000011: begin
                            if (n_rd == rs) new_rs_data = golden_r[n_rs] - golden_r[n_rt];               // sub (0x03)
                            else if (n_rd == rt) new_rt_data = golden_r[n_rs] - golden_r[n_rt];
                        end
                        6'b000100: begin
                            if (n_rd == rs) new_rs_data = (golden_r[n_rs] < golden_r[n_rt])? 1:0;        // slt (0x04)
                            else if (n_rd == rt) new_rt_data = (golden_r[n_rs] < golden_r[n_rt])? 1:0;
                        end
                        6'b000101: begin
                            if (n_rd == rs) new_rs_data = golden_r[n_rs] << shamt;                       // sll (0x05)
                            else if (n_rd == rt) new_rt_data = golden_r[n_rs] << shamt;
                        end
                        6'b000110: begin
                            if (n_rd == rs) new_rs_data = ~(golden_r[n_rs] | golden_r[n_rt]);            // nor (0x06)
                            else if (n_rd == rt) new_rt_data = ~(golden_r[n_rs] | golden_r[n_rt]);
                        end
                        default: ;
                    endcase
                end
                // ================ I-Type ================
                6'b000001: begin
                    if (n_rt == rs) new_rs_data = golden_r[n_rs] & {16'b0, n_imm[15:0]};                 // andi(0x01)
                    else if (n_rt == rt) new_rt_data = golden_r[n_rs] & {16'b0, n_imm[15:0]};
                end
                6'b000010: begin
                    if (n_rt == rs) new_rs_data = golden_r[n_rs] | {16'b0, n_imm[15:0]};                 // ori (0x02)
                    else if (n_rt == rt) new_rt_data = golden_r[n_rs] | {16'b0, n_imm[15:0]};
                end
                6'b000011: begin
                    if (n_rt == rs) new_rs_data = golden_r[n_rs] + {{16{n_imm[15]}}, n_imm[15:0]};       // addi(0x03)
                    else if (n_rt == rt) new_rt_data = golden_r[n_rs] + {{16{n_imm[15]}}, n_imm[15:0]}; 
                end
                6'b000100: begin
                    if (n_rt == rs) new_rs_data = golden_r[n_rs] - {{16{n_imm[15]}}, n_imm[15:0]};       // subi(0x04)
                    else if (n_rt == rt) new_rt_data = golden_r[n_rs] - {{16{n_imm[15]}}, n_imm[15:0]};
                end
                6'b000101: begin
                    if (n_rt == rs) new_rs_data = mem[{{16{n_imm[15]}}, n_imm[15:0]} + golden_r[n_rs]];  // lw  (0x05)
                    else if (n_rt == rt) new_rt_data = mem[{{16{n_imm[15]}}, n_imm[15:0]} + golden_r[n_rs]];
                end
                6'b001001: begin
                    if (n_rt == rs) new_rs_data = n_imm << 16;                                           // lui (0x09)
                    else if (n_rt == rt) new_rt_data = n_imm << 16;
                end
                // ================ J-Type ================
                6'b001011: begin
                    if (rs == 31) new_rs_data = jalpc;                                                   // jal (0x0B)
                    else if (rt == 31) new_rt_data = jalpc;
                end
                default: ;
            endcase
        end
        // Pre-decoding for those branch instructions
        case (opcode)
            6'b000000: if (func == 6'b000111) golden_inst_addr_in = new_rs_data;
            6'b000111: begin
                if (new_rs_data == new_rt_data) golden_inst_addr_in = golden_inst_addr_in + 4 + {{14{immediate[15]}}, immediate[15:0], 2'b00}; // beq(0x07)
                else golden_inst_addr_in = golden_inst_addr_in + 4;
            end
            6'b001000: begin
                if (new_rs_data != new_rt_data) golden_inst_addr_in = golden_inst_addr_in + 4 + {{14{immediate[15]}}, immediate[15:0], 2'b00}; // bne(0x08)
                else golden_inst_addr_in = golden_inst_addr_in + 4;
            end
            6'b001010: golden_inst_addr_in = {golden_inst_addr_in[31:28], address << 2};                                                       // j  (0x0A)
            6'b001011: begin                                                                                                                   
                jalpc = golden_inst_addr_in + 4;                                                                                               // jal(0x0B)
                golden_inst_addr_in = {golden_inst_addr_in[31:28], address << 2};
            end
            default: ;
        endcase
        // Get next instruction address for those not branch instructions
        if (opcode != 6'b000111 && opcode != 6'b001000 && opcode != 6'b001010 && opcode != 6'b001011 && !(opcode == 6'b000000 && func == 6'b000111)) begin
            golden_inst_addr_in = golden_inst_addr_in + 4;
        end

        // in_valid_counter
        in_valid_counter = in_valid_counter + 1;

    end
    else begin
        // inst = x ,in_valid = 0
        inst = 32'bX;
        in_valid = 1'b0;
    end

end
endtask

// check_ans_task
task check_ans_task; begin
    // Pipeline waiting
    if (in_valid) begin
        stage2_valid <= 1;
        stage2_inst_addr <= stage1_inst_addr; // Passing instruction
    end else stage2_valid <= 0;
    if (stage2_valid) begin
        stage3_valid <= 1;
        stage3_inst_addr <= stage2_inst_addr; // Passing instruction
    end else stage3_valid <= 0;
    if (stage3_valid) begin
        stage4_valid <= 1;
        stage4_inst_addr <= stage3_inst_addr; // Passing instruction
    end else stage4_valid <= 0;
    if (stage4_valid) begin
        stage5_valid <= 1;
        stage5_inst_addr <= stage4_inst_addr; // Passing instruction
    end else stage5_valid <= 0;
    if (stage4_valid) begin
        stage_valid <= 1;
        stage_inst_addr <= stage5_inst_addr;  // Passing instruction
    end else stage_valid <= 0;

    // check out_valid
    if(out_valid)begin
        // answer calculate (actual write)
        opcode = instruction[stage_inst_addr>>2][31:26];
        rs = instruction[stage_inst_addr>>2][25:21];
        rt = instruction[stage_inst_addr>>2][20:16];
		rd = instruction[stage_inst_addr>>2][15:11];
		shamt = instruction[stage_inst_addr>>2][10:6];
		func = instruction[stage_inst_addr>>2][5:0];
		immediate = instruction[stage_inst_addr>>2][15:0];
        // R-type
        // I-type
        // PC & jump, beq...etc.
        // hint: it's necessary to consider sign externtion while calculating
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
                    default: ;
                endcase
            end
            // ================ I-Type ================
            6'b000001: golden_r[rt] = golden_r[rs] & {16'b0, immediate[15:0]};                       // andi (0x01)
            6'b000010: golden_r[rt] = golden_r[rs] | {16'b0, immediate[15:0]};                       // ori  (0x02)
            6'b000011: golden_r[rt] = golden_r[rs] + {{16{immediate[15]}}, immediate[15:0]};         // addi (0x03)
            6'b000100: golden_r[rt] = golden_r[rs] - {{16{immediate[15]}}, immediate[15:0]};         // subi (0x04)
            6'b000101: golden_r[rt] = mem[{{16{immediate[15]}}, immediate[15:0]} + golden_r[rs]];    // lw   (0x05)
            6'b000110: mem[golden_r[rs] + {{16{immediate[15]}}, immediate[15:0]}] = golden_r[rt];    // sw   (0x06)
            6'b001001: golden_r[rt] = immediate << 16;                                               // lui  (0x09)
            6'b001011: golden_r[31] = jalpc;                                                         // jal  (0x0B)
            default: ;
        endcase

        // out_valid_counter
        out_valid_counter = out_valid_counter+1;

        // check register
        for(i = 0; i < 32; i = i + 1)begin
            if(My_SP.r[i] !== golden_r[i])begin
                display_fail_task;
                $display("-------------------------------------------------------------------");
                $display("*                        PATTERN NO.%4d 	                        *",out_valid_counter);
                $display("*                   register [%2d]  error 	                    *",i);
                $display("*          answer should be : %d , your answer is : %d            *",golden_r[i],My_SP.r[i]);
                $display("-------------------------------------------------------------------");
                repeat(2) @(negedge clk);
                $finish;
            end
        end
        
    end
    else begin
        // check execution cycle
        if(out_valid_counter == 0)begin
            latency = latency+1;
            if(latency == out_max_latency)begin
                $display("***************************************************");     
                $display("*   the execution cycles are more than 10 cycles  *",$time);
                $display("***************************************************");
                repeat(2) @(negedge clk);
                $finish;
            end

        end
        // check out_valid pulled down
        else begin
            $display("************************************************************");     
            $display("*  out_valid should not fall when executing  at %8t        *",$time);
            $display("************************************************************");
            repeat(2) #CYCLE;
            $finish;
        end
    end
    $display("*                        Pass PATTERN NO.%4d 	                  *",out_valid_counter);

end
endtask

// check_memory_and_out_valid
task check_memory_and_out_valid; begin

    // check memory
    for(i = 0; i < 4096; i = i + 1)begin
        if(My_MEM.mem[i] !== mem[i])begin
            display_fail_task;
            $display("-------------------------------------------------------------------");
            $display("*                     MEM [%4d]  error                            *",i);
            $display("*          answer should be : %d , your answer is : %d            *",mem[i],My_MEM.mem[i]);
            $display("-------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
    end

    // check out_valid
    if(out_valid == 1'b1)begin
        $display("************************************************************");     
        $display("*  out_valid should be low after finish execute at %8t     *",$time);
        $display("************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

end
endtask

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
end 
endtask

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

end 
endtask

endmodule