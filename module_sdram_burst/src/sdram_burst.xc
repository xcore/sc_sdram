/**
 * Module:  module_sdram_burst
 * Version: 1v0
 * Build:   c02321d4f63c73a1bc16cd7cfd25b52a1db06efa
 * File:    sdram_burst.xc
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
 * sdram.xc
 *
 * Must be compiled with -O2
 * Tools version min 9.9.0 is required
 *
 *************************************************************************
 *
 * Not using auto precharge or burst terminate, terminating with precharge
 * Not using self refresh
 *
 *************************************************************************/

#include <xs1.h>
#include <platform.h>
#include <xclib.h>
#include <print.h>
#include "sdram_burst.h"

on stdcore[1] : out port p_sdram_clk = XS1_PORT_1A;
on stdcore[1] : out port p_sdram_cke = XS1_PORT_1B;
on stdcore[1] : out buffered port:32 p_sdram_cmd = XS1_PORT_4D;
on stdcore[1] : buffered port:32 p_sdram_dq = XS1_PORT_16B;
on stdcore[1] : out buffered port:32 p_sdram_addr = XS1_PORT_32A;
on stdcore[1] : out buffered port:4 p_sdram_addr0 = XS1_PORT_1G;
on stdcore[1] : out port p_sdram_ba0 = XS1_PORT_1C;
on stdcore[1] : out port p_sdram_ba1 = XS1_PORT_1D;
on stdcore[1] : out buffered port:4 p_sdram_dqm0 = XS1_PORT_1E;
on stdcore[1] : out buffered port:4 p_sdram_dqm1 = XS1_PORT_1F;
on stdcore[1] : out port p_sdram_clkblk = XS1_PORT_1H;            // This port must be unused!
on stdcore[1] : out buffered port:4 p_sdram_gate = XS1_PORT_1I;   // This port must be unused!
on stdcore[1] : clock b_sdram_clk = XS1_CLKBLK_1;
on stdcore[1] : clock b_sdram_io = XS1_CLKBLK_2;
on stdcore[1] : clock b_ref = XS1_CLKBLK_REF;

static void uswait(int us)
{
	if (us == 0)
	{
		return;
	}
	else
	{
		timer tmr;
		unsigned t;
		tmr :> t;
		tmr when timerafter(t + 100 * us) :> t;
	}
}

static void init()
{
	p_sdram_addr <: 0;
	p_sdram_addr0:1 <: 0;
	sync(p_sdram_addr);

	set_port_clock(p_sdram_clk, b_sdram_clk);
	set_port_clock(p_sdram_clkblk, b_sdram_clk);
	set_port_clock(p_sdram_cke, b_sdram_io);
	set_port_clock(p_sdram_cmd, b_sdram_io);
	set_port_clock(p_sdram_dq, b_sdram_io);
	set_port_clock(p_sdram_addr, b_sdram_io);
	set_port_clock(p_sdram_addr0, b_sdram_io);
	set_port_clock(p_sdram_ba0, b_sdram_io);
	set_port_clock(p_sdram_ba1, b_sdram_io);
	set_port_clock(p_sdram_dqm0, b_sdram_io);
	set_port_clock(p_sdram_dqm1, b_sdram_io);
	set_port_clock(p_sdram_gate, b_sdram_io);
	set_port_strobed(p_sdram_cmd);
	set_port_strobed(p_sdram_dq);
	set_port_strobed(p_sdram_addr);
	set_port_strobed(p_sdram_addr0);
	set_port_slave(p_sdram_cmd);
	set_port_slave(p_sdram_dq);
	set_port_slave(p_sdram_addr);
	set_port_slave(p_sdram_addr0);

  // 12.5 MHz clock
  set_clock_div(b_sdram_clk, 4);

	// Delays
	// 9 clocks required for b_sdram_io to run along with b_sdram_clk
#ifdef CHIPLVL
	// Chip level simulation
	set_clock_fall_delay(b_sdram_io, 9);
	set_clock_rise_delay(b_sdram_io, 13);
#else
	// Real hardware
	set_clock_fall_delay(b_sdram_io, 11);
	set_clock_rise_delay(b_sdram_io, 13);
#endif

	// Do not start clock port yet
	set_port_mode_clock(p_sdram_clkblk);
	set_clock_src(b_sdram_io, p_sdram_clkblk);
	set_clock_ready_src(b_sdram_io, p_sdram_gate);
	start_clock(b_sdram_clk);
	start_clock(b_sdram_io);

	// Initialise all signals to 0 except command lines (INHIBIT)
	p_sdram_cke <: 0;
	p_sdram_cmd:4 <: 0xF;
	p_sdram_dq <: 0;
	p_sdram_addr <: 0;
	p_sdram_addr0:1 <: 0;
	p_sdram_ba0 <: 0;
	p_sdram_ba1 <: 0;
	p_sdram_dqm0 <: 0;
	p_sdram_dqm1 <: 0;
	p_sdram_gate:1 <: 1;

	// Start clock and provide 100us for SDRAM start up
	// Assert CKE in between
#if defined(CHIPLVL) || defined(SIMULATION)
	set_port_mode_clock(p_sdram_clk);
	p_sdram_cke <: 1;
	uswait(0);
#else
	uswait(50);
	set_port_mode_clock(p_sdram_clk);
	uswait(50);
	p_sdram_cke <: 1;
	uswait(50);
#endif

	// PRECHARGE (all banks A10=1) and wait 20ns
	// Two AUTO REFRESH with 66ns in between
	// Bit A10 is bit 22 of addr
	p_sdram_addr <: (1 << 22);
	p_sdram_cmd <: 0xE2FFFF28;

	sync(p_sdram_cmd);
	p_sdram_gate:1 <: 0;

	// Program mode register: CL3, sequential, continuous burst (0x37)
	// Value A=0x37 is bitrev(0x1B) on addr and 1 on addr0
	p_sdram_cmd:16 <: 0xEE0E;
	p_sdram_addr0:1 <: 1;
	p_sdram_addr <: bitrev(0x1B);
	p_sdram_gate <: 0b1111;
	p_sdram_gate:1 <: 0;
	sync(p_sdram_gate);

	set_thread_fast_mode_on();
}

