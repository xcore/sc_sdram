XCORE.com SDRAM SOFTWARE COMPONENT
..................................

:Stable release:  1.2 unreleased - based on SDRAM 1.1 of April 2010

:Status:  Initial updates to current tools, pending testing. 

:Maintainer:  `Russ Ferriday <https://github.com/topiaruss>`_ 

:Description:  A Burst Mode access driver for the Micron Technology
 MT48LC16M16A2 Synchronous DRAM


Key Features
============

  * One thread reads/writes data to SDRAM
  * Optimised for burst access of blocks of 32 bit words (not for random access)
  * Application retains control of refresh by calling sdram_refresh at
    appropriate to prevent unexpected delays
  * 16-bit - Peak write: 50MB/s, read 50MB/s. 
    Single word write  (3 threads): 3120ns, read 3520ns.
  * 4-bit -   Peak write: 12.5MB/s, read 12.5MB/s.
    Single word write (4 threads): approx 2.5us, approx 3us. 
  * Code size: 2KB
  * Thread count: 1

To Do
=====

* Test on representative hardware. 
* Document test procedure and check schematics
* Resolve two warnings related to buffered port
* Improve documentation for integrators

Firmware Overview
=================

 * module_sdram_burst: the burst mode driver
 * app_sdram_burst_example: contains a c client and an xc test harness
 
Known Issues
============

* Two warnings produced in XDE 11.2 related to buffered port
* Untested since moving to XDE 11.2

Required Repositories
=====================

* xcommon git\@github.com:xcore/xcommon.git

Support
=======

Issues may be submitted via the Issues tab in this github repo. Response to any issues submitted are at the discretion of the maintainer of this component.
