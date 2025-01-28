module SP_pipeline(
	// INPUT SIGNAL
	clk,
	rst_n,
	in_valid,
	inst,
	mem_dout,
	// OUTPUT SIGNAL
	out_valid,
	inst_addr,
	mem_wen,
	mem_addr,
	mem_din
);

//------------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION                         
//------------------------------------------------------------------------

input                    clk, rst_n, in_valid;
input             [31:0] inst;
input  signed     [31:0] mem_dout;   // 32-bit signal from memory
output reg               out_valid;  // Let outputs valid
output reg        [31:0] inst_addr;  // 32-bit address of current instruction
output reg               mem_wen;    // Memory write enable
output reg        [11:0] mem_addr;   // 12-bit Memory address
output reg signed [31:0] mem_din;    // 32-bit signal to write into memory

//------------------------------------------------------------------------
//   DECLARATION
//------------------------------------------------------------------------

// REGISTER FILE, DO NOT EDIT THE NAME.
reg	signed [31:0] r [0:31];   // 32 Register file, each 32-bit
reg signed [31:0] jalpc;      // 32-bit jal pc register
integer i;                    // for loop index

// IF-ID Registers
reg [31:0] IF_ID_immediate;
reg [5:0]  IF_ID_opcode, IF_ID_funct;
reg [4:0]  IF_ID_rs, IF_ID_rt, IF_ID_rd, IF_ID_shamt;
reg        IF_ID_in_valid;
// ID-EX Registers
reg signed [31:0] ID_EX_alu_out;
reg [31:0] ID_EX_immediate;
reg [5:0]  ID_EX_opcode, ID_EX_funct;
reg [4:0]  ID_EX_rs, ID_EX_rt, ID_EX_rd, ID_EX_shamt;
reg        ID_EX_reg_wen, ID_EX_mem_wen, ID_EX_in_valid;
// EX-MEM Registers
reg signed [31:0] EX_MEM_alu_out;
reg [5:0]  EX_MEM_opcode;
reg [4:0]  EX_MEM_rt_rd;
reg        EX_MEM_reg_wen, EX_MEM_mem_wen, EX_MEM_in_valid;
// MEM-WB Registers
reg signed [31:0] MEM_WB_alu_out;
reg [5:0]  MEM_WB_opcode;
reg [4:0]  MEM_WB_rt_rd;
reg        MEM_WB_reg_wen, MEM_WB_in_valid;

