`timescale 1ns/1ps

module tb_bitcoin_hash_core;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg start = 1'b0;
    reg stop = 1'b0;
    reg [255:0] midstate;
    reg [95:0] tail;
    reg [255:0] target;
    wire running;
    wire found;
    wire [31:0] found_nonce;
    wire [255:0] found_hash;
    wire [31:0] current_nonce;

    bitcoin_hash_core dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .stop(stop),
        .midstate(midstate),
        .tail(tail),
        .target(target),
        .running(running),
        .found(found),
        .found_nonce(found_nonce),
        .found_hash(found_hash),
        .current_nonce(current_nonce)
    );

    always #5 clk = ~clk;

    initial begin
        midstate = 256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;
        tail = 96'h4b1e5e4a29ab5f49ffff001d;
        target = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

        repeat (4) @(posedge clk);
        reset <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        wait(found);
        @(posedge clk);

        if (found_nonce !== 32'h00000000) begin
            $display("FAIL nonce: %h", found_nonce);
            $finish(1);
        end

        if (found_hash !== 256'hbf483998a9b44cbf5a113973e34da96b5cf3c7757d75ac3bd7c6b30af5a7c12b) begin
            $display("FAIL hash: %h", found_hash);
            $finish(1);
        end

        $display("PASS bitcoin hash core");
        $finish(0);
    end
endmodule
