/**
 * Module:  app_sdram_burst_example
 * Version: 1v1
 * Build:   eb5cce73e7f7b93b19b9fbd609ded15dc3c5cb05
 * File:    test.xc
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
#include <xs1.h>
#include <platform.h>
#include <stdlib.h>
#include <print.h>
#include "sdram_burst.h"

void result(int pass)
{
#ifndef SIMULATION
  if (!pass)
  {
    printstr("FAIL\n");
    exit(1);
  }
  else
  {
    printstr("PASS\n");
  }
#endif
}

void print(const char msg[], unsigned t)
{
  printstr(msg);
  printint(t * 10);
  printstr("ns\n");
}

#pragma unsafe arrays
void traffic_pausable(chanend t)
{
  unsigned x[8];
  unsigned i = 1;
  int active = 0;
  while (1)
  {
#pragma ordered
    select
    {
      case t :> active: break;
      default:
      {
    	if (active) {
			unsigned y = x[(i - 1) & 7];
			crc32(y, 0x48582BAC, 0xFAC91003);
			x[i & 7] = y;
			i++;
			}
        break;
      }
    }
  }
}

#pragma unsafe arrays
void traffic()
{
  unsigned x[8];
  unsigned i = 1;
  while (1)
  {
    unsigned y = x[(i - 1) & 7];
    crc32(y, 0x48582BAC, 0xFAC91003);
    x[i & 7] = y;
    i++;
  }
}

void simple(chanend c)
{
  int pass = 1;
  unsigned wrdata[4] = { 0xABCDEF12, 2, 3, 4 };
  unsigned rddata[4] = { 0, 0, 0, 0 };

  printstr("+ Simple test\n");

  sdram_write(c, 1, 5, 7, wrdata, 4);
  sdram_read(c, 1, 5, 7, rddata, 4);
  sdram_refresh(c);

  for (int i = 0; i < 4; i++)
  {
    if (rddata[i] != wrdata[i])
    {
      pass = 0;
#ifndef SIMULATION
      printstr("a:");
      printint(i);
      printstr(" d:0x"); printhex(rddata[i]); printstr("/0x"); printhex(wrdata[i]);
      printstr("\n");
#endif
    }
  }

  result(pass);
}

void timing(chanend c)
{
  timer tmr;
  register unsigned start, end;
  unsigned x[1] = { 0xABCDEF12 };
  unsigned y[1];

  printstr("+ Timing test\n");
  printstr("4 threads, all 4 active during read/write\n");

  tmr :> start;
  for (register int i = 0; i < 64; i++)
  {
    sdram_write(c, 3, 157, 24, x, 1);
  }
  tmr :> end;
  print("Write time: ", (end - start) / 64);

  tmr :> start;
  for (register int i = 0; i < 64; i++)
  {
    sdram_read(c, 3, 157, 24, y, 1);
  }
  tmr :> end;
  print("Read time: ", (end - start) / 64);

  sdram_refresh(c);
}

void burst32(chanend c)
{
  int pass = 1;
  unsigned y0[32], y1[32];

  printstr("+ Normal length burst test (ETA 6sec)\n");

  printstr("Generating...");
  y0[0] = 0x12345678;
  for (int i = 1; i < 32; i++)
  {
    unsigned y = y0[i - 1];
    crc32(y, 0x48582BAC, 0xFAC91003);
    y0[i] = y;
  }
 
  printstr("writing...");
  for (int bank = 0; bank < 4; bank++)
  {
    for (int row = 0; row < 8192; row++)
    {
      for (int col = 0; col < 256; col += 32)
      {
        sdram_write(c, bank, row, col, y0, 32);
        sdram_refresh(c);
      }
    }
  }

  printstr("reading and checking...");
  sdram_refresh(c);
  for (int bank = 0; bank < 4; bank++)
  {
    for (int row = 0; row < 8192; row++)
    {
      for (int col = 0; col < 256; col += 32)
      {
        sdram_read(c, bank, row, col, y1, 32);
        sdram_refresh(c);
        for (int i = 0; i < 32; i++)
        {
          if (y1[i] != y0[i])
          {
            pass = 0;
#ifndef SIMULATION
            printstr("a:");
            printint(bank); printstr(","); printint(row); printstr(","); printint(col); printstr(","); printint(i);
            printstr(" d:0x"); printhex(y1[i]); printstr("/0x"); printhex(y0[i]);
            printstr("\n");
#endif
          }
        }

      }
    }
  }

  result(pass);
}

void burst1(chanend c)
{
  int pass = 1;
  unsigned y0[256];

  printstr("+ Min length burst test (ETA 1min)\n");

  printstr("Generating...");
  y0[0] = 0x12345678;
  for (int i = 1; i < 256; i++)
  {
    unsigned y = y0[i - 1];
    crc32(y, 0x48582BAC, 0xFAC91003);
    y0[i] = y;
  }
 
  printstr("writing...");
  for (int bank = 0; bank < 4; bank++)
  {
    for (int row = 0; row < 8192; row++)
    {
      for (int col = 0; col < 256; col++)
      {
        unsigned y[1];
        int i = (col + row) % 256;
        y[0] = y0[i];
        sdram_write(c, bank, row, col, y, 1);
        if (col & 3)
          sdram_refresh(c);
      }
    }
  }

  printstr("reading and checking...");
  for (int bank = 0; bank < 4; bank++)
  {
    for (int row = 0; row < 8192; row++)
    {
      for (int col = 0; col < 256; col++)
      {
        unsigned y[1];
        int i = (col + row) % 256;
        sdram_read(c, bank, row, col, y, 1);
        if (y[0] != y0[i])
        {
          pass = 0;
#ifndef SIMULATION
          printstr("a:");
          printint(bank); printstr(","); printint(row); printstr(","); printint(col);
          printstr(" d:0x"); printhex(y[0]); printstr("/0x"); printhex(y0[i]);
          printstr("\n");
#endif
        }
        if (col & 3)
          sdram_refresh(c);
      }
    }
  }

  result(pass);
}

void burst256(chanend c)
{
  int pass = 1;
  unsigned y0[256], y1[256];

  printstr("+ Max length burst test (ETA 4sec)\n");

  printstr("Generating...");
  y0[0] = 0x12345678;
  for (int i = 1; i < 256; i++)
  {
    unsigned y = y0[i - 1];
    crc32(y, 0x48582BAC, 0xFAC91003);
    y0[i] = y;
  }
 
  printstr("writing...");
  for (int bank = 0; bank < 4; bank++)
  {
    for (int row = 0; row < 8192; row++)
    {
      sdram_write(c, bank, row, 0, y0, 256);
      sdram_refresh(c);
    }
  }

  printstr("reading and checking...");
  for (int bank = 0; bank < 4; bank++)
  {
    for (int row = 0; row < 8192; row++)
    {
      sdram_read(c, bank, row, 0, y1, 256);
      for (int i = 0; i < 256; i++)
      {
        if (y1[i] != y0[i])
        {
          pass = 0;
#ifndef SIMULATION
          printstr("a:");
          printint(bank); printstr(","); printint(row); printstr(","); printint(i);
          printstr(" d:0x"); printhex(y1[i]); printstr("/0x"); printhex(y0[i]);
          printstr("\n");
#endif
        }
      }
      sdram_refresh(c);
    }
  }

  result(pass);
}

void init(chanend c)
{
  sdram_init(c);
  sdram_refresh(c);
}

void traffic_test(chanend c)
{
  const unsigned wrdata[4] = { 0xABCDEF12, 2, 3, 4 };
  unsigned rddata[4] = { 0, 0, 0, 0 };
  int pass = 1;

  sdram_read(c, 1, 5, 7, rddata, 4);
  sdram_refresh(c);

  for (int i = 0; i < 4; i++)
  {
    if (rddata[i] != wrdata[i])
    {
      pass = 0;
#ifndef SIMULATION
      printstr("a:");
      printint(i);
      printstr(" d:0x"); printhex(rddata[i]); printstr("/0x"); printhex(wrdata[i]);
      printstr("\n");
#endif
    }
  }

  result(pass);
  exit(0);
}

void test(chanend c)
{
  init(c);
  simple(c);
  timing(c);
  burst32(c);
  burst256(c);
  burst1(c);
  printstr("All tests passed OK\n");
  exit(0);
}

int main()
{
  chan c;
  par
  {
    on stdcore[1] : sdram_server(c);
    on stdcore[1] :
    {
			printstrln("required min tools version: 9.9.0");
			printstrln("tested with XC optimisation level O2");
      par
      {
        traffic();
        traffic();
        traffic();
        traffic();
        traffic();
        traffic();
        traffic();
      }
    }
    on stdcore[0] : test(c);
  }
  return 0;
}
