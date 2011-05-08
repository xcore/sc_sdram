/**
 * Module:  app_sdram_burst_example
 * Version: 1v1
 * Build:   eb5cce73e7f7b93b19b9fbd609ded15dc3c5cb05
 * File:    client.c
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
#include <xccompat.h>

// In order to use negative indexing and get a 4 instruction loop, we need pointer arithmetics
// Hence C (rather than XC)
#define OUT(c, x) asm("out res[%0], %1" : : "r"(c), "r"(x))
#define IN(c, x) asm("in %0, res[%1]" : "=r"(x) : "r"(c))
#define OUTCT_END(c) asm("outct res[%0], %1" : : "r"(c), "i"(XS1_CT_END))
#define CHKCT_END(c) asm("chkct res[%0], %1" : : "r"(c), "i"(XS1_CT_END))

// LLVM canonical loop transformations (XMOS bug 6253) produce 5 instructions
// Assembly required to get 4
#ifdef __llvm__
#define BRBT(x, off) asm("bt %0, %1" : : "r"(x), "i"(off))
#define INC(x) asm("add %0, %1, 1" : "=r"(x) : "r"(x))
#define LOAD(word, base, off) asm("ldw %0, %1[%2]" : "=r"(word) : "r"(base), "r"(off))
#define STORE(word, base, off) asm("stw %0, %1[%2]" : : "r"(word), "r"(base), "r"(off))
#endif

void sdram_write(chanend c, int bank, int row, int col, const unsigned words[], int nwords)
{
	const unsigned *ptr;
	int index;
	unsigned word;
   
	// Output write command
	OUTCT_END(c);
	CHKCT_END(c);
	OUT(c, 3);
	OUTCT_END(c);
	CHKCT_END(c);

	// Init slave output
	CHKCT_END(c);

	// Out bank row col nwords
	OUT(c, bank);
	OUT(c, row);
	OUT(c, col);
	OUT(c, nwords);

	ptr = words + nwords;
	index = -nwords - 1; 

  // See comment above
	while (index != 0)
	{
#ifndef __llvm__
		index++;
		word = ptr[index];
#else
    INC(index);
    LOAD(word, ptr, index);
#endif
		OUT(c, word);
	}

	// End slave
	OUTCT_END(c);
	CHKCT_END(c);
}

void sdram_read(chanend c, int bank, int row, int col, unsigned words[], int nwords)
{
	unsigned *ptr;
	int index;
	unsigned word;

	// Output read command
	OUTCT_END(c);
	CHKCT_END(c);
	OUT(c, 4);
	OUTCT_END(c);
	CHKCT_END(c);

	// Init slave input
	CHKCT_END(c);

	// Out bank row col nwords
	OUT(c, bank);
	OUT(c, row);
	OUT(c, col);
	OUT(c, nwords);

	// Output a END token for ABI
	OUTCT_END(c);

#ifdef SERVER_NOT_UNROLLED
	// Dummy input
	IN(c, word);
#endif

	ptr = words + nwords;
	index = -nwords;

  // See comment above
	while (index != 0)
	{
		IN(c, word);
#ifndef __llvm__
		ptr[index] = word;
		index++;
#else
    STORE(word, ptr, index);
    INC(index);
#endif
	}

	// End slave
	OUTCT_END(c);
	CHKCT_END(c);
}
