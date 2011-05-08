/**
 * Module:  module_sdram_burst
 * Version: 1v0
 * Build:   c02321d4f63c73a1bc16cd7cfd25b52a1db06efa
 * File:    sdram_burst.h
 *
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2010
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/                                   
/*************************************************************************
 *
 * SDRAM driver - optimised for bursts
 * 25MHz 16bit
 * Micron SDRAM MT48LC16M16A2P-75
 *
 * sdram.h
 *
 * Must be compiled with -O2
 * Tools version min 9.9.0 is required
 *
 *************************************************************************/

#ifndef _sdram_h_
#define _sdram_h_

void sdram_server(chanend client);

void sdram_init(chanend server);
void sdram_shutdown(chanend server);

// Every 15us
void sdram_refresh(chanend server);

// Burst read and write
// Minimum burst size 1, maximum burst size 256
// 4 banks, 8192 rows, 256 32b columns
// Total: 32MB, bank size: 8MB, row size: 1KB
void sdram_write(chanend c, int bank, int row, int col, const unsigned words[], int nwords);
void sdram_read(chanend c, int bank, int row, int col, unsigned words[], int nwords);

#endif
