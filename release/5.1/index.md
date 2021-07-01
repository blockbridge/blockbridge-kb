---
layout: page
title: Version 5.1 Release Notes
description: New features in Blockbridge 5.1.
permalink: /release/5.1/index.html
keywords: release 5.1
toc: false
---

Blockbridge Version 5.1 updates the widely deployed 5.x AnyScale architecture.
This release brings numerous performance and stability improvements alongside
support for Proxmox, multi-cloud Openstack deployments, Grafana, and an updated
Kubernetes driver.

This document is current as of **version 5.1.3**.  It incorporates all changes
from the minor versions of 5.1 (5.1.1, 5.1.2, etc.)

---

Management
----------

Release 5.1.3 includes several improvements in management for both the
web application and the command line tool.
<br>

* **CLI Roles and Levels:** The CLI tool now offers a more focused workflow for
  tenants by appropriately restricting the visibility of administrative and
  infrastructure commands.  Admins can further limit or expand the number of
  commands and options shown with levels like "advanced" and "expert" levels.

* **Hourly Roll-up Datastore Statistics:** You can now view a robust set of
  utilization statistics from the CLI, via the "datastore stats" subcommand.

* **Enclosure and Volume Visibility:** The web console now affords a more
  consistent and easier to navigate view of enclosures, volumes, and their
  underlying physical storage devices.

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

Integrations
------------

### Proxmox

Deploying Proxmox on Blockbridge just got a lot simpler.  Release 5.1 brings
full shared-block storage support for Proxmox with a supported plugin.  Use the
full suite of Blockbridge features:

* High Availability
* Multi-Tenancy & Multi-Proxmox
* High Performance
* At-Rest & In-Flight Encryption
* Snapshots & Clones
* Thin Provisioning & Data Reduction

### Multi-Cloud Openstack

In 5.1, we've expanded the types of OpenStack deployments we can support.
Prior versions of our Cinder driver were limited to one Openstack cloud per
Blockbridge controlplane.  The 5.1 release now includes support for multiple
OpenStack clouds and per-tenant accounts.

### Kubernetes Version 1.14

Our K8s driver version 2.0.0 is up to spec with Kubernetes 1.14.

---

Compression
-----------

Release 5.1 has benefited from a heavy focus on improving the performance of
our compression-related metadata and the compression data cache.

* **Metadata Efficiency:** On systems with a heavy re-write workload, database
pages that store compression metadata could become inefficiently used, leading
to increased lookup times.  In 5.1, we have optimized the way our B+tree handles
these pages yielding a much improved fill-factor and compact metadata layout.
* **Metadata Cache:** Efficiency has improved more than 40% in release 5.1.
* **Metadata Concurrency:** For large installations where the compression
metadata exceeds the cache size, we've improved our database concurrency by
more than an order of magnitude.
* **Data Cache Sweeping:** We've taken steps to limit the impact of compression
scans on the compressed data cache.  These scans now use their own pool of cache
memory, to avoid impacting cached user data.

---

Performance
-----------

We've improved performance across the board.

* **Snapshot Remove Fairness:** Release 5.1 offers lower latency and higher
IOPS for user traffic during snapshot removal (reclaim) metadata scans,
effectively getting the system's traffic out of the way of user I/O.
* **Offloaded Message Logging:** The dataplane made strides in its low-level
latency consistency by offloading its logging of diagnostic, user, and
administrative events and statistics to another CPU core.
* **Improved Write-Combining:** Some filesystems, including XFS, intersperse
their inode metadata with user data.  This forces client access patterns that
are frequently not aligned with the Blockbridge extent size.  Release 5.1
includes special handling to re-combine this sort of write pattern to achieve
higher performance.
* **Micro-Optimizations:** Several critical I/O handling codepaths in the
dataplane have been hand-optimized to eliminate processor stalls due to
excessive branching and memory references.  And, we've markedly reduced some
nasty instances of unnecessary data sharing between CPU cores.  Translation:
lower achievable latency and more IOPS headroom.
* **Client-Side Tunings:** Release 5.1 includes enhanced support for
client-side tunings on "host attach" over a wider range of 3.x, 4.x, and 5.x
Linux kernels.
* **Adjustable TLS Compression:** You can now adjust the TLS compression level of tunneled data sessions.
* **Lower Memory Fragmentation:** We've improved our memory allocation
  techniques on the dataplane to avoid creating small, unusable sections of
  RAM.

---

Snapshot Reclaim
----------------

Some workloads with partial overwrites of data segments cause patterns of space
allocation such that some unneeded segments weren't returned to the pool when
their snapshots were removed.  In 5.1.3, we've adjusted the snapshot
reclamation algorithm to perform a deeper inspection for storage to be
released, resulting in improved efficiency.

---

Platform
--------

* **Linux Kernel 5.4.21:** We're currently shipping our own version of Linux
kernel 5.4.21, based on the Long-Term Support (LTS) stream.  We continue to
monitor kernel development for activity related to NVMe support, network
drivers, server platforms, and all block-layer bug fixes from upstream
Linux. The bare-metal and cloud images include the blockbridge kernel built-in.
Release 5.1.3 incorporates an important Kernel 5.4.21 Hotfix, adding the
upstream kernel patch 6920cef (md/raid1: properly indicate failure when ending
a failed write request).  All Blockbridge 5.x series installs should upgrade.
(Blockbridge 4.x installs are unaffected.)
* **Centos 7.9:** The latest CentOS 7.9 release is now the base for all
Blockbridge pre-built bare-metal and cloud images.
* **AMD EPYC Naples & Rome:** With the 5.0 release, we began shipping
installations specifically optimized for the AMD EPYC line of server
processors.  Release 5.1 continues this trend with optimizations to IRQ routing
on 48- and 64-core AMD systems.
* **SCSI Enclosure Stability:** Some Supermicro SCSI expanders manufactured in
2020 came with faulty firmware that would stop responding to SES enclosure
queries.  With support from our storage lab, they were able to address the
issue.  Firmware revisions from 16.16.14.00 have the fix.  Additionally,
Blockbridge platform management software gained improved resiliency against
flaky SCSI enclosures.
* **Memory Usage:** We fixed some slow-growing memory usage problems with our
platform-level services.  They weren't leaking memory, but could in some cases
grow to consume more memory than they really should have.  Release 5.1 enforces
tight constraints on these processes.
* **Diskctl Enclosure View:** Management of devices and volumes is
significantly simpler with an enclosure-centric view that's now the default in
the "diskctl" command.
* **IP Addresses Scale:** Doubled the number of supported front-facing IP
addresses for data services.
* **iSCSI Sessions Scale:** Doubled the number iSCSI sessions
  on a single target to support large multipath shared storage clusters.
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

The installation and management shell "blockbridge" got a facelift in 5.1.  It
now has much clearer, consistent organization, with better documentation.

* Add a built-in workflow for configuring an HTTP proxy.
* Do not need to stop services to remove a cluster fence.
* In "vip del", the list of VIPs is now sorted.
* On service start or stop, shell warns if maintenance mode is enabled.

---

Bugs Fixed
----------

* We fixed an extremely rare case of stuck I/O requests on volumes with IOPS
  limits enabled.
* Sending-side statistics for targets now properly count status PDUs.
* Dataplane complex IOPS gauges were sometimes observed to oscillate ~10% when
  the rates were in the 100,000 IOPS range, or higher.  This is fixed in 5.1.
* Fixed a rare case where the iSCSI target discovery reply could be empty when
  interfaces were disabled.
* Fixed instances where the datastore cache-hit statistic reported incorrect
  values under certain workloads.
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

