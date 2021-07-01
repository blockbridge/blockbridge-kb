---
layout: page
title: Blockbridge 5.1.3 Release Notes
description: What's changed in Blockbridge 5.1.3
permalink: /release/5.1.3/index.html
keywords: release 5.x 5.1 5.1.3
toc: false
---

Blockbridge Version 5.1.3 adds long-awaited Grafana support for dataplane
complex statistics in addition to numerous bug fixes and other minor
enhancements.  It also brings an important Linux kernel fix for all Blockbridge
5.1 installations.

---

Management
----------

* **Grafana:** We're excited to offer Grafana support for datastore statistics.
  You can monitor all of your Blockbridge storage engines from a single
  dashboard, using the standard JSON datasource plugin.  Ask us for our example
  dashboard!
* **Capacity-Scaled Burst IOPS Credits:** You can now create service templates
  that scale the IOPS burst credit pool with the capacity of the provisioned
  volume.
* **Compression Scheduling:** The datastore now supports a daily schedule for
  performing data compression.  The dataplane maintains a list of data segments
  to compress during the off hours, then processes them when the schedule
  permits.

---

Platform & Dataplane
--------------------

* **Kernel 5.4.21 Hotfix:** Incorporate upstream kernel patch 6920cef
  (md/raid1: properly indicate failure when ending a failed write request) into
  the Blockbridge 5.4.21 kernel.  All Blockbridge 5.x series installs should
  upgrade.  (Blockbridge 4.x installs are unaffected.)
* **Lower Memory Fragmentation:** We've improved our memory allocation
  techniques on the dataplane to avoid creating small, unusable sections of
  RAM.
* **Improved Failover and Service Move Times:** We've improved the way that the
  Heal and Disk platform services coordinate on a service move action to
  improve the time to clean shutdown.  And on startup or failover, the
  dataplane is quicker about opening and recovering volumes.  Most failovers
  should be two to four seconds quicker.
* **Per-Volume Maintenance Mode:** volumectl now supports setting a
  "maintenance mode" on a Heal volume to prevent the system from automatically
  replacing a failed drive.
* **NVMe Secure Erase:** the disk service now provides a built-in interface to
  the `nvme format` command line tool.

---

Snapshot Reclaim
----------------

Some workloads with partial overwrites of data segments cause patterns of space
allocation such that some unneeded segments weren't returned to the pool when
their snapshots were removed.  In 5.1.3, we've adjusted the snapshot
reclamation algorithm to perform a deeper inspection for storage to be
released, resulting in improved efficiency.


---

Web UI
------

* **Statistics Widget:** trimmed the significant figures shown in the tooltip
  back on some series.
* **Datastore Statistics:** In 5.1.3, we significantly reworked the list of
  available statistics for the datastore to make the (long) list easier on the
  eyes.  All the old favorites are there, and we've added a distinction between
  I/O's measured at the QoS enforcement point vs. those in the core of the
  thin-provisioning controller.

---
 
Blockbridge Shell
-----------------

* Do not need to stop services to remove a cluster fence.
* In "vip del", the list of VIPs is now sorted.
* On service start or stop, shell warns if maintenance mode is enabled.

---

Bugs Fixed
----------

* We fixed an extremely rare case of stuck I/O requests on volumes with IOPS
  limits enabled.
* Sending-side statistics for targets now properly count status PDUs.
* Fixed instances where the datastore cache-hit statistic reported incorrect values
  under certain workloads.
* Dataplane complex IOPS gauges were sometimes observed to oscillate ~10% when
  the rates were in the 100,000 IOPS range, or higher.  This is now fixed.
* Fixed a rare case where the iSCSI target discovery reply could be empty when
  interfaces were disabled.
* Fixed a rare race condition that could cause cross-vss block clones to hang
  after a vdisk resize.
* Fixed a race condition triggered by SCSI logical unit reset commands that in
  rare cases could cause I/O hang to a disk.
* Fixed an unusual case where an overwrite of just-written data has to wait for
  the data journal to flush.
* Fixed a startup memory allocation failure on systems with very large
  compressed record cache memory.
* The cluster now tolerates link failures while in maintenance mode.
* Fixed a parsing error that occurred after 9,999 iSCSI attaches on the same
  Linux host.
* Fixed a parsing error with array check schedule times that had leading
  zeroes.
* We closed an open internal HTTP port detected by Nessus.  All Blockbridge
  internal services require certificate validation, so there was never any
  security risk.  But there was also no reason to have the port exposed.
* We fixed a display issue where, during upgrade, some statistics series would
  occasionally show a large negative dip.
