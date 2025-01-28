module SP(
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
reg signed [31:0] pc;         // 32-bit Program counter
reg signed [31:0] alu_out;    // ALU output
reg [5:0] opcode, funct;      // Instruction field
reg [4:0] rs, rt, rd, shamt;  // Registers
reg [31:0] immediate;         // immediate
reg [2:0] delay_counter;      // Clock counter
integer i;                    // for loop index

//------------------------------------------------------------------------
//   DESIGN
//------------------------------------------------------------------------

// Execute when clk positive-edge or rst_n negative-edge 
always @(posedge clk, negedge rst_n) begin
	// If rst_n == 0, reset all signal
	if (!rst_n) begin
		pc <= 0;
		inst_addr <= 0;
		out_valid <= 0;
		mem_wen <= 1;            // Only read
		mem_addr <= 0;
		mem_din <= 0;
		delay_counter <= 7;
		for (i = 0; i < 32; i = i + 1) begin
            r[i] <= 0;
        end
	// If in_valid == 1 (from PATTERN), start decoding
	end else if (in_valid) begin
		delay_counter <= 0;
		mem_wen <= 1;            // Only read
		opcode = inst[31:26];
		rs = inst[25:21];
		rt = inst[20:16];
		rd = inst[15:11];
		shamt = inst[10:6];
		funct = inst[5:0];
		immediate = inst[15:0];
		// Execute instuction
		case (opcode)
			// ================ R-Type ================
			6'b000000: begin
				case (funct)
					6'b000000: alu_out <= r[rs] & r[rt];         // and (0x00)
					6'b000001: alu_out <= r[rs] | r[rt];         // or  (0x01)
					6'b000010: alu_out <= r[rs] + r[rt];         // add (0x02)
					6'b000011: alu_out <= r[rs] - r[rt];         // sub (0x03)
					6'b000100: alu_out <= (r[rs] < r[rt])? 1:0;  // slt (0x04)
					6'b000101: alu_out <= r[rs] << shamt;        // sll (0x05)
					6'b000110: alu_out <= ~(r[rs] | r[rt]);      // nor (0x06)
					6'b000111: pc <= r[rs];                      // jr  (0x07)
					default: ;
				endcase
			end
			// ================ I-Type ================
			6'b000001: r[rt] <= r[rs] & {16'b0, immediate[15:0]};                  // r[rt] = r[rs] & ZE(imm): andi (0x01)
			6'b000010: r[rt] <= r[rs] | {16'b0, immediate[15:0]};                  // r[rt] = r[rs] | ZE(imm): ori  (0x02)
			6'b000011: r[rt] <= r[rs] + {{16{immediate[15]}}, immediate[15:0]};    // r[rt] = r[rs] + SE(imm): addi (0x03)
			6'b000100: r[rt] <= r[rs] - {{16{immediate[15]}}, immediate[15:0]};    // r[rt] = r[rs] - SE(imm): subi (0x04)
			6'b000111: begin
				if (r[rs] == r[rt]) pc <= pc + 4 + {{14{immediate[15]}}, immediate[15:0], 2'b00};   // beq (0x07)
				else pc <= pc + 4;
			end
			6'b001000: begin
				if (r[rs] != r[rt]) pc <= pc + 4 + {{14{immediate[15]}}, immediate[15:0], 2'b00};   // bne (0x08)
				else pc <= pc + 4;
			end
			6'b001001: r[rt] <= immediate << 16;              // lui (0x09)
			// ================ J-Type ================
			6'b001010: pc <= {pc[31:28], inst[25:0] << 2};    // j   (0x0A)
			6'b001011: begin
				r[31] <= pc + 4;
				pc <= {pc[31:28], inst[25:0] << 2};           // jal (0x0B)
			end
			default: ;
		endcase
		// Get next instruction address for those not branch instructions
		if (opcode != 6'b000111 && opcode != 6'b001000 && opcode != 6'b001010 && opcode != 6'b001011 && !(opcode == 6'b000000 && funct == 6'b000111)) pc <= pc + 4;
		// Clock counter part
	end else if (delay_counter != 7) begin
		delay_counter <= delay_counter + 1;
		if (delay_counter == 0) begin
			// Load alu_out into mem_addr continuously
			mem_addr <= alu_out;
			// For R-Type
			if (opcode == 6'b000000 && funct != 6'b000111) r[rd] <= alu_out;
			// For lw (Read memory part)
			if (opcode == 6'b000101) begin
				mem_wen <= 1;
				mem_addr <= r[rs] + {{16{immediate[15]}}, immediate[15:0]};
				// For sw
			end else if (opcode == 6'b000110) begin
				mem_wen <= 0;
				mem_addr <= r[rs] + {{16{immediate[15]}}, immediate[15:0]};
			 	mem_din <= r[rt];
			end
		end else if (delay_counter == 1) begin
			// Refresh program count
			inst_addr <= pc;
		end else if (delay_counter == 2) begin
			// For lw (Write register part)
			if (opcode == 6'b000101) r[rt] <= mem_dout;
		end else if (delay_counter == 3) begin
			// Start output (Let PATTERN check)
			out_valid <= 1;
		end else if (delay_counter == 4) begin
			// Stop output & refresh delay_counter for next cycle
			out_valid <= 0;
            delay_counter <= 0;
		end
	end
end


endmodule