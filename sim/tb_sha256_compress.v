`timescale 1ns/1ps

module tb_sha256_compress;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg start = 1'b0;
    reg [255:0] state_in;
    reg [511:0] block;
    wire busy;
    wire done;
    wire [255:0] state_out;

    sha256_compress dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .state_in(state_in),
        .block(block),
        .busy(busy),
        .done(done),
        .state_out(state_out)
    );

    always #5 clk = ~clk;

    initial begin
        state_in = {
            32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
            32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
        };

        block = {
            32'h61626380, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000018
        };

        repeat (4) @(posedge clk);
        reset <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        wait(done);
        @(posedge clk);

        if (state_out !== 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad) begin
            $display("FAIL sha256 abc: %h", state_out);
            $finish(1);
        end

        $display("PASS sha256 abc");
        $finish(0);
    end
endmodule
