#include "Vcva6_axi_wrapper.h"
#include "verilated.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <queue>
#include <cstring>
#include <string>
#include <sstream>
#include <regex>

#define RAM_SIZE (1024 * 1024 * 16)
#define BASE_ADDR 0x80000000ULL

struct AXI_Req {
    uint64_t addr;
    uint32_t id;
    uint8_t  len;
};

// ==========================================
// Structure and functions for processing the Spike log
// ==========================================
struct SpikeLogEntry {
    uint64_t pc;       // Updated to 64-bit
    uint32_t rd;       // Destination register (0 to 31)
    uint64_t wdata;    // Written data (Updated to 64-bit)
    bool has_write;    // Does this instruction write to a register?
    std::string full_line;
};

std::vector<SpikeLogEntry> load_spike_log(const std::string& filename) {
    std::vector<SpikeLogEntry> log_entries;
    std::ifstream file(filename);
    if (!file) {
        std::cerr << "Warning: Could not open spike log file: " << filename << "\n";
        return log_entries;
    }

    std::string line;
    
    // Detect commit lines: they contain a privilege level (e.g. 3) before the PC
    // Example: core   0: 3 0x00001004 (0x02028593) x11 0x00001020
    std::regex commit_regex(R"(core\s+\d+:\s+\d+\s+(0x[0-9a-fA-F]+)\s+\(0x[0-9a-fA-F]+\)(.*))");
    
    // Check whether the rest of the line contains a register write (xN)
    std::regex reg_write_regex(R"(x(\d+)\s+(0x[0-9a-fA-F]+))");

    std::smatch match;
    while (std::getline(file, line)) {
        if (std::regex_search(line, match, commit_regex)) {
            SpikeLogEntry entry;
            entry.full_line = line;
            
            // Extract PC (group 1)
            entry.pc = static_cast<uint64_t>(std::stoull(match[1].str(), nullptr, 16));
            
            // Extract destination register and data from the rest of the line (group 2)
            std::string rest = match[2].str();
            std::smatch reg_match;
            if (std::regex_search(rest, reg_match, reg_write_regex)) {
                entry.rd = std::stoul(reg_match[1].str());
                entry.wdata = static_cast<uint64_t>(std::stoull(reg_match[2].str(), nullptr, 16));
                entry.has_write = (entry.rd != 0); // Ignore x0 (register zero is always zero)
            } else {
                entry.has_write = false;
                entry.rd = 0;
                entry.wdata = 0;
            }
            
            log_entries.push_back(entry);
        }
    }
    std::cout << "Loaded " << log_entries.size() << " commit lines from Spike log.\n";
    return log_entries;
}
// ==========================================

uint64_t read_ram(const std::vector<uint8_t>& ram, uint64_t addr) {
    // اجبار به هم‌ترازی 8 بایتی (صفر کردن 3 بیت آخر)
    uint64_t aligned_addr = addr & ~0x7ULL; 
    
    if (aligned_addr >= BASE_ADDR && (aligned_addr - BASE_ADDR) <= RAM_SIZE - 8) {
        uint64_t data = 0;
        std::memcpy(&data, &ram[aligned_addr - BASE_ADDR], 8);
        return data;
    }
    return 0;
}

