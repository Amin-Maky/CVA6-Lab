`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Am/148
// Engineer: AminMaky
//////////////////////////////////////////////////////////////////////////////////

module cva6_tb;

  // ==========================================
  // 1. Clock and Reset
  // ==========================================
  logic clk;
  logic rst_n;
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk; 
  end
  
  initial begin
    rst_n = 0;
    #100;
    rst_n = 1; 
  end

  // ==========================================
  // 2. Memory Model
  // ==========================================
  logic [31:0] ram [0:16383]; 
  
  initial begin
    for (int i = 0; i < 16384; i++) ram[i] = 32'h0;
    $readmemh("firmware/firmware.hex", ram);
  end

  // ==========================================
  // 3. AXI Read Channels & Burst Logic
  // ==========================================
  logic        noc_ar_valid;
  logic [63:0] noc_ar_addr;
  logic [7:0]  noc_ar_len;  // Burst length
  logic [3:0]  noc_ar_id;   // Transaction ID
  logic        noc_ar_ready;
  
  logic        noc_r_valid;
  logic [63:0] noc_r_data; 
  logic        noc_r_last;
  logic [3:0]  noc_r_id;
  logic        noc_r_ready;
  
  typedef enum logic [1:0] {AR_IDLE, R_DATA} axi_r_state_t;
  axi_r_state_t r_state;

  logic [63:0] r_addr;
  logic [7:0]  r_len;
  logic [3:0]  r_id;
  logic [7:0]  r_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_state      <= AR_IDLE;
      noc_ar_ready <= 1'b1;
      noc_r_valid  <= 1'b0;
      noc_r_last   <= 1'b0;
      r_cnt        <= 8'h0;
    end else begin
      case (r_state)
        AR_IDLE: begin
          noc_ar_ready <= 1'b1;
          if (noc_ar_valid && noc_ar_ready) begin
            r_state      <= R_DATA;
            r_addr       <= noc_ar_addr;
            r_len        <= noc_ar_len;
            r_id         <= noc_ar_id;
            r_cnt        <= 8'h0;
            noc_ar_ready <= 1'b0;
            noc_r_valid  <= 1'b1;
            // If ARLEN is zero, the first beat is already the last one
            noc_r_last   <= (noc_ar_len == 8'h0);
          end
        end
        
        R_DATA: begin
          if (noc_r_valid && noc_r_ready) begin
            if (noc_r_last) begin
              // End of burst
              r_state      <= AR_IDLE;
              noc_r_valid  <= 1'b0;
              noc_ar_ready <= 1'b1;
            end else begin
              // Advance to the next beat within the burst
              r_addr     <= r_addr + 8; // 64-bit bus (8 bytes)
              r_cnt      <= r_cnt + 1;
              noc_r_last <= (r_cnt + 1 == r_len);
            end
          end
        end
      endcase
    end
  end

  assign noc_r_id = r_id;
  // Combinational read from RAM
  assign noc_r_data = (r_state == R_DATA) ? {ram[r_addr[15:2] + 1], ram[r_addr[15:2]]} : 64'b0;

  // ==========================================
  // 4. AXI Write Channels & Strobe Logic
  // ==========================================
  logic        noc_aw_valid;
  logic [63:0] noc_aw_addr;
  logic [7:0]  noc_aw_len;
  logic [3:0]  noc_aw_id;
  logic        noc_aw_ready;

  logic        noc_w_valid;
  logic [63:0] noc_w_data;
  logic [7:0]  noc_w_strb;  // Specifies which bytes must be written
  logic        noc_w_last;
  logic        noc_w_ready;

  logic        noc_b_valid;
  logic [3:0]  noc_b_id;
  logic        noc_b_ready;

  typedef enum logic [1:0] {AW_IDLE, W_DATA, B_RESP} axi_w_state_t;
  axi_w_state_t w_state;

  logic [63:0] w_addr;
  logic [3:0]  w_id;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_state      <= AW_IDLE;
      noc_aw_ready <= 1'b1;
      noc_w_ready  <= 1'b0;
      noc_b_valid  <= 1'b0;
    end else begin
      case (w_state)
        AW_IDLE: begin
          noc_aw_ready <= 1'b1;
          if (noc_aw_valid && noc_aw_ready) begin
            w_addr       <= noc_aw_addr;
            w_id         <= noc_aw_id;
            w_state      <= W_DATA;
            noc_aw_ready <= 1'b0;
            noc_w_ready  <= 1'b1;
          end
        end
        
        W_DATA: begin
          if (noc_w_valid && noc_w_ready) begin
            // Byte-by-byte write for full safety and sb/sh instruction support
            if (noc_w_strb[0]) ram[w_addr[15:2]][7:0]   <= noc_w_data[7:0];
            if (noc_w_strb[1]) ram[w_addr[15:2]][15:8]  <= noc_w_data[15:8];
            if (noc_w_strb[2]) ram[w_addr[15:2]][23:16] <= noc_w_data[23:16];
            if (noc_w_strb[3]) ram[w_addr[15:2]][31:24] <= noc_w_data[31:24];
            if (noc_w_strb[4]) ram[w_addr[15:2]+1][7:0]   <= noc_w_data[39:32];
            if (noc_w_strb[5]) ram[w_addr[15:2]+1][15:8]  <= noc_w_data[47:40];
            if (noc_w_strb[6]) ram[w_addr[15:2]+1][23:16] <= noc_w_data[55:48];
            if (noc_w_strb[7]) ram[w_addr[15:2]+1][31:24] <= noc_w_data[63:56];

            if (noc_w_last) begin
              w_state     <= B_RESP;
              noc_w_ready <= 1'b0;
              noc_b_valid <= 1'b1;
            end else begin
              w_addr <= w_addr + 8;
            end
          end
        end
        
        B_RESP: begin
          if (noc_b_valid && noc_b_ready) begin
            w_state      <= AW_IDLE;
            noc_b_valid  <= 1'b0;
            noc_aw_ready <= 1'b1;
          end
        end
      endcase
    end
  end

  assign noc_b_id = w_id;

  // ==========================================
  // 5. CVA6 Netlist Instantiation
  // ==========================================
  cva6 u_cva6 (
    .clk_i       (clk),
    .rst_ni      (rst_n),
    .boot_addr_i (32'h8000_0000), 
    .hart_id_i   (32'b0),
    .irq_i       (2'b0),
    .ipi_i       (1'b0),
    .time_irq_i  (1'b0),
    .debug_req_i (1'b0),

    // Read address channel
    .\noc_req_o[ar_valid] (noc_ar_valid),
    .\noc_req_o[ar][addr] (noc_ar_addr),
    .\noc_req_o[ar][len]  (noc_ar_len),
    .\noc_req_o[ar][id]   (noc_ar_id),
    .\noc_resp_i[ar_ready] (noc_ar_ready),
    
    // Read data channel
    .\noc_resp_i[r_valid]  (noc_r_valid),
    .\noc_resp_i[r][data]  (noc_r_data),
    .\noc_resp_i[r][last]  (noc_r_last),
    .\noc_resp_i[r][id]    (noc_r_id),
    .\noc_resp_i[r][resp]  (2'b00),
    .\noc_resp_i[r][user]  (32'b0),
    .\noc_req_o[r_ready]   (noc_r_ready),
    
    // Write address channel
    .\noc_req_o[aw_valid]  (noc_aw_valid),
    .\noc_req_o[aw][addr]  (noc_aw_addr),
    .\noc_req_o[aw][len]   (noc_aw_len),
    .\noc_req_o[aw][id]    (noc_aw_id),
    .\noc_resp_i[aw_ready] (noc_aw_ready),
    
    // Write data channel
    .\noc_req_o[w_valid]   (noc_w_valid),
    .\noc_req_o[w][data]   (noc_w_data),
    .\noc_req_o[w][strb]   (noc_w_strb),
    .\noc_req_o[w][last]   (noc_w_last),
    .\noc_resp_i[w_ready]  (noc_w_ready),
    
    // Write response channel
    .\noc_resp_i[b_valid]  (noc_b_valid),
    .\noc_resp_i[b][id]    (noc_b_id),
    .\noc_resp_i[b][resp]  (2'b0),
    .\noc_resp_i[b][user]  (32'b0),
    .\noc_req_o[b_ready]   (noc_b_ready),
    
    // Disable custom (co-processor) extension (cvxif)
    .\cvxif_resp_i[compressed_ready]        (1'b0),
    .\cvxif_resp_i[compressed_resp][instr]  (32'b0),
    .\cvxif_resp_i[compressed_resp][accept] (1'b0),
    .\cvxif_resp_i[issue_ready]             (1'b0),
    .\cvxif_resp_i[issue_resp][accept]      (1'b0),
    .\cvxif_resp_i[issue_resp][writeback]   (1'b0),
    .\cvxif_resp_i[issue_resp][register_read] (2'b0),
    .\cvxif_resp_i[register_ready]          (1'b0),
    .\cvxif_resp_i[result_valid]            (1'b0),
    .\cvxif_resp_i[result][hartid]          (32'b0),
    .\cvxif_resp_i[result][id]              (3'b0),
    .\cvxif_resp_i[result][data]            (32'b0),
    .\cvxif_resp_i[result][rd]              (5'b0),
    .\cvxif_resp_i[result][we]              (1'b0)
  );

endmodule