// Order of clock block stopping is significant
static void shutdown()
{
	set_thread_fast_mode_off();
	set_port_clock(p_sdram_addr, b_ref);
	set_port_clock(p_sdram_addr0, b_ref);
	set_port_clock(p_sdram_dq, b_ref);
	set_port_clock(p_sdram_clk, b_ref);
	set_port_clock(p_sdram_clkblk, b_ref);
	stop_clock(b_sdram_io);
	stop_clock(b_sdram_clk);
	set_clock_off(b_sdram_clk);
	set_clock_off(b_sdram_io);
	set_clock_on(b_sdram_clk);
	set_clock_on(b_sdram_io);
}

// Do two refreshes
// Each refresh requires 66ns to complete
static void refresh()
{
	p_sdram_cmd <: 0xEEE2EE2E;
	p_sdram_gate <: 0b1111;
	p_sdram_gate <: 0b1111;
	p_sdram_gate:1 <: 0;
}

void sdram_init(chanend server)
{
	server :> int ready;
}

void sdram_shutdown(chanend server)
{
	server <: 1;
	server :> int done;
}

void sdram_refresh(chanend server)
{
	server <: 2;
}

void sdram_server(chanend client)
{
	int running = 1;
	init();
	client <: 0;
	while (running)
	{
		unsigned cmd;
		client :> cmd;
		switch (cmd)
		{
      case 1:
        shutdown();
        running = 0;
        break;

      case 2:
        // REFRESH required every 7us
        refresh();
        break;

      case 3:
        // Write
        master
        {
          int bank, row, col, nwords;
          unsigned t;
          unsigned dt;
          unsigned x;
          unsigned colw;
          int i;
          
          client :> bank;
          client :> row;
          client :> col;
          client :> nwords;

          // ACTIVE first
          // WRITE with no auto-precharge (A10 = 0)
          // Terminated with PRECHARGE single bank (A10 = 0)
          // Column address bit 0 is always 0 (32b word aligned)
          // Data port is driving throughout this function
          // No FNOPs in data loop (budget is 4 instrs at 25MHz/50MIPS)
          dt = 2 * nwords + 2;
          colw = bitrev(col);
          i = nwords - 1;
          p_sdram_ba0 <: bank;
          p_sdram_ba1 <: bank >> 1;
          p_sdram_addr0 <: (row & 1) << 1;
          p_sdram_addr <: 0;
          p_sdram_addr <: bitrev(row >> 1);
          p_sdram_cmd:16 <: 0xE4AE;
          p_sdram_dq <: 0;
          p_sdram_gate:1 <: 0 @ t;
          t += 12;
          p_sdram_gate:1 @ t <: 1;  // IO: kick off
          t += dt;
          p_sdram_dqm0 @ t <: 0b0001;
          p_sdram_dqm1 @ t <: 0b0001;
          p_sdram_cmd:8 @ t <: 0xE8;
          client :> x;
          p_sdram_dq <: x;          // IO: first data
          client :> x;
          p_sdram_addr <: colw;
          p_sdram_gate @ t <: 0b0011;
          while (i != 0)
          {
            p_sdram_dq <: x;        // IO: next data
            client :> x;            // last data is not written to p_sdram_dq (timing optimisation)
            i--;
          }
        }
        break;

      case 4:
        // Read
        master
        {
          int bank, row, col, nwords;
          unsigned t0, t1, t2;
          unsigned dt; 
          unsigned x;
          unsigned colw;
          int i;
          
          client :> bank;
          client :> row;
          client :> col;
          client :> nwords;

          // ACTIVE first
          // READ with no auto-precharge (A10 = 0)
          // Terminated with PRECHARGE single bank (A10 = 0)
          // Data port is driving when entering and leaving this function
          // No FNOPs in data loop (budget is 4 instrs at 25MHz/50MIPS)
          dt = 2 * nwords + 2;
          colw = bitrev(col);
          i = nwords - 1;
          p_sdram_ba0 <: bank;
          p_sdram_ba1 <: bank >> 1;
          p_sdram_addr0 <: (row & 1) << 1;
          p_sdram_addr <: 0;
          p_sdram_addr <: bitrev(row >> 1);
          p_sdram_cmd:16 <: 0xE6AE;
          p_sdram_gate:1 <: 0 @ t0;
          t0 += 12;
          t1 = t0 + 4;
          t2 = t0 + dt;
          p_sdram_dqm0 @ t2 <: 0b0010;
          p_sdram_dqm1 @ t2 <: 0b0010;
          p_sdram_gate @ t0 <: 0b1111;  // IO: kick off
          p_sdram_cmd:8 @ t2 <: 0xE8;
          p_sdram_addr <: colw;         // IO: address
          p_sdram_dq @ t1 :> int pre_data;
          p_sdram_gate @ (t2 + 5) <: 0;
          p_sdram_dq :> x;

          client <: x;
          while (i != 0)
          {
            p_sdram_dq :> x;            // IO: data
            client <: x;
            i--;
          }
          // Note: Do not remove, turning the port around for each read() generates required timing
          p_sdram_dq <: 0;
          p_sdram_gate @ (t2 + 12) <: 0b0011;
        }
        break;
		}
	}
	client <: 0;
}
