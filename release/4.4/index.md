---
layout: page
title: Version 5.4 Release Notes
description: What's changed in Blockbridge 4.4.
permalink: /release/4.4/index.html
keywords: release 4.4
toc: false
---

Blockbridge Version 4.4 is a maintenance release focused on stability
improvements and performance gains.

---

Dataplane
---------

* We **significantly improved the performance of writes that allocate storage**
  with a blend of database optimizations and system tunings.  Though most
  benchmarks focus on already "thickened" storage, real world applications
  frequently allocate storage on demand.

* **Metadata Encryption Offload** *(backported from 5.0)*: The
  dataplane provides at-rest encryption for all metadata.  Previously,
  encryption processing happened in the context of processing user I/O.  The
  dataplane now offloads metadata encryption to other CPU cores, improving
  concurrency during write operations significantly.

* **Compound Read Operations for Snapshots and Clones**: This feature
  extends the dataplane's optimized compound operation handling to reads of
  cloned disks and reads on disks with complex snapshot histories.

* **Addressed a rare race condition** where an "out of space" error could be
  returned to clients prematurely when the system was operating with less than
  1 GiB remaining capacity.

* Fixed incorrect SCSI sense code when THIRD PARTY COPY target was remote.

* Startup and failover times improved on SATA and NVMe systems with many
  drives.

* Hyper-V support: issue more frequent iSCSI NOP probes.

---

Web UI
------

* **Disk snapshots panel:** improve handling for updates while in edit mode.
* **Improvements to Account Reports:** display VSS labels and add a datastore
  column.
* **Performance and Usage Visualizations:** *(backported from 5.0)* From the
  administrator's view of the Infrastructure, select the heading of any of the
  elements under Global Usage (e.g., Read Bandwidth, IOPS, Snapshots, etc.)  to
  toggle a per-datastore breakdown that updates in real-time.
* **Numerous tweaks and adjustments** throughout the UI.


---
 
CLI
---

* **Improved error handling for IPsec "host attach"** including
  controlplane-side errors and checking for the StrongSwan duplicheck plugin.

---

Platform
--------

* Support for custom slot names in enclosure definitions.
* Fixed conversion to bytes of certain SMART values represented in gigabytes.
* Reduced volume of diagnostic logging for Blockbridge components.
* Added manpages for CPU, Memory, Filesystem, and Heal Volume system probe types.
* Additional chassis definitions for Supermicro platforms.

