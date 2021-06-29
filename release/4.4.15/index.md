---
layout: page
title: Version 4.4.15 Release Notes
description: What's changed in Blockbridge 4.4.15
permalink: /release/4.4.15/index.html
keywords: release 4.4 4.4.15
toc: false
---

Blockbridge Version 4.4.15 brings numerous enhancements from our 5.x releases
into the 4.4 codebase, focused on stability improvements and performance gains.
In addition, this release adds support for multi-cloud Openstack deployments.

---

Management
----------

* **Multi-Cloud Openstack:** We've expanded the types of OpenStack deployments
we can support.  Prior versions of our Cinder driver were limited to one
Openstack cloud per Blockbridge controlplane.  With this release, Blockbridge's
4.4 release stream now supports multiple OpenStack clouds and per-tenant
accounts and capacity-scaled burst IOPS credits.
* **Capacity-Scaled Burst IOPS Credits:** Starting with release 4.4.15, you can
create service templates that scale the IOPS burst credit pool with the
capacity of the provisioned volume.

---

Compression Metadata
--------------------

Release 4.4.15 benefits from extensive efforts to improve the performance of
compression-related metadata.

* **Metadata Efficiency:** On systems with a heavy re-write workload, database
pages that store compression metadata could become inefficiently used, leading
to increased lookup times.  In 4.4.15, we have improved the way our B+tree
handles these pages yielding a much improved fill-factor and compact metadata
layout.
* **Metadata Cache:** Efficiency has improved more than 40%.
* **Metadata Concurrency:** For large installations where the compression
metadata exceeds the cache size, we've improved our database concurrency by
more than an order of magnitude.
* **Cache Sweeping:** We've taken steps to limit the impact of compression
scans on the metadata cache.  These scans now use their own pool of cache
memory, to avoid impacting cached user metadata.

---

Performance
-----------

* **Snapshot Remove Fairness:** This release offers lower latency and higher
IOPS for user traffic during snapshot removal (reclaim) metadata scans,
effectively getting the system's traffic out of the way of user I/O.
* **Improved IRQ Routing:** This release includes improvements in how the
dataplane balances NIC and NVMe interrupts to achieve ultra low latency.
Interrupt routing for Ethernet attached NVMe is now managed according to the
current role of the cluster member.  And, the IRQ pattern matching logic has
improved to allow for smaller, simpler configuration.
* **Lower Memory Fragmentation:** We've improved our memory allocation
techniques on the dataplane to avoid creating small, unusable sections of RAM.

---

Platform
--------

* **SCSI Enclosure Stability:** Some Supermicro SCSI expanders manufactured in
2020 came with faulty firmware that would stop responding to SES enclosure
queries.  With support from our storage lab, they were able to address the
issue.  Firmware revisions from 16.16.14.00 have the fix.  Blockbridge platform
management software gained improved resiliency against flaky SCSI enclosures.
* **Improved Failover Times:** The dataplane is quicker about opening and
recovering volumes.  Most failovers should be about two seconds quicker.

---

Web UI
------

* **Statistics Widget:** trimmed the significant figures shown in the tooltip
  back on some series.

---
 
CLI
---

* Added support for Debian 10 ("Buster") and Ubuntu 20.04.

---

Bugs Fixed
----------

* We fixed an extremely rare case of stuck I/O requests on volumes with IOPS
  limits enabled.
* Sending-side statistics for targets now properly count status PDUs.
* Fixed instances where the datastore cache-hit statistic reported wild values
  under certain workloads.
* Dataplane complex IOPS gauges were sometimes observed to oscillate ~10% when
  the rates were in the 100,000 IOPS range, or higher.  This is now fixed.
* Fixed a rare case where the iSCSI target discovery reply could be empty when
  interfaces were disabled.
* Fixed a rare race condition that could cause cross-vss block clones to hang
  after a vdisk resize.
* The cluster now tolerates link failures while in maintenance mode.
* Fixed a race condition triggered by SCSI logical unit reset commands that in
  rare cases could cause I/O hang to a disk.
* Fixed an unusual case where an overwrite of just-written data has to wait for
  the data journal to flush.
* Fixed a startup memory allocation failure on systems with very large
  compressed record cache memory.
* During upgrade, some statistics series would sometimes show a large negative
  dip.  We've finally fixed this tricky bug.  Upgrades to 4.4.15 should see no
  interruption in statistics.

