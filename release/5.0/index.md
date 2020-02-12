---
layout: page
title: Blockbridge 5.0 Release Notes
description: New features in Blockbridge 5.0.
permalink: /release/5.0/index.html
keywords: release
toc: false
---

Blockbridge 5.0 is the GA release of Multi-Complex.


MULTI-COMPLEX DATAPLANE
=======================

Jon's excellent prose here.



Administration
--------------

Release 5.0 includes several improvments in the visibility into dataplane
performance and tenant usage:
<br>
<br>

* **New Datastore Statistics:** Administrators now have a system-wide view of
  task duration and queueing from the Datastore Statistics tab.

* **Improved Visibility into Tenant Usage:** The tenant usage reports available
  under nodes and accounts now include the datastore, as well as a translation
  of the virtual service serial number to the tenant's selected label.

* **Performance and Usage Visualizations:** From the administrator's view of
  the Infrastructure, select the heading of any of the elements under Global
  Usage (e.g. Read Bandwidth, IOPS, Snapshots, etc.)  to toggle a per-datastore
  breakdown that's updated in real-time.


Integrations
------------

### VMware: Improved ATS Concurrency

Release 5.0 brings substantial concurrency improvements to the VAAI atomic
test-and-set (ATS) command, SCSI COMPARE AND WRITE.  VMware uses this command
for its cluster heartbeating and to coordinate VMFS changes between cluster
members.  In this release, our implementation of the ATS primitive no longer
detectably impacts other reads and writes to the volume.

### OpenStack: Target Portals Filter

Advanced filtering options in this release allow for more optimal network
selection when provisioning Blockbridge storage from OpenStack.

Data Mobility
-------------

### Cross-Dataplane Read-Copy Clones

Blockbridge has supported read-through "thin" clones within the same virtual
storage service (VSS) for some time.  Now, you can create cross-VSS and
cross-dataplane read-copy clones of snapshots.  This new type of cloned disk
copies data on demand, as needed by user I/O operations.  Read-copy clones may
also be copied in their entirety via a background task.

(Block clones were available starting in version 4.3 as part of our early
access program.)


Performance
-----------

### Built With gcc8 And Link-Time Optimization

We now build all Blockbridge software written in C or C++ with the improved
gcc8 toolchain.  We've seen small performance improvements across the board,
not to mention improved static checking.  Additionally, we now build our
dataplane I/O processor with link-time optimization for quite a nice
performance boost.

### Segment Cache Hugepages

A cornerstone of the low-latency dataplane infrastructure, the segment cache
typically reserves between four to eight GiB of memory to cache the
logical-to-physical translation metadata for recently accessed portions of
disk.  We now allocate this cache from a pool of 1 GiB hugepages for reduced
TLB lookup time and improved performance.

### Read Performance Improvements

Read operations in the dataplane now allocate their memory from a dedicated,
contiguous region.  This cache-friendly technique reduces random memory
references significantly, increasing performance.

### Compound Operations

Older versions of the dataplane software chopped I/O's smaller than 128 KiB
into 4 KiB chunks for processing through the storage stack.  In this release,
the dataplane now handles most typical cases of I/O's that are between 4 KiB
and 128 KiB as a single unit.  This optimization reduces the length of the
internal task queue significantly, resulting in far lower latencies.

### Improved IRQ Routing

The 5.0 release includes improvements in how the dataplane balances NIC and
NVMe interrupts to achieve ultra low latency.  Interrupt routing for ethernet
attached NVMe is now managed according to the current role of the cluster
member.  And, the IRQ pattern matching logic has improved to allow for smaller,
simpler configuration.

### Out-of-Band Metadata Encryption

The dataplane encrypts its thin-provisioning metadata at rest.  Previously,
encryption processing happened in the context of processing user I/O.  In this
release, the dataplane offloads metadata encryption to other CPU cores.  This
optimization improves concurrency during write operations significantly.

### Compression with Zstandard 1.4.3

The dataplane now uses Zstandard version 1.4.3 for the Economy and Adaptive
Economy modes.  This version offers not only faster compression and decompression
performance but also much better compression.

Platform
--------

### AMD Server Support

Blockbridge now fully supports the AMD EPYC line of server processors.  Release
5.0 brings tight integration with the on-board SP5100 watchdog and improved
handling for complex NUMA layouts.

### Encrypted Cluster Heartbeating

By default, Blockbridge 5.0 installs with encrypted cluster heartbeating, using
a pre-shared key unique to each cluster.  Blockbridge data links have always
been encrypted.  Now by encrypting the cluster heartbeating, we're protecting
against rogue nodes and providing an additional line of defense against
configuration mistakes.

### Blockbridge 5.4 Kernel

Blockbridge now ships and supports our own kernel version based on the latest
Long Term Support (LTS) linux kernel version 5.4. This kernel provides full
NVMe support, the latest network drivers, support for the latest server
platforms, and the latest bug fixes from upstream linux. The bare-metal and
cloud images include the blockbridge kernel built-in.

### Centos 7.7

We use the latest CentOS 7.7 release as the basis for all Blockbridge pre-built
bare-metal and cloud images.

### Improved Cluster Upgrade Uptime

Upgrade downtime is less than half of what it was in early 4.x series releases.
Two major changes contribute to the performance here.  First, the dataplane now
uses multi-core memory allocation to bring the buffer cache online sooner after
restart.  Second, clusters now upgrade their services in-place, prioritizing
the quick restart of the dataplane controller.

### Enhanced HEAL Volume Check Scheduling

The HEAL volume manager now has tight integration with the kernel RAID
consistency checker.  You can specify a time range each day of the week when
it's acceptable to do consistency checking, in addition to the permissible
check bandwidth and the number of concurrently checking volumes.

*(Note: Some of the above features were backported to earlier 4.x releases as
part of our early access program.)*

