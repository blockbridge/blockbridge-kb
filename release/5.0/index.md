---
layout: page
title: Version 5.0 Release Notes
description: New features in Blockbridge 5.0.
permalink: /release/5.0/index.html
keywords: release
toc: false
---

Blockbridge Version 5.0 is the GA release of the AnyScale architecture. The major
feature of this release is **Multi-Complex**.

### Multi-Complex

Multi-Complex provides in-the-box performance scalability designed to take
advantage of dense NVMe systems and server platforms with high core-count
processors, with a specific focus on AMD EPYC Naples and Rome. In IOPS dense
environments, a multi-complex system can reduce hardware footprint by 8 to 1 or
more! Multi-Complex boosts efficiency by extracting additional performance from
your hardware.
<br>
<br>
**Conisder multi-complex when you need to**:

* Reduce hardware costs when scaling storage performance
* Reduce hardware costs for dedicated multi-tenant scenarios
* Implement classes of storage with independent QoS guarantees
* Maximize performance density

Multi-complex configurations maintain full compatibility with your existing
applications and deployments (i.e., VMware, Kubernetes, OpenStack, etc.).

Management
--------------

Release 5.0 includes several improvements in the visibility into dataplane
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
  Usage (e.g., Read Bandwidth, IOPS, Snapshots, etc.)  to toggle a per-datastore
  breakdown that updates in real-time.


Integrations
------------

### ATS Concurrency (VMware)

Release 5.0 brings substantial concurrency improvements to the VAAI atomic
test-and-set (ATS) command, SCSI COMPARE AND WRITE.  VMware uses this command
for cluster heartbeating and to coordinate VMFS updates between cluster
members.  In this release, our implementation of the ATS primitive no longer
detectably impacts other reads and writes to the volume.

### Portal Filter (OpenStack)

Advanced filtering options in this release allow for more flexible network
selection capabilities when provisioning Blockbridge storage from OpenStack.

Data Mobility
-------------

### Inter-Dataplane Clones

Read-through "thin" clones within the same virtual storage service (VSS) have
been supported for some time.  Release 5.0 extends support to include cross-VSS
and cross-dataplane read-copy clones of snapshots.  This new type of clone
copies data on demand, as needed by user I/O operations.  Read-copy clones may
also be copied in their entirety via a background task.

(Block clones were available starting in version 4.3 as part of our early
access program.)


Performance
-----------

### GCC8 with LTO

We now build all Blockbridge software written in C or C++ with the improved
gcc8 toolchain.  We've seen small performance improvements across the board,
not to mention improved static checking.  Additionally, our dataplane I/O
processor now compiles with link-time optimizations that provide a notable
boost in performance.

### Segment Cache Hugepages

The segment cache is a foundation of our low-latency dataplane.  The cache
typically reserves between four to eight GiB of memory and is used to store
metadata for recently accessed locations on disk.  We now allocate this cache
from a pool of 1 GiB "hugepages", resulting in fewer TLB misses and improved
performance.

### Read Performance Improvements

The memory management function used to allocate scatter-gather buffers for read
operations uses an improved algorithm for sourcing contiguous regions of
memory.  This new cache-friendly technique reduces random memory references
significantly, increasing performance.

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

### Metadata Encryption Offload

The dataplane provides at-rest encryption for all metadata.  Previously,
encryption processing happened in the context of processing user I/O.  In this
release, the dataplane offloads metadata encryption to other CPU cores.  This
optimization improves concurrency during write operations significantly.

### Compression

The dataplane was updated to use Zstandard version 1.4.3 for the Economy and
Adaptive Economy data reduction modes.  This version offers not only faster
compression and decompression performance but also improved compression.

Platform
--------

### AMD EPYC Naples & Rome

Blockbridge now implements optimizations for the AMD EPYC line of server
processors.  Release 5.0 provides tight integration with the onboard SP5100
watchdog and improved handling for complex NUMA layouts.

### Encrypted Cluster Heartbeating

By default, Blockbridge 5.0 installs with encrypted cluster heartbeating, using
a pre-shared key unique to each cluster.  Blockbridge data links have always
been encrypted.  Now by encrypting the cluster heartbeating, we're protecting
against rogue nodes and providing an additional line of defense against
configuration mistakes.

### Linux Kernel 5.4

Blockbridge now ships and supports our own kernel version based on the latest
Long Term Support (LTS) linux kernel version 5.4. This kernel provides improved
NVMe support, the latest network drivers, support for the latest server
platforms, and the latest bug fixes from upstream linux. The bare-metal and
cloud images include the blockbridge kernel built-in.

### Centos 7.7

The latest CentOS 7.7 release is now the base for all Blockbridge pre-built
bare-metal and cloud images.

### Cluster Upgrade Performance

Client I/O interruption during an update is now less than half of what it was
in early 4.x series releases. Two significant changes contribute to the
performance here.  First, the dataplane now uses multi-core optimized memory
allocation to initialize the buffer cache on process restart.  Second, clusters
now upgrade their services in-place, prioritizing the quick restart of the
dataplane controller and avoiding failover.

### Volume Check Scheduling

The HEAL volume manager now has tight integration with the disk-level data
consistency checker.  You can specify a time range for each day of the week
when it's acceptable to run consistency checking, in addition to the
permissible check bandwidth and the number of concurrently checking
volumes. Planning metrics allow you to tune your desired check SLA with a
predictable performance impact.

*(Note: Some of the above features were backported to 4.x releases as part of
our early access program.)*
