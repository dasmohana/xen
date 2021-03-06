***********************************************
Intel Memory Bandwidth Allocation (MBA) Feature
***********************************************

- Status: **Tech Preview**
- Architecture(s): Intel x86
- Component(s): Hypervisor, toolstack
- Hardware: MBA is supported on Skylake Server and beyond

===========
Terminology
===========

* CAT         Cache Allocation Technology
* CBM         Capacity BitMasks
* CDP         Code and Data Prioritization
* COS/CLOS    Class of Service
* HW          Hardware
* MBA         Memory Bandwidth Allocation
* MSRs        Machine Specific Registers
* PSR         Intel Platform Shared Resource
* THRTL       Throttle value or delay value

========
Overview
========

The Memory Bandwidth Allocation (MBA) feature provides indirect and approximate
control over memory bandwidth available per-core. This feature provides OS/
hypervisor the ability to slow misbehaving apps/domains by using a credit-based
throttling mechanism.

============
User Details
============

* Feature Enabling:

  Add "psr=mba" to boot line parameter to enable MBA feature.

* xl interfaces:

  1. `psr-mba-show [domain-id|domain-name]`:

     Show memory bandwidth throttling for domain. Under different modes, it
     shows different type of data.

     There are two modes:
     Linear mode: the input precision is defined as 100-(MBA_MAX). For instance,
     if the MBA_MAX value is 90, the input precision is 10%. Values not an even
     multiple of the precision (e.g., 12%) will be rounded down (e.g., to 10%
     delay applied) by HW automatically. The response of throttling value is
     linear.

     Non-linear mode: input delay values are powers-of-two from zero to the
     MBA_MAX value from CPUID. In this case any values not a power of two will
     be rounded down the next nearest power of two by HW automatically. The
     response of throttling value is non-linear.

     For linear mode, it shows the decimal value. For non-linear mode, it shows
     hexadecimal value.

  2. `psr-mba-set [OPTIONS] <domain-id|domain-name> <throttling>`:

     Set memory bandwidth throttling for domain.

     Options:
     '-s': Specify the socket to process, otherwise all sockets are processed.

     Throttling value set in register implies the approximate amount of delaying
     the traffic between core and memory. Higher throttling value result in
     lower bandwidth. The max throttling value (MBA_MAX) supported can be
     obtained through CPUID inside hypervisor. Users can fetch the MBA_MAX value
     using the `psr-hwinfo` xl command.

=================
Technical Details
=================

MBA is a member of Intel PSR features, it shares the base PSR infrastructure
in Xen.

Hardware Perspective
~~~~~~~~~~~~~~~~~~~~

  MBA defines a range of MSRs to support specifying a delay value (Thrtl) per
  COS, with details below.

  ```
   +----------------------------+----------------+
   | MSR (per socket)           |    Address     |
   +----------------------------+----------------+
   | IA32_L2_QOS_Ext_BW_Thrtl_0 |     0xD50      |
   +----------------------------+----------------+
   | ...                        |  ...           |
   +----------------------------+----------------+
   | IA32_L2_QOS_Ext_BW_Thrtl_n |     0xD50+n    |
   +----------------------------+----------------+
  ```

  When context switch happens, the COS ID of domain is written to per-hyper-
  thread MSR `IA32_PQR_ASSOC`, and then hardware enforces bandwidth allocation
  according to the throttling value stored in the Thrtl MSR register.

Relationship between MBA and CAT/CDP
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  Generally speaking, MBA is completely independent of CAT/CDP, and any
  combination may be applied at any time, e.g. enabling MBA with CAT
  disabled.

  But it needs to be noticed that MBA shares COS infrastructure with CAT,
  although MBA is enumerated by different CPUID leaf from CAT (which
  indicates that the max COS of MBA may be different from CAT). In some
  cases, a domain is permitted to have a COS that is beyond one (or more)
  of PSR features but within the others. For instance, let's assume the max
  COS of MBA is 8 but the max COS of L3 CAT is 16, when a domain is assigned
  9 as COS, the L3 CAT CBM associated to COS 9 would be enforced, but for MBA,
  the HW works as default value is set since COS 9 is beyond the max COS (8)
  of MBA.

Design Overview
~~~~~~~~~~~~~~~

* Core COS/Thrtl association

  When enforcing Memory Bandwidth Allocation, all cores of domains have
  the same default Thrtl MSR (COS0) which stores the same Thrtl (0). The
  default Thrtl MSR is used only in hypervisor and is transparent to tool stack
  and user.

  System administrators can change PSR allocation policy at runtime by
  using the tool stack. Since MBA shares COS ID with CAT/CDP, a COS ID
  corresponds to a 2-tuple, like [CBM, Thrtl] with only-CAT enabled, when CDP
  is enabled, the COS ID corresponds to a 3-tuple, like [Code_CBM, Data_CBM,
  Thrtl]. If neither CAT nor CDP is enabled, things are easier, since one COS
  ID corresponds to one Thrtl.

* VCPU schedule

  This part reuses CAT COS infrastructure.

* Multi-sockets

  Different sockets may have different MBA capabilities (like max COS)
  although it is consistent on the same socket. So the capability
  of per-socket MBA is specified.

  This part reuses CAT COS infrastructure.

Implementation Description
~~~~~~~~~~~~~~~~~~~~~~~~~~

