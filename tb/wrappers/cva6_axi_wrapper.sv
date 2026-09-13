`include "rvfi_types.svh"
`include "cvxif_types.svh"

module cva6_axi_wrapper
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg),
    
    // ==========================================
    // RVFI Parameter Types (Required to unpack probes)
    // ==========================================
    parameter type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg),
    parameter type rvfi_probes_csr_t   = `RVFI_PROBES_CSR_T(CVA6Cfg),
    parameter type rvfi_probes_t       = struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
    },

    // ==========================================
    // AXI types
    // ==========================================
    parameter type axi_ar_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_aw_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_w_chan_t = struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    },
    parameter type b_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type r_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type noc_req_t = struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    },
    parameter type noc_resp_t = struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    }
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    input  logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    input  logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    input  logic [1:0]              irq_i,
    input  logic                    ipi_i,
    input  logic                    time_irq_i,
    input  logic                    debug_req_i,

    // ==========================================
    // Commit Log Ports (For C++ Testbench Co-Sim)
    // ==========================================
    output logic [CVA6Cfg.NrCommitPorts-1:0]                   commit_ack_o,
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.VLEN-1:0] commit_pc_o,
    output logic [CVA6Cfg.NrCommitPorts-1:0][4:0]              commit_rd_o,
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] commit_wdata_o,

    // ==========================================
    // AXI Flattened Ports (For C++ Testbench)
    // ==========================================
    
    // --- AW Channel (Write Address) ---
    output logic                            axi_aw_valid_o,
    input  logic                            axi_aw_ready_i,
    output logic [CVA6Cfg.AxiIdWidth-1:0]   axi_aw_id_o,
    output logic [CVA6Cfg.AxiAddrWidth-1:0] axi_aw_addr_o,
    output logic [7:0]                      axi_aw_len_o,
    output logic [2:0]                      axi_aw_size_o,
    output logic [1:0]                      axi_aw_burst_o,
    output logic                            axi_aw_lock_o,
    output logic [3:0]                      axi_aw_cache_o,
    output logic [2:0]                      axi_aw_prot_o,
    output logic [3:0]                      axi_aw_qos_o,
    output logic [3:0]                      axi_aw_region_o,
    output logic [5:0]                      axi_aw_atop_o,
    output logic [CVA6Cfg.AxiUserWidth-1:0] axi_aw_user_o,

    // --- W Channel (Write Data) ---
    output logic                            axi_w_valid_o,
    input  logic                            axi_w_ready_i,
    output logic [CVA6Cfg.AxiDataWidth-1:0] axi_w_data_o,
    output logic [(CVA6Cfg.AxiDataWidth/8)-1:0] axi_w_strb_o,
    output logic                            axi_w_last_o,
    output logic [CVA6Cfg.AxiUserWidth-1:0] axi_w_user_o,

    // --- B Channel (Write Response) ---
    input  logic                            axi_b_valid_i,
    output logic                            axi_b_ready_o,
    input  logic [CVA6Cfg.AxiIdWidth-1:0]   axi_b_id_i,
    input  logic [1:0]                      axi_b_resp_i,
    input  logic [CVA6Cfg.AxiUserWidth-1:0] axi_b_user_i,
    
    // --- AR Channel (Read Address) ---
    output logic                            axi_ar_valid_o,
    input  logic                            axi_ar_ready_i,
    output logic [CVA6Cfg.AxiIdWidth-1:0]   axi_ar_id_o,
    output logic [CVA6Cfg.AxiAddrWidth-1:0] axi_ar_addr_o,
    output logic [7:0]                      axi_ar_len_o,
    output logic [2:0]                      axi_ar_size_o,
    output logic [1:0]                      axi_ar_burst_o,
    output logic                            axi_ar_lock_o,
    output logic [3:0]                      axi_ar_cache_o,
    output logic [2:0]                      axi_ar_prot_o,
    output logic [3:0]                      axi_ar_qos_o,
    output logic [3:0]                      axi_ar_region_o,
    output logic [CVA6Cfg.AxiUserWidth-1:0] axi_ar_user_o,
    
    // --- R Channel (Read Data) ---
    input  logic                            axi_r_valid_i,
    output logic                            axi_r_ready_o,
    input  logic [CVA6Cfg.AxiIdWidth-1:0]   axi_r_id_i,
    input  logic [CVA6Cfg.AxiDataWidth-1:0] axi_r_data_i,
    input  logic [1:0]                      axi_r_resp_i,
    input  logic                            axi_r_last_i,
    input  logic [CVA6Cfg.AxiUserWidth-1:0] axi_r_user_i
);
    
    noc_req_t  core_noc_req;
    noc_resp_t core_noc_resp;
    
    // Wire to catch the giant 4196-bit probe from CVA6
    rvfi_probes_t rvfi_probes;

    // ==========================================
    // Unpacking RVFI for C++ Testbench
    // ==========================================
    assign commit_ack_o = rvfi_probes.instr.commit_ack;
    
    genvar i;
    generate
        for (i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin : gen_commit_ports
            assign commit_pc_o[i]    = rvfi_probes.instr.commit_instr_pc[i];
            assign commit_rd_o[i]    = rvfi_probes.instr.commit_instr_rd[i][4:0]; 
            assign commit_wdata_o[i] = rvfi_probes.instr.wdata[i]; 
        end
    endgenerate

    // ==========================================
    // Unpacking Requests: Core -> AXI
    // ==========================================
    assign axi_aw_valid_o  = core_noc_req.aw_valid;
    assign axi_aw_id_o     = core_noc_req.aw.id;
    assign axi_aw_addr_o   = core_noc_req.aw.addr;
    assign axi_aw_len_o    = core_noc_req.aw.len;
    assign axi_aw_size_o   = core_noc_req.aw.size;
    assign axi_aw_burst_o  = core_noc_req.aw.burst;
    assign axi_aw_lock_o   = core_noc_req.aw.lock;
    assign axi_aw_cache_o  = core_noc_req.aw.cache;
    assign axi_aw_prot_o   = core_noc_req.aw.prot;
    assign axi_aw_qos_o    = core_noc_req.aw.qos;
    assign axi_aw_region_o = core_noc_req.aw.region;
    assign axi_aw_atop_o   = core_noc_req.aw.atop;
    assign axi_aw_user_o   = core_noc_req.aw.user;

    assign axi_w_valid_o   = core_noc_req.w_valid;
    assign axi_w_data_o    = core_noc_req.w.data;
    assign axi_w_strb_o    = core_noc_req.w.strb;
    assign axi_w_last_o    = core_noc_req.w.last;
    assign axi_w_user_o    = core_noc_req.w.user;

    assign axi_b_ready_o   = core_noc_req.b_ready;

    assign axi_ar_valid_o  = core_noc_req.ar_valid;
    assign axi_ar_id_o     = core_noc_req.ar.id;
    assign axi_ar_addr_o   = core_noc_req.ar.addr;
    assign axi_ar_len_o    = core_noc_req.ar.len;
    assign axi_ar_size_o   = core_noc_req.ar.size;
    assign axi_ar_burst_o  = core_noc_req.ar.burst;
    assign axi_ar_lock_o   = core_noc_req.ar.lock;
    assign axi_ar_cache_o  = core_noc_req.ar.cache;
    assign axi_ar_prot_o   = core_noc_req.ar.prot;
    assign axi_ar_qos_o    = core_noc_req.ar.qos;
    assign axi_ar_region_o = core_noc_req.ar.region;
    assign axi_ar_user_o   = core_noc_req.ar.user;

    assign axi_r_ready_o   = core_noc_req.r_ready;

    // ==========================================
    // Packing Responses: AXI -> Core
    // ==========================================
    assign core_noc_resp.aw_ready = axi_aw_ready_i;
    assign core_noc_resp.w_ready  = axi_w_ready_i;
    
    assign core_noc_resp.b_valid  = axi_b_valid_i;
    assign core_noc_resp.b.id     = axi_b_id_i;
    assign core_noc_resp.b.resp   = axi_b_resp_i;
    assign core_noc_resp.b.user   = axi_b_user_i;
    
    assign core_noc_resp.ar_ready = axi_ar_ready_i;
    
    assign core_noc_resp.r_valid  = axi_r_valid_i;
    assign core_noc_resp.r.id     = axi_r_id_i;
    assign core_noc_resp.r.data   = axi_r_data_i;
    assign core_noc_resp.r.resp   = axi_r_resp_i;
    assign core_noc_resp.r.last   = axi_r_last_i;
    assign core_noc_resp.r.user   = axi_r_user_i;

    // ==========================================
    // CVA6 Instantiation (DUT)
    // ==========================================
    cva6 #(
        .CVA6Cfg(CVA6Cfg)
    ) i_cva6 (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .boot_addr_i   (boot_addr_i),
        .hart_id_i     (hart_id_i),
        .irq_i         (irq_i),
        .ipi_i         (ipi_i),
        .time_irq_i    (time_irq_i),
        .debug_req_i   (debug_req_i),
        
        .noc_req_o     (core_noc_req),
        .noc_resp_i    (core_noc_resp),
        
        .rvfi_probes_o (rvfi_probes),   // <--- Connect to local RVFI structure
        .cvxif_req_o   (),
        .cvxif_resp_i  ('0)
    );

endmodule
