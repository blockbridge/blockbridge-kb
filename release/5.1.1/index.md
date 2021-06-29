---
layout: page
title: Version 5.1.1 Release Notes
description: New features in Blockbridge 5.1.1.
permalink: /release/5.1.1/index.html
keywords: release 5.1.1
toc: false
---

Blockbridge Version 5.1.1 updates the widely deployed 5.x AnyScale architecture.
This release brings numerous performance and stability improvements alongside
support for Proxmox, multi-cloud Openstack deployments, and an updated
Kubernetes driver.

---

Management
--------------

Release 5.1.1 includes several improvements in management for both the
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

---

Integrations
------------

### Proxmox

Deploying Proxmox on Blockbridge just got a lot simpler.  Release 5.1.1 brings
full shared-block storage support for Proxmox with a supported plugin.  Use the
full suite of Blockbridge features:

* High Availability
* Multi-Tenancy & Multi-Proxmox
* High Performance
* At-Rest & In-Flight Encryption
* Snapshots & Clones
* Thin Provisioning & Data Reduction

### Multi-Cloud Openstack

In 5.1.1, we've expanded the types of OpenStack deployments we can support.
Prior versions of our Cinder driver were limited to one Openstack cloud per
Blockbridge controlplane.  The 5.1.1 release now includes support for multiple
OpenStack clouds and per-tenant accounts.

### Kubernetes Version 1.14

Our K8s driver version 2.0.0 is up to spec with Kubernetes 1.14.

---

Compression Metadata
--------------------

Release 5.1.1 has benefited from a heavy focus on improving the performance of
our compression-related metadata.

* **Metadata Efficiency:** On systems with a heavy re-write workload, database
pages that store compression metadata could become inefficiently used, leading
to increased lookup times.  In 5.1.1, we have improved the way our B+tree handles
these pages yielding a much improved fill-factor and compact metadata layout.
* **Metadata Cache:** Efficiency has improved more than 40% in release 5.1.1.
* **Metadata Concurrency:** For large installations where the compression
metadata exceeds the cache size, we've improved our database concurrency by
more than an order of magnitude.
* **Cache Sweeping:** We've taken steps to limit the impact of compression
scans on the metadata cache.  These scans now use their own pool of cache
memory, to avoid impacting cached user metadata.

---

Performance
-----------

We've improved performance across the board.

* **Snapshot Remove Fairness:** Release 5.1.1 offers lower latency and higher
IOPS for user traffic during snapshot removal (reclaim) metadata scans,
effectively getting the system's traffic out of the way of user I/O.
* **Offloaded Message Logging:** The dataplane made strides in its low-level
latency consistency by offloading its logging of diagnostic, user, and
administrative events and statistics to another CPU core.
* **Improved Write-Combining:** Some filesystems, including XFS, intersperse
their inode metadata with user data.  This forces client access patterns that
are frequently not aligned with the Blockbridge extent size.  Release 5.1.1
includes special handling to re-combine this sort of write pattern to achieve
higher performance.
* **Micro-Optimizations:** Several critical I/O handling codepaths in the
dataplane have been hand-optimized to eliminate processor stalls due to
excessive branching and memory references.  And, we've markedly reduced some
nasty instances of unnecessary data sharing between CPU cores.  Translation:
lower achievable latency and more IOPS headroom.
* **Client-Side Tunings:** Release 5.1.1 includes enhanced support for
client-side tunings on "host attach" over a wider range of 3.x, 4.x, and 5.x
Linux kernels.
* **Adjustable TLS Compression:** You can now adjust the TLS compression level of tunneled data sessions.

---

Platform
--------

* **Linux Kernel 5.4.21:** We're currently shipping our own version of Linux
kernel 5.4.21, based on the Long-Term Support (LTS) stream.  We continue to
monitor kernel development for activity related to NVMe support, network
drivers, server platforms, and all block-layer bug fixes from upstream
Linux. The bare-metal and cloud images include the blockbridge kernel built-in.
* **Centos 7.9:** The latest CentOS 7.9 release is now the base for all
Blockbridge pre-built bare-metal and cloud images.
* **AMD EPYC Naples & Rome:** With the 5.0 release, we began shipping
installations specifically optimized for the AMD EPYC line of server
processors.  Release 5.1.1 continues this trend with optimizations to IRQ routing
on 48- and 64-core AMD systems.
* **SCSI Enclosure Stability:** Some Supermicro SCSI expanders manufactured in
2020 came with faulty firmware that would stop responding to SES enclosure
queries.  With support from our storage lab, they were able to address the
issue.  Firmware revisions from 16.16.14.00 have the fix.  Blockbridge platform
management software gained improved resiliency against flaky SCSI enclosures.
* **Memory Usage:** We fixed some slow-growing memory usage problems with our
platform-level services.  They weren't leaking memory, but could in some cases
grow to consume more memory than they really should have.  Release 5.1.1 enforces
tight constraints on these processes.
* **Blockbridge Shell:** The installation and management shell "blockbridge"
got a facelift in 5.1.1.  It now has much clearer, consistent organization, with
better documentation.  It also includes built-in support for configuring an
HTTP proxy.
* **Diskctl Enclosure View:** Management of devices and volumes is
significantly simpler with an enclosure-centric view that's now the default in
the "diskctl" command.
* **IP Addresses Scale:** Doubled the number of supported front-facing IP
addresses for data services.
* **iSCSI Sessions Scale:** Doubled the number iSCSI sessions
  on a single target to support large multipath shared storage clusters.

---

Miscellaneous
-------------

* We fixed an extremely rare case of stuck I/O requests on volumes with IOPS
  limits enabled.
* Sending-side statistics for targets now properly count status PDUs.
* Dataplane complex IOPS gauges were sometimes observed to oscillate ~10% when
  the rates were in the 100,000 IOPS range, or higher.  This is fixed in 5.1.1.
* Fixed a rare case where the iSCSI target discovery reply could be empty when
  interfaces were disabled.



*(Note: Some of the above features were backported to later 5.0 releases as
part of our early access program.)*
