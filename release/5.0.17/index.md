---
layout: page
title: Blockbridge 5.0.17 Release Notes
description: What's changed in Blockbridge 5.0.17
permalink: /release/5.0.17/index.html
keywords: release 5.x 5.0 5.0.17
toc: false
---

Blockbridge Version 5.0.17 is a maintenance release with several important
bug fixes.

---

Management
----------

* **Capacity-Scaled Burst IOPS Credits:** You can now create service templates
  that scale the IOPS burst credit pool with the capacity of the provisioned
  volume.

---

Platform & Dataplane
--------------------

* **Kernel 5.4.21 Hotfix:** Incorporate upstream kernel patch 6920cef
  (md/raid1: properly indicate failure when ending a failed write request) into
  the Blockbridge 5.4.21 kernel.  All Blockbridge 5.x series installs should
  upgrade.  (Blockbridge 4.x installs are unaffected.)
* **Improved Failover and Service Move Times:** We've improved the way that the
  Heal and Disk platform services coordinate on a service move action to
  improve the time to clean shutdown.  And on startup or failover, the
  dataplane is quicker about opening and recovering volumes.  Most failovers
  should be two to four seconds quicker.

---

Snapshot Reclaim
----------------

Some workloads with partial overwrites of data segments cause patterns of space
allocation such that some unneeded segments weren't returned to the pool when
their snapshots were removed.  We've adjusted the snapshot reclamation
algorithm to perform a deeper inspection for storage to be released, resulting
in improved efficiency.

In addition, release 5.0.17 offers lower latency and higher IOPS for user
traffic during snapshot removal (reclaim) metadata scans, effectively getting
the system's traffic out of the way of user I/O.

---

Bugs Fixed
----------

* We fixed an extremely rare case of stuck I/O requests on volumes with IOPS
  limits enabled.
* Fixed a race condition triggered by SCSI logical unit reset commands that in
  rare cases could cause I/O hang to a disk.
* Fixed an unusual case where an overwrite of just-written data has to wait for
  the data journal to flush.
* The cluster now tolerates link failures while in maintenance mode.
* We closed an open internal HTTP port detected by Nessus.  All Blockbridge
  internal services require certificate validation, so there was never any
  security risk.  But there was also no reason to have the port exposed.
* During upgrade, some statistics series would sometimes show a large negative
  dip.  We've finally fixed this tricky bug.  Upgrades to 5.0.17 should see no
  interruption in statistics.