* Hypervisor interfaces:

  1. Boot line param: "psr=mba" to enable the feature.

  2. SYSCTL:
          - XEN_SYSCTL_PSR_MBA_get_info: Get system MBA information.

  3. DOMCTL:
          - XEN_DOMCTL_PSR_MBA_OP_GET_THRTL: Get throttling for a domain.
          - XEN_DOMCTL_PSR_MBA_OP_SET_THRTL: Set throttling for a domain.

* xl interfaces:

  1. psr-mba-show [domain-id]
          Show system/domain runtime MBA throttling value. For linear mode,
          it shows the decimal value. For non-linear mode, it shows hexadecimal
          value.
          => XEN_SYSCTL_PSR_MBA_get_info/XEN_DOMCTL_PSR_MBA_OP_GET_THRTL

  2. psr-mba-set [OPTIONS] <domain-id> <throttling>
          Set bandwidth throttling for a domain.
          => XEN_DOMCTL_PSR_MBA_OP_SET_THRTL

  3. psr-hwinfo
          Show PSR HW information, including L3 CAT/CDP/L2 CAT/MBA.
          => XEN_SYSCTL_PSR_MBA_get_info

* Key data structure:

  1. Feature HW info

     ```
     struct {
         unsigned int thrtl_max;
         bool linear;
     } mba;

     - Member `thrtl_max`

       `thrtl_max` is the max throttling value to be set, i.e. MBA_MAX.

     - Member `linear`

       `linear` means the response of delay value is linear or not.

     As mentioned above, MBA is a member of Intel PSR features, it shares the
     base PSR infrastructure in Xen. For example, the 'cos_max' is a common HW
     property for all features. So, for other data structure details, please
     refer to 'intel_psr_cat_cdp.pandoc'.

===========
Limitations
===========

MBA can only work on HW which supports it (check CPUID).

=======
Testing
=======

We can execute these commands to verify MBA on different HWs supporting them.

For example:
  1. User can get the MBA hardware info through 'psr-hwinfo' command. From
     result, user can know if this hardware works under linear mode or non-
     linear mode, the max throttling value (MBA_MAX) and so on.

    root@:~$ xl psr-hwinfo --mba
    Memory Bandwidth Allocation (MBA):
    Socket ID       : 0
    Linear Mode     : Enabled
    Maximum COS     : 7
    Maximum Throttling Value: 90
    Default Throttling Value: 0

  2. Then, user can set a throttling value to a domain. For example, set '10',
     i.e 10% delay.

    root@:~$ xl psr-mba-set 1 10

  3. User can check the current configuration of the domain through
     'psr-mab-show'. For linear mode, the decimal value is shown.

    root@:~$ xl psr-mba-show 1
    Socket ID       : 0
    Default THRTL   : 0
       ID                     NAME            THRTL
        1                 ubuntu14             10

=====================
Areas for Improvement
=====================

N/A

============
Known Issues
============

N/A

==========
References
==========

`INTEL RESOURCE DIRECTOR TECHNOLOGY (INTEL RDT) ALLOCATION FEATURES [Intel 64 and IA-32 Architectures Software Developer Manuals, vol3]<http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html>`__

=========
Changelog
=========

------------------------------------------------------------------------
Date       Revision Version  Notes
---------- -------- -------- -------------------------------------------
2017-01-10 1.0      Xen 4.9  Design document written
2017-07-10 1.1      Xen 4.10 Changes:
                             1. Modify data structure according to latest
                                codes;
                             2. Add content for 'Areas for improvement';
                             3. Other minor changes.
2017-08-09 1.2      Xen 4.10 Changes:
                             1. Remove a special character to avoid error when
                                building pandoc.
2017-08-15 1.3      Xen 4.10 Changes:
                             1. Add terminology 'HW'.
                             2. Change 'COS ID of VCPU' to 'COS ID of domain'.
                             3. Change 'COS register' to 'Thrtl MSR'.
                             4. Explain the value shown for 'psr-mba-show' under
                                different modes.
                             5. Remove content in 'Areas for improvement'.
2017-08-16 1.4      Xen 4.10 Changes:
                             1. Add '<>' for mandatory argument.
2017-08-30 1.5      Xen 4.10 Changes:
                             1. Modify words in 'Overview' to make it easier to
                                understand.
                             2. Explain 'linear/non-linear' modes before mention
                                them.
                             3. Explain throttling value more accurate.
                             4. Explain 'MBA_MAX'.
                             5. Correct some words in 'Design Overview'.
                             6. Change 'mba_info' to 'mba' according to code
                                changes. Also, modify contents of it.
                             7. Add context in 'Testing' part to make things
                                more clear.
                             8. Remove 'n<64' to avoid out-of-sync.
2017-09-21 1.6      Xen 4.10 Changes:
                             1. Add 'domain-name' as parameter of 'psr-mba-show/
                                psr-mba-set'.
                             2. Fix some wordings.
                             3. Explain how user can know the MBA_MAX.
                             4. Move the description of 'Linear mode/Non-linear
                                mode' into section of 'psr-mba-show'.
                             5. Change 'per-thread' to 'per-hyper-thread'.
2017-09-29 1.7      Xen 4.10 Changes:
                             1. Correct some words.
                             2. Change 'xl psr-mba-set 1 0xa' to
                                'xl psr-mba-set 1 10'
2017-10-08 1.8      Xen 4.10 Changes:
                             1. Correct some words.
---------- -------- -------- -------------------------------------------