void write_ram(std::vector<uint8_t>& ram, uint64_t addr, uint64_t data, uint8_t strb) {
    // اجبار به هم‌ترازی 8 بایتی
    uint64_t aligned_addr = addr & ~0x7ULL; 
    
    if (aligned_addr >= BASE_ADDR && (aligned_addr - BASE_ADDR) <= RAM_SIZE - 8) {
        uint64_t offset = aligned_addr - BASE_ADDR;
        for (int i = 0; i < 8; i++) {
            if ((strb >> i) & 1) {
                ram[offset + i] = (data >> (i * 8)) & 0xFF;
            }
        }
    }
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vcva6_axi_wrapper* top = new Vcva6_axi_wrapper;

    std::vector<uint8_t> ram(RAM_SIZE, 0);
    std::ifstream bin_file("firmware.bin", std::ios::binary);
    if (bin_file) {
        bin_file.read(reinterpret_cast<char*>(ram.data()), RAM_SIZE);
        std::cout << "Loaded firmware into memory. Size: " << bin_file.gcount() << " bytes.\n";
    } else {
        std::cerr << "\nCRITICAL ERROR: Failed to open 'firmware.bin'!\n";
        return 1;
    }

    // Load Spike log file
    std::vector<SpikeLogEntry> spike_log = load_spike_log("spike_trace.log"); 
    size_t spike_idx = 0;
    bool is_synced = false;
    bool sim_failed = false;

    vluint64_t main_time = 0;
    
    // Variables for stall detection
    vluint64_t last_commit_time = 0;
    const vluint64_t MAX_STALL_TIME = 100000; // Max allowed time without a commit (~50K clocks)

    std::queue<AXI_Req> ar_queue;
    std::queue<AXI_Req> aw_queue;
    std::queue<uint32_t> b_queue;

    bool r_active = false; uint64_t r_addr = 0; uint32_t r_id = 0; int r_beats = 0;
    bool w_active = false; uint64_t w_addr = 0; uint32_t w_id = 0; int w_beats = 0;

    top->clk_i = 0; top->rst_ni = 0; top->boot_addr_i = BASE_ADDR; top->irq_i = 0;
    top->axi_ar_ready_i = 1; top->axi_aw_ready_i = 1; top->axi_w_ready_i = 0;
    top->axi_r_valid_i = 0; top->axi_r_id_i = 0; top->axi_r_data_i = 0; top->axi_r_resp_i = 0; top->axi_r_last_i = 0;
    top->axi_b_valid_i = 0; top->axi_b_id_i = 0; top->axi_b_resp_i = 0;
    
    top->eval();

    for (int i = 0; i < 20; i++) {
        top->clk_i = 1; top->eval(); main_time++;
        top->clk_i = 0; top->eval(); main_time++;
    }
    
    top->rst_ni = 1;
    top->eval();
    
    last_commit_time = main_time; // Initialize the stall timer before entering the loop

    while (!Verilated::gotFinish() && main_time < 10000000 && !sim_failed) {
        
        bool ar_fire = top->axi_ar_valid_o && top->axi_ar_ready_i;
        uint64_t captured_ar_addr = top->axi_ar_addr_o;
        uint32_t captured_ar_id   = top->axi_ar_id_o;
        uint8_t  captured_ar_len  = top->axi_ar_len_o;

        bool aw_fire = top->axi_aw_valid_o && top->axi_aw_ready_i;
        uint64_t captured_aw_addr = top->axi_aw_addr_o;
        uint32_t captured_aw_id   = top->axi_aw_id_o;
        uint8_t  captured_aw_len  = top->axi_aw_len_o;

        bool w_fire  = top->axi_w_valid_o && top->axi_w_ready_i;
        uint64_t captured_w_data  = top->axi_w_data_o;
        uint8_t  captured_w_strb  = top->axi_w_strb_o;
        bool     captured_w_last  = top->axi_w_last_o;

        bool r_fire  = top->axi_r_valid_i  && top->axi_r_ready_o;
        bool b_fire  = top->axi_b_valid_i  && top->axi_b_ready_o;

        top->clk_i = 1;
        top->eval();
        main_time++;

        // ==========================================================
        // Monitoring and comparison section (Co-simulation)
        // ==========================================================
        if (top->commit_ack_o > 0 && !spike_log.empty()) {
            for (int i = 0; i < 2; i++) { 
                if ((top->commit_ack_o >> i) & 1) { 
                    
                    // Combine the two 32-bit halves to build the 64-bit PC and WDATA
                    uint64_t pc_low  = top->commit_pc_o[i * 2];
                    uint64_t pc_high = top->commit_pc_o[i * 2 + 1];
                    uint64_t pc = (pc_high << 32) | pc_low;

                    uint64_t wdata_low  = top->commit_wdata_o[i * 2];
                    uint64_t wdata_high = top->commit_wdata_o[i * 2 + 1];
                    uint64_t wdata = (wdata_high << 32) | wdata_low;

                    // Extract the destination register (RD) number from the 5-bit fields
                    uint32_t rd = (top->commit_rd_o >> (i * 5)) & 0x1F;       
                    
                    // 1. Initial synchronization
                    if (!is_synced) {
                        while (spike_idx < spike_log.size() && spike_log[spike_idx].pc != pc) {
                            spike_idx++;
                        }
                        if (spike_idx < spike_log.size()) {
                            is_synced = true;
                            printf("\n[SYNC] Synced RTL and Spike at PC=0x%016llx\n", (unsigned long long)pc);
                        } else {
                            printf("\n❌ [ERROR] Could not find RTL starting PC (0x%016llx) in Spike log!\n", (unsigned long long)pc);
                            sim_failed = true;
                            break;
                        }
                    }

                    // 2. Full line-by-line comparison
                    if (is_synced && spike_idx < spike_log.size()) {
                        SpikeLogEntry& expected = spike_log[spike_idx];
                        
                        // a) Control-flow check (do the PCs match?)
                        if (pc != expected.pc) {
                            printf("\n❌ [DIVERGENCE ERROR: PC MISMATCH] at time %lu ps\n", main_time);
                            printf("   RTL Executed : PC=0x%016llx\n", (unsigned long long)pc);
                            printf("   Spike Expects: PC=0x%016llx -> %s\n", (unsigned long long)expected.pc, expected.full_line.c_str());
                            sim_failed = true;
                            break;
                        }

                        // b) Datapath check (written register value)
                        if (rd != 0 && expected.has_write) {
                            if (rd != expected.rd) {
                                printf("\n❌ [DIVERGENCE ERROR: DEST REG MISMATCH] at time %lu ps\n", main_time);
                                printf("   PC=0x%016llx\n", (unsigned long long)pc);
                                printf("   RTL wrote to   : x%d\n", rd);
                                printf("   Spike wrote to : x%d\n", expected.rd);
                                sim_failed = true;
                                break;
                            }
                            if (wdata != expected.wdata) {
                                printf("\n❌ [DIVERGENCE ERROR: DATA MISMATCH] at time %lu ps\n", main_time);
                                printf("   PC=0x%016llx | Register: x%d\n", (unsigned long long)pc, rd);
                                printf("   RTL Data   : 0x%016llx\n", (unsigned long long)wdata);
                                printf("   Spike Data : 0x%016llx\n", (unsigned long long)expected.wdata);
                                sim_failed = true;
                                break;
                            }
                        }
                        
                        // Print success log
                        printf("✅ [MATCH] PC=0x%016llx | Spike: %s\n", (unsigned long long)pc, expected.full_line.c_str());
                        
                        spike_idx++;
                        last_commit_time = main_time; // Update the stall timer on a successful commit
                    }
                }
            }
        }
        // ==========================================================

        if (ar_fire) { ar_queue.push({captured_ar_addr, captured_ar_id, captured_ar_len}); }
        if (aw_fire) { aw_queue.push({captured_aw_addr, captured_aw_id, captured_aw_len}); }
        if (w_fire) {
            write_ram(ram, w_addr, captured_w_data, captured_w_strb);
            w_beats--; w_addr += 8;
            if (captured_w_last || w_beats <= 0) { w_active = false; b_queue.push(w_id); }
        }
        if (r_fire) {
            r_beats--; r_addr += 8;
            if (r_beats <= 0) { r_active = false; }
        }
        if (b_fire) { b_queue.pop(); }

        if (!r_active && !ar_queue.empty()) {
            r_active = true; r_addr  = ar_queue.front().addr; r_id = ar_queue.front().id; r_beats = ar_queue.front().len + 1;
            ar_queue.pop();
        }
        if (!w_active && !aw_queue.empty()) {
            w_active = true; w_addr  = aw_queue.front().addr; w_id = aw_queue.front().id; w_beats = aw_queue.front().len + 1;
            aw_queue.pop();
        }

        top->axi_ar_ready_i = 1; top->axi_aw_ready_i = 1; 
        top->axi_r_valid_i = r_active; top->axi_r_id_i = r_id; top->axi_r_resp_i = 0; top->axi_r_last_i = (r_active && r_beats == 1) ? 1 : 0;
        top->axi_r_data_i = r_active ? read_ram(ram, r_addr) : 0;
        top->axi_w_ready_i = w_active;
        top->axi_b_valid_i = !b_queue.empty(); top->axi_b_id_i = b_queue.empty() ? 0 : b_queue.front(); top->axi_b_resp_i = 0;

        top->clk_i = 0;
        top->eval();
        main_time++;
        
        // Check whether all instructions in the Spike log have been executed
        if (is_synced && spike_idx >= spike_log.size() && spike_log.size() > 0) {
            break;
        }

        // ==========================================================
        // Stall Detection Logic
        // ==========================================================
        if (main_time - last_commit_time > MAX_STALL_TIME) {
            if (!is_synced) {
                printf("\n❌ [STALL ERROR] RTL never started committing instructions! (Initial sync timeout)\n");
            } else {
                printf("\n❌ [STALL ERROR] RTL stopped committing instructions for %llu time units!\n", (unsigned long long)MAX_STALL_TIME);
            }
            sim_failed = true;
            break;
        }
    } // End of while loop

    delete top;
    return sim_failed ? 1 : 0;
}
