`timescale 1ns / 1ps

module pc_reg(
    input clk,
    input rst,
    input stall,
    input [31:0] pc_next,
    output reg [31:0] pc
);
    always @(posedge clk) begin
        if (rst) pc <= 32'h0000_0000;
        else if (!stall) pc <= pc_next;
    end
endmodule

module instr_mem(
    input [31:0] addr,
    output [31:0] instr
);
    reg [31:0] ram [0:1023];
    initial $readmemh("imem.mem", ram);
    assign instr = ram[addr[11:2]];
endmodule

module if_id_reg(
    input clk,
    input rst,
    input stall,
    input flush,
    input [31:0] pc_in,
    input [31:0] instr_in,
    output reg [31:0] pc_out,
    output reg [31:0] instr_out
);
    always @(posedge clk) begin
        if (rst || flush) begin
            pc_out <= 32'd0;
            instr_out <= 32'h00000013; // NOP
        end else if (!stall) begin
            pc_out <= pc_in;
            instr_out <= instr_in;
        end
    end
endmodule

module reg_file(
    input clk,
    input [4:0] rs1_addr,
    input [4:0] rs2_addr,
    input [4:0] rd_addr,
    input [31:0] rd_data,
    input reg_write,
    output [31:0] rs1_data,
    output [31:0] rs2_data
);
    reg [31:0] registers [0:31];
    integer i;
    initial begin
        for(i=0; i<32; i=i+1) registers[i] = 32'd0;
    end
    always @(posedge clk) begin
        if (reg_write && rd_addr != 5'd0) begin
            registers[rd_addr] <= rd_data;
        end
    end
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : 
                      (reg_write && rs1_addr == rd_addr) ? rd_data : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : 
                      (reg_write && rs2_addr == rd_addr) ? rd_data : registers[rs2_addr];
endmodule

module imm_gen(
    input [31:0] instr,
    input [2:0] imm_src,
    output reg [31:0] imm_ext
);
    always @(*) begin
        case(imm_src)
            3'b000: imm_ext = {{20{instr[31]}}, instr[31:20]}; // I-type
            3'b001: imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
            3'b010: imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
            3'b011: imm_ext = {instr[31:12], 12'd0}; // U-type
            3'b100: imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type
            default: imm_ext = 32'd0;
        endcase
    end
endmodule

module control_unit(
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg RegWrite,
    output reg ALUSrc,
    output reg MemRead,
    output reg MemWrite,
    output reg [2:0] ResultSrc,
    output reg Branch,
    output reg Jump,
    output reg [2:0] ImmSrc,
    output reg [3:0] ALUCtrl,
    output reg ALUEn
);
    wire op_5 = opcode[5];
    wire f7_5 = funct7[5];
    
    always @(*) begin
        RegWrite = 0; ALUSrc = 0; MemRead = 0; MemWrite = 0;
        ResultSrc = 3'b000; Branch = 0; Jump = 0; ImmSrc = 3'b000;
        ALUCtrl = 4'b0000; ALUEn = 1;
        
        case(opcode)
            7'b0110011: begin // R-type
                RegWrite = 1; ResultSrc = 3'b000;
                ALUEn = 1; ALUSrc = 0;
                if (funct3 == 3'b000) ALUCtrl = f7_5 ? 4'b0001 : 4'b0000;
                else if (funct3 == 3'b001) ALUCtrl = 4'b0010;
                else if (funct3 == 3'b010) ALUCtrl = 4'b0011;
                else if (funct3 == 3'b011) ALUCtrl = 4'b0100;
                else if (funct3 == 3'b100) ALUCtrl = 4'b0101;
                else if (funct3 == 3'b101) ALUCtrl = f7_5 ? 4'b0111 : 4'b0110;
                else if (funct3 == 3'b110) ALUCtrl = 4'b1000;
                else if (funct3 == 3'b111) ALUCtrl = 4'b1001;
            end
            7'b0010011: begin // I-type ALU
                RegWrite = 1; ALUSrc = 1; ResultSrc = 3'b000; ImmSrc = 3'b000; ALUEn = 1;
                if (funct3 == 3'b000) ALUCtrl = 4'b0000;
                else if (funct3 == 3'b010) ALUCtrl = 4'b0011;
                else if (funct3 == 3'b011) ALUCtrl = 4'b0100;
                else if (funct3 == 3'b100) ALUCtrl = 4'b0101;
                else if (funct3 == 3'b110) ALUCtrl = 4'b1000;
                else if (funct3 == 3'b111) ALUCtrl = 4'b1001;
                else if (funct3 == 3'b001) ALUCtrl = 4'b0010;
                else if (funct3 == 3'b101) ALUCtrl = f7_5 ? 4'b0111 : 4'b0110;
            end
            7'b0000011: begin // Load
                RegWrite = 1; ALUSrc = 1; MemRead = 1; ResultSrc = 3'b001; ImmSrc = 3'b000;
                ALUCtrl = 4'b0000; ALUEn = 1;
            end
            7'b0100011: begin // Store
                ALUSrc = 1; MemWrite = 1; ImmSrc = 3'b001;
                ALUCtrl = 4'b0000; ALUEn = 1;
            end
            7'b1100011: begin // Branch
                Branch = 1; ImmSrc = 3'b010;
                ALUCtrl = 4'b0001; ALUEn = 1;
            end
            7'b1101111: begin // JAL
                RegWrite = 1; Jump = 1; ResultSrc = 3'b010; ImmSrc = 3'b100;
                ALUEn = 0;
            end
            7'b1100111: begin // JALR
                RegWrite = 1; Jump = 1; ALUSrc = 1; ResultSrc = 3'b010; ImmSrc = 3'b000;
                ALUCtrl = 4'b0000; ALUEn = 1;
            end
            7'b0110111: begin // LUI
                RegWrite = 1; ResultSrc = 3'b100; ImmSrc = 3'b011;
                ALUEn = 0;
            end
            7'b0010111: begin // AUIPC
                RegWrite = 1; ResultSrc = 3'b011; ImmSrc = 3'b011;
                ALUEn = 0;
            end
            default: ALUEn = 0;
        endcase
    end
endmodule

module id_ex_reg(
    input clk, input rst, input flush,
    
    input [31:0] pc_in,
    input [31:0] rs1_data_in, input [31:0] rs2_data_in,
    input [31:0] imm_ext_in,
    input [4:0] rs1_addr_in, input [4:0] rs2_addr_in, input [4:0] rd_addr_in,
    input [2:0] funct3_in,
    input RegWrite_in, input ALUSrc_in, input MemRead_in, input MemWrite_in,
    input [2:0] ResultSrc_in, input Branch_in, input Jump_in,
    input [3:0] ALUCtrl_in, input ALUEn_in,
    
    output reg [31:0] pc_out,
    output reg [31:0] rs1_data_out, output reg [31:0] rs2_data_out,
    output reg [31:0] imm_ext_out,
    output reg [4:0] rs1_addr_out, output reg [4:0] rs2_addr_out, output reg [4:0] rd_addr_out,
    output reg [2:0] funct3_out,
    output reg RegWrite_out, output reg ALUSrc_out, output reg MemRead_out, output reg MemWrite_out,
    output reg [2:0] ResultSrc_out, output reg Branch_out, output reg Jump_out,
    output reg [3:0] ALUCtrl_out, output reg ALUEn_out
);
    always @(posedge clk) begin
        if (rst || flush) begin
            pc_out <= 0; rs1_data_out <= 0; rs2_data_out <= 0; imm_ext_out <= 0;
            rs1_addr_out <= 0; rs2_addr_out <= 0; rd_addr_out <= 0; funct3_out <= 0;
            RegWrite_out <= 0; ALUSrc_out <= 0; MemRead_out <= 0; MemWrite_out <= 0;
            ResultSrc_out <= 0; Branch_out <= 0; Jump_out <= 0; ALUCtrl_out <= 0; ALUEn_out <= 0;
        end else begin
            pc_out <= pc_in; rs1_data_out <= rs1_data_in; rs2_data_out <= rs2_data_in; imm_ext_out <= imm_ext_in;
            rs1_addr_out <= rs1_addr_in; rs2_addr_out <= rs2_addr_in; rd_addr_out <= rd_addr_in; funct3_out <= funct3_in;
            RegWrite_out <= RegWrite_in; ALUSrc_out <= ALUSrc_in; MemRead_out <= MemRead_in; MemWrite_out <= MemWrite_in;
            ResultSrc_out <= ResultSrc_in; Branch_out <= Branch_in; Jump_out <= Jump_in; ALUCtrl_out <= ALUCtrl_in; ALUEn_out <= ALUEn_in;
        end
    end
endmodule

module alu(
    input [31:0] a, b,
    input [3:0] alu_ctrl,
    input alu_en,
    output reg [31:0] result
);
    wire signed [31:0] sa = a;
    wire signed [31:0] sb = b;
    
    // Operand isolation for power optimization
    wire [31:0] op_a = alu_en ? a : 32'd0;
    wire [31:0] op_b = alu_en ? b : 32'd0;
    
    always @(*) begin
        case(alu_ctrl)
            4'b0000: result = op_a + op_b; // ADD
            4'b1000: result = op_a - op_b; // SUB
            4'b0001: result = op_a << op_b[4:0]; // SLL
            4'b0010: result = (sa < sb) ? 32'd1 : 32'd0; // SLT
            4'b0011: result = (op_a < op_b) ? 32'd1 : 32'd0; // SLTU
            4'b0100: result = op_a ^ op_b; // XOR
            4'b0101: result = op_a >> op_b[4:0]; // SRL
            4'b1101: result = sa >>> op_b[4:0]; // SRA
            4'b0110: result = op_a | op_b; // OR
            4'b0111: result = op_a & op_b; // AND
            default: result = 32'd0;
        endcase
    end
endmodule

module pc_adder(
    input [31:0] pc_ex,
    input [31:0] imm_ext,
    output [31:0] pc_target
);
    assign pc_target = pc_ex + imm_ext;
endmodule

module branch_resolve(
    input [2:0] branch_type,
    input [31:0] a, b,
    output reg cond
);
    wire signed [31:0] sa = a;
    wire signed [31:0] sb = b;
    always @(*) begin
        case(branch_type)
            3'b000: cond = (a == b); // BEQ
            3'b001: cond = (a != b); // BNE
            3'b100: cond = (sa < sb); // BLT
            3'b101: cond = (sa >= sb); // BGE
            3'b110: cond = (a < b); // BLTU
            3'b111: cond = (a >= b); // BGEU
            default: cond = 1'b0;
        endcase
    end
endmodule

module forward_unit(
    input [4:0] ex_mem_rd,
    input [4:0] mem_wb_rd,
    input ex_mem_regwrite,
    input mem_wb_regwrite,
    input [4:0] id_ex_rs1,
    input [4:0] id_ex_rs2,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);
    always @(*) begin
        if (ex_mem_regwrite && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        else if (mem_wb_regwrite && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;
            
        if (ex_mem_regwrite && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_regwrite && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
endmodule

module hazard_unit(
    input id_ex_memread,
    input [4:0] id_ex_rd,
    input [4:0] if_id_rs1,
    input [4:0] if_id_rs2,
    output stall,
    output flush_id_ex
);
    wire lwstall = id_ex_memread && (id_ex_rd != 0) && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
    assign stall = lwstall;
    assign flush_id_ex = lwstall;
endmodule

module ex_mem_reg(
    input clk, rst, flush,
    input [31:0] alu_result_in, pc_target_in, pc_plus4_in,
    input [31:0] write_data_in, imm_ext_in,
    input [4:0] rd_addr_in,
    input RegWrite_in, MemRead_in, MemWrite_in,
    input [2:0] ResultSrc_in, funct3_in,
    
    // NEW: Branch signals needed in MEM
    input Branch_in, Jump_in, ALUSrc_in,
    input cond_in,
    
    output reg [31:0] alu_result_out, pc_target_out, pc_plus4_out,
    output reg [31:0] write_data_out, imm_ext_out,
    output reg [4:0] rd_addr_out,
    output reg RegWrite_out, MemRead_out, MemWrite_out,
    output reg [2:0] ResultSrc_out, funct3_out,
    
    output reg Branch_out, Jump_out, ALUSrc_out,
    output reg cond_out
);
    always @(posedge clk) begin
        if (rst || flush) begin
            alu_result_out <= 0; pc_target_out <= 0; pc_plus4_out <= 0;
            write_data_out <= 0; imm_ext_out <= 0;
            rd_addr_out <= 0;
            RegWrite_out <= 0; MemRead_out <= 0; MemWrite_out <= 0;
            ResultSrc_out <= 0; funct3_out <= 0;
            Branch_out <= 0; Jump_out <= 0; ALUSrc_out <= 0; cond_out <= 0;
        end else begin
            alu_result_out <= alu_result_in; pc_target_out <= pc_target_in; pc_plus4_out <= pc_plus4_in;
            write_data_out <= write_data_in; imm_ext_out <= imm_ext_in;
            rd_addr_out <= rd_addr_in;
            RegWrite_out <= RegWrite_in; MemRead_out <= MemRead_in; MemWrite_out <= MemWrite_in;
            ResultSrc_out <= ResultSrc_in; funct3_out <= funct3_in;
            Branch_out <= Branch_in; Jump_out <= Jump_in; ALUSrc_out <= ALUSrc_in; cond_out <= cond_in;
        end
    end
endmodule

module data_mem(
    input clk,
    input [31:0] addr,
    input [31:0] write_data,
    input mem_write,
    input mem_read,
    input [2:0] funct3,
    output reg [31:0] read_data,
    output reg [31:0] test_result
);
    reg [31:0] ram [0:1023];
    initial begin
        $readmemh("dmem.mem", ram);
        test_result = 32'd0;
    end
    
    wire [29:0] word_addr = addr[31:2];
    
    always @(posedge clk) begin
        if (mem_write) begin
            if (addr == 32'h00000FFC) begin
                test_result <= write_data;
            end else begin
                case(funct3[1:0])
                    2'b00: begin
                        if (addr[1:0] == 2'b00) ram[word_addr][7:0]   <= write_data[7:0];
                        if (addr[1:0] == 2'b01) ram[word_addr][15:8]  <= write_data[7:0];
                        if (addr[1:0] == 2'b10) ram[word_addr][23:16] <= write_data[7:0];
                        if (addr[1:0] == 2'b11) ram[word_addr][31:24] <= write_data[7:0];
                    end
                    2'b01: begin
                        if (addr[1] == 1'b0) ram[word_addr][15:0]  <= write_data[15:0];
                        if (addr[1] == 1'b1) ram[word_addr][31:16] <= write_data[15:0];
                    end
                    2'b10: ram[word_addr] <= write_data;
                endcase
            end
        end
    end
    
    always @(*) begin
        if (mem_read) begin
            case(funct3)
                3'b000: begin
                    if (addr[1:0] == 2'b00) read_data = {{24{ram[word_addr][7]}}, ram[word_addr][7:0]};
                    else if (addr[1:0] == 2'b01) read_data = {{24{ram[word_addr][15]}}, ram[word_addr][15:8]};
                    else if (addr[1:0] == 2'b10) read_data = {{24{ram[word_addr][23]}}, ram[word_addr][23:16]};
                    else read_data = {{24{ram[word_addr][31]}}, ram[word_addr][31:24]};
                end
                3'b001: begin
                    if (addr[1] == 1'b0) read_data = {{16{ram[word_addr][15]}}, ram[word_addr][15:0]};
                    else read_data = {{16{ram[word_addr][31]}}, ram[word_addr][31:16]};
                end
                3'b010: read_data = ram[word_addr];
                3'b100: begin
                    if (addr[1:0] == 2'b00) read_data = {24'd0, ram[word_addr][7:0]};
                    else if (addr[1:0] == 2'b01) read_data = {24'd0, ram[word_addr][15:8]};
                    else if (addr[1:0] == 2'b10) read_data = {24'd0, ram[word_addr][23:16]};
                    else read_data = {24'd0, ram[word_addr][31:24]};
                end
                3'b101: begin
                    if (addr[1] == 1'b0) read_data = {16'd0, ram[word_addr][15:0]};
                    else read_data = {16'd0, ram[word_addr][31:16]};
                end
                default: read_data = 32'd0;
            endcase
        end else begin
            read_data = 32'd0;
        end
    end
endmodule

module mem_wb_reg(
    input clk, input rst,
    input [31:0] alu_result_in, input [31:0] mem_read_data_in, input [31:0] pc_plus4_in,
    input [31:0] pc_target_in, input [31:0] imm_ext_in, input [4:0] rd_addr_in,
    input RegWrite_in, input [2:0] ResultSrc_in,
    
    output reg [31:0] alu_result_out, output reg [31:0] mem_read_data_out, output reg [31:0] pc_plus4_out,
    output reg [31:0] pc_target_out, output reg [31:0] imm_ext_out, output reg [4:0] rd_addr_out,
    output reg RegWrite_out, output reg [2:0] ResultSrc_out
);
    always @(posedge clk) begin
        if (rst) begin
            alu_result_out <= 0; mem_read_data_out <= 0; pc_plus4_out <= 0;
            pc_target_out <= 0; imm_ext_out <= 0; rd_addr_out <= 0;
            RegWrite_out <= 0; ResultSrc_out <= 0;
        end else begin
            alu_result_out <= alu_result_in; mem_read_data_out <= mem_read_data_in; pc_plus4_out <= pc_plus4_in;
            pc_target_out <= pc_target_in; imm_ext_out <= imm_ext_in; rd_addr_out <= rd_addr_in;
            RegWrite_out <= RegWrite_in; ResultSrc_out <= ResultSrc_in;
        end
    end
endmodule

module wb_mux(
    input [2:0] result_src,
    input [31:0] alu_result,
    input [31:0] mem_read_data,
    input [31:0] pc_plus4,
    input [31:0] pc_target,
    input [31:0] imm_ext,
    output reg [31:0] rd_data
);
    always @(*) begin
        case(result_src)
            3'b000: rd_data = alu_result;
            3'b001: rd_data = mem_read_data;
            3'b010: rd_data = pc_plus4;
            3'b011: rd_data = pc_target;
            3'b100: rd_data = imm_ext;
            default: rd_data = 32'd0;
        endcase
    end
endmodule

module rv32i_core(
    input clk, rst,
    // Instruction Memory Interface
    output [31:0] pc_if,
    input [31:0] instr_if,
    // Data Memory Interface
    output [31:0] alu_result_mem,
    output [31:0] write_data_mem,
    output MemWrite_mem,
    output MemRead_mem,
    output [2:0] funct3_mem,
    input [31:0] mem_read_data_mem
);
    // Fetch
    wire [31:0] pc_next;
    wire stall, flush_id_ex, flush_ex_mem, pc_redirect;
    wire [31:0] redirect_target;
    
    wire [31:0] pc_plus4_if = pc_if + 32'd4;
    assign pc_next = pc_redirect ? redirect_target : pc_plus4_if;
    
    pc_reg PC(
        .clk(clk), .rst(rst), .stall(stall), .pc_next(pc_next), .pc(pc_if)
    );
    
    // Decode
    wire [31:0] pc_id, instr_id;
    if_id_reg IF_ID(
        .clk(clk), .rst(rst), .stall(stall), .flush(pc_redirect),
        .pc_in(pc_if), .instr_in(instr_if),
        .pc_out(pc_id), .instr_out(instr_id)
    );
    
    wire [4:0] rs1_addr_id = instr_id[19:15];
    wire [4:0] rs2_addr_id = instr_id[24:20];
    wire [4:0] rd_addr_id = instr_id[11:7];
    
    wire [31:0] rs1_data_id, rs2_data_id, rd_data_wb;
    wire reg_write_wb;
    wire [4:0] rd_addr_wb;
    
    reg_file RF(
        .clk(clk), .rs1_addr(rs1_addr_id), .rs2_addr(rs2_addr_id), .rd_addr(rd_addr_wb),
        .rd_data(rd_data_wb), .reg_write(reg_write_wb),
        .rs1_data(rs1_data_id), .rs2_data(rs2_data_id)
    );
    
    wire RegWrite_id, ALUSrc_id, MemRead_id, MemWrite_id, Branch_id, Jump_id, ALUEn_id;
    wire [2:0] ResultSrc_id, ImmSrc_id;
    wire [3:0] ALUCtrl_id;
    
    control_unit CU(
        .opcode(instr_id[6:0]), .funct3(instr_id[14:12]), .funct7(instr_id[31:25]),
        .RegWrite(RegWrite_id), .ALUSrc(ALUSrc_id), .MemRead(MemRead_id), .MemWrite(MemWrite_id),
        .ResultSrc(ResultSrc_id), .Branch(Branch_id), .Jump(Jump_id), .ImmSrc(ImmSrc_id),
        .ALUCtrl(ALUCtrl_id), .ALUEn(ALUEn_id)
    );
    
    wire [31:0] imm_ext_id;
    imm_gen IG(
        .instr(instr_id), .imm_src(ImmSrc_id), .imm_ext(imm_ext_id)
    );
    
    // Execute
    wire [31:0] pc_ex, rs1_data_ex, rs2_data_ex, imm_ext_ex;
    wire [4:0] rs1_addr_ex, rs2_addr_ex, rd_addr_ex;
    wire [2:0] funct3_ex, ResultSrc_ex;
    wire RegWrite_ex, ALUSrc_ex, MemRead_ex, MemWrite_ex, Branch_ex, Jump_ex, ALUEn_ex;
    wire [3:0] ALUCtrl_ex;
    
    id_ex_reg ID_EX(
        .clk(clk), .rst(rst), .flush(flush_id_ex || pc_redirect),
        .pc_in(pc_id), .rs1_data_in(rs1_data_id), .rs2_data_in(rs2_data_id), .imm_ext_in(imm_ext_id),
        .rs1_addr_in(rs1_addr_id), .rs2_addr_in(rs2_addr_id), .rd_addr_in(rd_addr_id), .funct3_in(instr_id[14:12]),
        .RegWrite_in(RegWrite_id), .ALUSrc_in(ALUSrc_id), .MemRead_in(MemRead_id), .MemWrite_in(MemWrite_id),
        .ResultSrc_in(ResultSrc_id), .Branch_in(Branch_id), .Jump_in(Jump_id), .ALUCtrl_in(ALUCtrl_id), .ALUEn_in(ALUEn_id),
        
        .pc_out(pc_ex), .rs1_data_out(rs1_data_ex), .rs2_data_out(rs2_data_ex), .imm_ext_out(imm_ext_ex),
        .rs1_addr_out(rs1_addr_ex), .rs2_addr_out(rs2_addr_ex), .rd_addr_out(rd_addr_ex), .funct3_out(funct3_ex),
        .RegWrite_out(RegWrite_ex), .ALUSrc_out(ALUSrc_ex), .MemRead_out(MemRead_ex), .MemWrite_out(MemWrite_ex),
        .ResultSrc_out(ResultSrc_ex), .Branch_out(Branch_ex), .Jump_out(Jump_ex), .ALUCtrl_out(ALUCtrl_ex), .ALUEn_out(ALUEn_ex)
    );
    wire [1:0] forward_a, forward_b;
    
    // Memory stage forward data mux (resolves LUI, JAL, AUIPC in MEM stage)
    reg [31:0] forward_data_mem;
    always @(*) begin
        case(ResultSrc_mem)
            3'b000: forward_data_mem = alu_result_mem;
            3'b010: forward_data_mem = pc_plus4_mem;
            3'b011: forward_data_mem = pc_target_mem;
            3'b100: forward_data_mem = imm_ext_mem;
            default: forward_data_mem = alu_result_mem; // Loads stall, so this path is ignored
        endcase
    end
    
    wire [31:0] src_a = (forward_a == 2'b10) ? forward_data_mem :
                        (forward_a == 2'b01) ? rd_data_wb : rs1_data_ex;
                        
    wire [31:0] forwarded_rs2 = (forward_b == 2'b10) ? forward_data_mem :
                                (forward_b == 2'b01) ? rd_data_wb : rs2_data_ex;
                                
    wire [31:0] src_b = ALUSrc_ex ? imm_ext_ex : forwarded_rs2;
    
    // Operand Isolation
    wire [31:0] alu_in_a = ALUEn_ex ? src_a : 32'd0;
    wire [31:0] alu_in_b = ALUEn_ex ? src_b : 32'd0;
    
    wire [31:0] alu_result_ex;
    wire zero, lt, ltu;
    
    alu ALU(
        .a(alu_in_a), .b(alu_in_b), .alu_ctrl(ALUCtrl_ex),
        .alu_en(ALUEn_ex), .result(alu_result_ex)
    );
    
    wire [31:0] pc_target_ex;
    pc_adder PC_ADDER(
        .pc_ex(pc_ex), .imm_ext(imm_ext_ex), .pc_target(pc_target_ex)
    );
    
    // Cond is computed in EX
    wire cond;
    branch_resolve BR(.branch_type(funct3_ex), .a(src_a), .b(src_b), .cond(cond));
    
    // Memory
    wire RegWrite_mem;
    wire [31:0] pc_plus4_mem, pc_target_mem, imm_ext_mem;
    wire [4:0] rd_addr_mem;
    wire [2:0] ResultSrc_mem;
    wire Branch_mem, Jump_mem, ALUSrc_mem, cond_mem;
    
    ex_mem_reg EX_MEM(
        .clk(clk), .rst(rst), .flush(flush_ex_mem),
        .alu_result_in(alu_result_ex), .pc_target_in(pc_target_ex), .pc_plus4_in(pc_ex + 32'd4),
        .write_data_in(forwarded_rs2), .imm_ext_in(imm_ext_ex), .rd_addr_in(rd_addr_ex),
        .RegWrite_in(RegWrite_ex), .MemRead_in(MemRead_ex), .MemWrite_in(MemWrite_ex), .ResultSrc_in(ResultSrc_ex), .funct3_in(funct3_ex),
        .Branch_in(Branch_ex), .Jump_in(Jump_ex), .ALUSrc_in(ALUSrc_ex), .cond_in(cond),
        
        .alu_result_out(alu_result_mem), .pc_target_out(pc_target_mem), .pc_plus4_out(pc_plus4_mem),
        .write_data_out(write_data_mem), .imm_ext_out(imm_ext_mem), .rd_addr_out(rd_addr_mem),
        .RegWrite_out(RegWrite_mem), .MemRead_out(MemRead_mem), .MemWrite_out(MemWrite_mem), .ResultSrc_out(ResultSrc_mem), .funct3_out(funct3_mem),
        .Branch_out(Branch_mem), .Jump_out(Jump_mem), .ALUSrc_out(ALUSrc_mem), .cond_out(cond_mem)
    );
    
    // Branch evaluation moved to MEM
    assign pc_redirect = (Branch_mem && cond_mem) || Jump_mem;
    assign redirect_target = (Jump_mem && ALUSrc_mem) ? {alu_result_mem[31:1], 1'b0} : pc_target_mem; // JALR uses ALU result
    assign flush_ex_mem = pc_redirect;
    
    // DMEM instantiation removed, ports are exposed at the top level
    
    // Writeback
    wire [31:0] alu_result_wb, mem_read_data_wb, pc_plus4_wb, pc_target_wb, imm_ext_wb;
    wire [2:0] ResultSrc_wb;
    
    mem_wb_reg MEM_WB(
        .clk(clk), .rst(rst),
        .alu_result_in(alu_result_mem), .mem_read_data_in(mem_read_data_mem), .pc_plus4_in(pc_plus4_mem),
        .pc_target_in(pc_target_mem), .imm_ext_in(imm_ext_mem), .rd_addr_in(rd_addr_mem),
        .RegWrite_in(RegWrite_mem), .ResultSrc_in(ResultSrc_mem),
        
        .alu_result_out(alu_result_wb), .mem_read_data_out(mem_read_data_wb), .pc_plus4_out(pc_plus4_wb),
        .pc_target_out(pc_target_wb), .imm_ext_out(imm_ext_wb), .rd_addr_out(rd_addr_wb),
        .RegWrite_out(reg_write_wb), .ResultSrc_out(ResultSrc_wb)
    );
    
    wb_mux WBMUX(
        .result_src(ResultSrc_wb), .alu_result(alu_result_wb), .mem_read_data(mem_read_data_wb),
        .pc_plus4(pc_plus4_wb), .pc_target(pc_target_wb), .imm_ext(imm_ext_wb),
        .rd_data(rd_data_wb)
    );
    
    // Forwarding and Hazards
    forward_unit FU(
        .ex_mem_rd(rd_addr_mem), .mem_wb_rd(rd_addr_wb),
        .ex_mem_regwrite(RegWrite_mem), .mem_wb_regwrite(reg_write_wb),
        .id_ex_rs1(rs1_addr_ex), .id_ex_rs2(rs2_addr_ex),
        .forward_a(forward_a), .forward_b(forward_b)
    );
    
    hazard_unit HU(
        .id_ex_memread(MemRead_ex), .id_ex_rd(rd_addr_ex),
        .if_id_rs1(rs1_addr_id), .if_id_rs2(rs2_addr_id),
        .stall(stall), .flush_id_ex(flush_id_ex)
    );
    
endmodule