//------------------------------------------------------------------------
//   DESIGN
//------------------------------------------------------------------------
// Stage 1: IF (Instruction Fetch)
always @(posedge clk or negedge rst_n) begin
	// Reset signal
    if (!rst_n) begin
        out_valid <= 0;
        inst_addr <= 0;
        mem_wen <= 1;    // Only read
		mem_addr <= 0;
		mem_din <= 0;
		IF_ID_in_valid <= 0;
		IF_ID_opcode <= 0;
		IF_ID_rs <= 0;
		IF_ID_rt <= 0;
		IF_ID_rd <= 0;
		IF_ID_shamt <= 0;
		IF_ID_funct <= 0;
		IF_ID_immediate <= 0;
        for (i = 0; i < 32; i = i + 1) begin
            r[i] <= 0;
        end
		// If in_valid == 1 (from PATTERN), start decoding branch instructions (jr, beq, bne, j, jal)
    end else if (in_valid) begin
		IF_ID_in_valid <= 1;             // Let next stage ID valid
        IF_ID_opcode <= inst[31:26];
        IF_ID_rs <= inst[25:21];
        IF_ID_rt <= inst[20:16];
        IF_ID_rd <= inst[15:11];
		IF_ID_shamt <= inst[10:6];
        IF_ID_funct <= inst[5:0];
		IF_ID_immediate <= inst[15:0];
        case (inst[31:26])
            6'b000000: if (inst[5:0] == 6'b000111) inst_addr <= r[inst[25:21]];                                          // jr  (0x00)
            6'b000111: begin
				if (r[inst[25:21]] == r[inst[20:16]]) inst_addr <= inst_addr + 4 + {{14{inst[15]}}, inst[15:0], 2'b00};  // beq (0x07)
				else inst_addr <= inst_addr + 4;
			end
			6'b001000: begin
				if (r[inst[25:21]] != r[inst[20:16]]) inst_addr <= inst_addr + 4 + {{14{inst[15]}}, inst[15:0], 2'b00};  // bne (0x08)
				else inst_addr <= inst_addr + 4;
			end
			6'b001010: inst_addr <= {inst_addr[31:28], inst[25:0] << 2};                                                 // j   (0x0A)
            6'b001011: begin                                                                                             // jal (0x0B)
                jalpc <= inst_addr + 4;
                inst_addr <= {inst_addr[31:28], inst[25:0] << 2};
            end
            default: ;
        endcase
		// Get next instruction address for those not branch instructions
        if (inst[31:26] != 6'b000111 && inst[31:26] != 6'b001000 && inst[31:26] != 6'b001010 && inst[31:26] != 6'b001011 && !(inst[31:26] == 6'b000000 && inst[5:0] == 6'b000111)) begin
			inst_addr <= inst_addr + 4;
		end
	end else begin
		// End instruction (End IF)
		IF_ID_in_valid <= 0;
	end
end

// Stage 2: ID (Instruction Decode)
always @(posedge clk or negedge rst_n) begin
	// Reset signal
    if (!rst_n) begin
        ID_EX_opcode <= 0;
        ID_EX_rs <= 0;
        ID_EX_rt <= 0;
        ID_EX_rd <= 0;
        ID_EX_shamt <= 0;
        ID_EX_funct <= 0;
        ID_EX_immediate <= 0;
        ID_EX_reg_wen <= 1;    // Only read
        ID_EX_mem_wen <= 1;    // Only read
		ID_EX_in_valid <= 0;
		// If IF_ID_in_valid == 1 (from IF), start decoding instructions
    end else if (IF_ID_in_valid) begin
		ID_EX_in_valid <= 1;             // Let next stage EX valid
        ID_EX_opcode <= IF_ID_opcode;        
        ID_EX_rs <= IF_ID_rs;            
        ID_EX_rt <= IF_ID_rt;                 
        ID_EX_rd <= IF_ID_rd;                  
        ID_EX_shamt <= IF_ID_shamt;          
        ID_EX_funct <= IF_ID_funct;       
        ID_EX_immediate <= IF_ID_immediate;  
        if ((IF_ID_opcode == 6'b000000 && IF_ID_funct == 6'b000111) || IF_ID_opcode == 6'b000111 || IF_ID_opcode == 6'b001000 || IF_ID_opcode == 6'b001010 || IF_ID_opcode == 6'b001011) begin
            ID_EX_reg_wen <= 1;    // Register: Read
            ID_EX_mem_wen <= 1;    // Memory:   Read
        end else if (IF_ID_opcode == 6'b000101) begin  // lw
            ID_EX_reg_wen <= 0;    // Register: Write
            ID_EX_mem_wen <= 1;    // Memory:   Read
        end else if (IF_ID_opcode == 6'b000110) begin  // sw
            ID_EX_reg_wen <= 1;    // Register: Read
            ID_EX_mem_wen <= 0;    // Memory:   Write
        end else begin
            ID_EX_reg_wen <= 0;    // Register: Write
            ID_EX_mem_wen <= 1;    // Memory:   Read
        end
		if (IF_ID_opcode == 6'b000101) begin
			ID_EX_alu_out <= r[IF_ID_rs] + {{16{IF_ID_immediate[15]}}, IF_ID_immediate[15:0]};         // lw   (0x05)
			mem_wen <= 1;
			mem_addr <= r[IF_ID_rs] + {{16{IF_ID_immediate[15]}}, IF_ID_immediate[15:0]};
		end else if (IF_ID_opcode == 6'b000110) begin
			ID_EX_alu_out <= r[IF_ID_rs] + {{16{IF_ID_immediate[15]}}, IF_ID_immediate[15:0]};         // sw   (0x06)
			mem_wen <= 0;
			mem_addr <= r[IF_ID_rs] + {{16{IF_ID_immediate[15]}}, IF_ID_immediate[15:0]};
			mem_din <= r[IF_ID_rt];
        end
	end else begin
		// End ID
		ID_EX_in_valid <= 0;
	end
end

// Stage 3: EX (Execution)
always @(posedge clk or negedge rst_n) begin
	// Reset signal
    if (!rst_n) begin
        EX_MEM_alu_out <= 0;
        EX_MEM_rt_rd <= 0;
        EX_MEM_mem_wen <= 1;   // Only read
        EX_MEM_reg_wen <= 1;   // Only read
        EX_MEM_opcode <= 0;
		EX_MEM_in_valid <= 0;
		// If ID_EX_in_valid == 1 (from ID), start computing with ALU & Read / Write Memory
    end else if (ID_EX_in_valid) begin
		EX_MEM_in_valid <= 1;              // Let next stage MEM valid
        EX_MEM_mem_wen <= ID_EX_mem_wen;
        EX_MEM_reg_wen <= ID_EX_reg_wen;
        EX_MEM_opcode <= ID_EX_opcode;
		EX_MEM_alu_out <= ID_EX_alu_out;
        case (ID_EX_opcode)
			// ================ R-Type ================
            6'b000000: begin
                case (ID_EX_funct)
					6'b000000: EX_MEM_alu_out <= r[ID_EX_rs] & r[ID_EX_rt];         // and (0x00)
					6'b000001: EX_MEM_alu_out <= r[ID_EX_rs] | r[ID_EX_rt];         // or  (0x01)
                    6'b000010: EX_MEM_alu_out <= r[ID_EX_rs] + r[ID_EX_rt];         // add (0x02)
                    6'b000011: EX_MEM_alu_out <= r[ID_EX_rs] - r[ID_EX_rt];         // sub (0x03)
                    6'b000100: EX_MEM_alu_out <= (r[ID_EX_rs] < r[ID_EX_rt])? 1:0;  // slt (0x04)
					6'b000101: EX_MEM_alu_out <= r[ID_EX_rs] << ID_EX_shamt;        // sll (0x05)
					6'b000110: EX_MEM_alu_out <= ~(r[ID_EX_rs] | r[ID_EX_rt]);      // nor (0x06)
					default: ;
                endcase
				EX_MEM_rt_rd <= ID_EX_rd;  // Pass rd as the destination register for the WB stage
            end
			// ================ I-Type ================
			6'b000001: EX_MEM_alu_out <= r[ID_EX_rs] & {16'b0, ID_EX_immediate[15:0]};                      // andi (0x01)
			6'b000010: EX_MEM_alu_out <= r[ID_EX_rs] | {16'b0, ID_EX_immediate[15:0]};                      // ori  (0x02)
			6'b000011: EX_MEM_alu_out <= r[ID_EX_rs] + {{16{ID_EX_immediate[15]}}, ID_EX_immediate[15:0]};  // addi (0x03)
			6'b000100: EX_MEM_alu_out <= r[ID_EX_rs] - {{16{ID_EX_immediate[15]}}, ID_EX_immediate[15:0]};  // subi (0x04)
			// 6'b000101: begin
			// 	EX_MEM_alu_out <= r[ID_EX_rs] + {{16{ID_EX_immediate[15]}}, ID_EX_immediate[15:0]};         // lw   (0x05)
			// 	mem_wen <= 1;
			// 	mem_addr <= r[ID_EX_rs] + {{16{ID_EX_immediate[15]}}, ID_EX_immediate[15:0]};
			// end
			// 6'b000110: begin
			// 	EX_MEM_alu_out <= r[ID_EX_rs] + {{16{ID_EX_immediate[15]}}, ID_EX_immediate[15:0]};         // sw   (0x06)
			// 	mem_wen <= 0;
			// 	mem_addr <= r[ID_EX_rs] + {{16{ID_EX_immediate[15]}}, ID_EX_immediate[15:0]};
			// 	mem_din <= r[ID_EX_rt];
            // end
			6'b001001: EX_MEM_alu_out <= ID_EX_immediate << 16;                                             // lui  (0x09)
        endcase
		// Pass rt as the destination register for the WB stage (Except for R-Type Instructions)
		if (ID_EX_opcode != 6'b000000) EX_MEM_rt_rd <= ID_EX_rt;
    end else begin
		// End EX
		EX_MEM_in_valid <= 0;
	end
end

// Stage 4: MEM (Memory Read / Write)
always @(posedge clk or negedge rst_n) begin
	// Reset signal
    if (!rst_n) begin
        MEM_WB_alu_out <= 0;
		MEM_WB_rt_rd <= 0;
		MEM_WB_reg_wen <= 1;  // Only read
		MEM_WB_opcode <= 0;
		// If EX_MEM_in_valid == 1 (from EX), just pass the data that WB stage need
    end else if (EX_MEM_in_valid) begin
		// MEM_WB_in_valid <= 1;               // Let next stage WB valid
		// MEM_WB_reg_wen <= EX_MEM_reg_wen;
        // MEM_WB_alu_out <= EX_MEM_alu_out;
		// MEM_WB_rt_rd <= EX_MEM_rt_rd;
		// MEM_WB_opcode <= EX_MEM_opcode;
		out_valid <= 1;
		if (EX_MEM_reg_wen == 0) begin
			if (EX_MEM_opcode == 6'b000101) r[EX_MEM_rt_rd] <= mem_dout;
			else r[EX_MEM_rt_rd] <= EX_MEM_alu_out;
		end
		if (EX_MEM_opcode == 6'b001011) r[31] <= jalpc;
    end else begin
		// End MEM
		//MEM_WB_in_valid <= 0;
		out_valid <= 0;
	end
end

// // Stage 5: WB (Write Back)
// always @(posedge clk or negedge rst_n) begin
//     if (!rst_n) begin
//         // Do not need to restart any signal
// 		// If MEM_WB_in_valid == 1 (from MEM), write data into the destination register
//     end else if (MEM_WB_in_valid) begin
// 		out_valid <= 1;                    // Let output valid (Let PATTERN check)
//         if (MEM_WB_reg_wen == 0) begin     // Register: Write
// 			if (MEM_WB_opcode == 6'b000101) r[MEM_WB_rt_rd] <= mem_dout;    // For lw
// 			else r[MEM_WB_rt_rd] <= MEM_WB_alu_out;                         // For other instructions
// 		end
// 		if (MEM_WB_opcode == 6'b001011) r[31] <= jalpc;                     // For jal
// 	end else begin
// 		// End WB
// 		out_valid <= 0;
// 	end
// end

endmodule