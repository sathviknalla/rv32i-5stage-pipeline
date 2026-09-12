`timescale 1ns / 1ps

module tb_rv32i_core();

    reg clk;
    reg rst;
    wire [31:0] test_result;
    
    wire [31:0] pc_if, instr_if;
    wire [31:0] alu_result_mem, write_data_mem;
    wire MemWrite_mem, MemRead_mem;
    wire [2:0] funct3_mem;
    wire [31:0] mem_read_data_mem;

    instr_mem IMEM(
        .addr(pc_if), .instr(instr_if)
    );

    data_mem DMEM(
        .clk(clk), .addr(alu_result_mem), .write_data(write_data_mem),
        .mem_write(MemWrite_mem), .mem_read(MemRead_mem), .funct3(funct3_mem),
        .read_data(mem_read_data_mem), .test_result(test_result)
    );

    rv32i_core uut(
        .clk(clk),
        .rst(rst),
        .pc_if(pc_if),
        .instr_if(instr_if),
        .alu_result_mem(alu_result_mem),
        .write_data_mem(write_data_mem),
        .MemWrite_mem(MemWrite_mem),
        .MemRead_mem(MemRead_mem),
        .funct3_mem(funct3_mem),
        .mem_read_data_mem(mem_read_data_mem)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #20 rst = 0;
    end
    
    always @(posedge clk) begin
        if (test_result == 32'd1) begin
            $display("=================================================");
            $display("Test Passed: rv32i pipeline achieved correctness.");
            $display("=================================================");
            $finish;
        end
    end

    // Timeout
    initial begin
        #5000;
        $display("Test Failed: Timeout reached before test completion.");
        $finish;
    end

endmodule
