---
layout: page
title: Blockbridge Volume Management
description: A detailed howto for Volume Management.
permalink: /howto/volumes/index.html
keywords: volumes volume management
toc: false
---

## Introduction

Blockbridge Volume Manager builds, monitors, and repairs volumes autonomously using pre-configured heuristics. A volume consists of local or remote disks, assembled using properties such as failure domain, media type, fabric, and slot. The attribute provisioning requirements are used to choose disks for the volume when building and repairing. Specific data protection requirements are enforced. On failure of a disk in a volume, Volume Manager performs a query to find a suitable replacement using the defined replacement attributes for the volume. Once a replacement is found, the volume is repaired and brought back to a healthy state.

Volume Manager guarantees that volumes are assembled and repaired using only valid disks for each volume. Specific restrictions and protections are in place that ensure out of date disks previously in the volume are rejected and not used again, both for assembly and repair of the volume. Disks selected to repair a volume are appropriately initialized and data is synchronized.

Volumes are managed by the **volumectl** command. In a cluster, the **volumectl** command must be executed on the active cluster member with services running.

Blockbridge Volume Manager operates through interaction with Blockbridge Disk Services. The set of disks available to Volume Manager, their properties, failure domain, and enclosure are all defined and managed by Disk Services. It is important to have an understanding of Disk Services and the specific properties associated with disks available to the system to build and manage volumes.

# Behavior

## Volume Types

The vast majority of volumes are created as RAID1 mirrors, typically with two disks. For more advanced use cases a RAID10 volume is supported with a minimum of 3 disks. All disks in a given volume must have identical capacity.

### RAID1

Volume Manager RAID1 volumes are the recommended volume type for most installations. For ethernet-attached installations, Volume Manager automatically enforces a rule to select one disk from each failure domain (host). This ensures any single host failure allows the volume to continue operation, and the data to remain available in a degraded state. Any loss of a disk due to an offline host or a disk failure must be resolved as soon as possible. If multiple disks in a volume are lost permanently, data loss occurs.

Once initialized, each disk in a RAID1 array contains the same data. Changes are written to all disks in parallel. Data is read from any one disk. The volume attempts to distribute read requests across all disks to maximize performance.

### RAID10

For some advanced use-cases, Volume Manager RAID10 are supported. RAID10 volumes operate in what is known as a RAID-1E configuration. This requires a minimum of 3 disks per volume, and only an odd number of disks are supported in a volume (3, 5, 7, etc.). However, the vast majority of RAID10 volume configurations contain 3 disks. For direct-attached SANs, it may be desired to have more than 3 disks in a volume, but this is rare. For 3 disk RAID-1E volumes, a loss of one single disk enables continued operation of the volume and availability of the data in a degraded state. The volume should be repaired as soon as possible. Any multiple disk failure (due to offline host or disk failure) will result in data being unavailable, and any permanent failure will result in data loss.

Volumes of this type assemble in a "near-2" RAID-1E layout. This means each data chunk is mirrored on the next disk in volume, and 2 copies of each chunk are written. For a typical 3 disks RAID-1E, the layout of data on-disk looks like this:

| Offset | Disk1 | Disk2 | Disk3 |
| ------ | ----- | ----- | ----- |
| 0 | A1 | A1 | B1 |
| 1 | B1 | C1 | C1 |
| 2 | A2 | A2 | B2 |
| 3 | B2 | C2 | C2

Changes are written to each of the two disks mirroring the chunk in parallel. Reads for a particular chunk are spread across the two disks to maximize performance.

Any loss of one disk leaves one mirrored copy of each data chunk on the remaining set of disks. However, a loss of 2 disks causes data to be unavailable and the volume to no longer be viable. If a lost disk comes back (due to host coming back online, or disk functioning again), the volume is repaired.

## Automated Repairs and Timers

In the event of a disk failure, the disk is kicked out of the volume and the volume is degraded. Disk failures can be caused by offline enclosures, offline remote hosts, or actual disk media failures.

Volume Manager attempts to recover the volume from previous member disks before giving up and choosing a new disk replacement. Repair timers ensure a time for previous member disks to come back online and be available for optimized recovery.

*TimeToRepair*: the time to repair timer defaults to 5 minutes. Within these 5 minutes, if a previous member disk that was kicked out of the array comes back online, it is re-added to the volume. Re-add is only possible if the disk's data is still intact. An optimized recovery is performed for the volume.

*TimeToReplace*: once time to repair expires, Volume Manager actively searches for a new replacement disk. If a new replacement disk is available for replacement, a 1-minute timer starts. This 1-minute window is an additional grace period to allow previous member disks from the volume to come back online. After the 1-minute expires, **ALL** previous existing member disks are invalidated and optimized recovery is no longer possible. The new disk is chosen as a replacement, and a full volume resynchronization occurs.

Full resynchronization is an expensive operation. Volume Manager does everything it can to recover from previous member disks before choosing new replacements. However, a disk media failure cannot be avoided in all cases, and disk replacement must be performed to ensure the integrity of the volume data.

Once optimized or full recovery has been performed for the volume, the volume is no longer degraded and data is fully protected.

**NOTE**: disks chosen for replacement use the full set of attribute provisioning requirements specified in the volume configuration.

## Repair Optimizations

All volumes support optimized repair capabilities. In the case of power outage, reboot, host failure, or repair with a disk previously a member of the volume, volume recovery is performed in an optimized way. With optimized repair, only data that was written recently is required to be synchronized in the volume. This allows for a much-reduced recovery time. Without optimized recovery, the volume would not know which data had been written recently and would be required to resynchronize the entire volume. With multi-terabyte volumes, this resynchronization process is quite lengthy. During the resynchronization process volume data protections are degraded (data not fully mirrored across member disks), so it is important to complete the resynchronization as quickly as possible. The builtin optimized repair capabilities provide this critical function.

No additional configuration is necessary, optimized recovery is automatically enabled for all volumes.

# Administration

## List Volumes

The **volumectl** command-line utility is used to manage volumes.

Display the currently configured volumes:

    volumectl ls

Display detailed status information about an individual volume or all volumes:

    volumectl info

    volumectl info <volume>

    volumectl info vol.0

## Create a Volume

In it's most essential form, a volume **NAME** and **RAID** type are required, along with the number of disks in the volume.

Create a volume named *vol.0* in a *RAID1* mirror with *2* disks:

    volumectl create --name vol.0 --raid 1.2

The **NAME** parameter specified must be unique for each volume.

The **RAID** parameter is specified as *<raid-level>*.*<number-of-disks>*

No attribute provisioning arguments are specified in the default query.

For direct-attached storage configurations, two disks are selected from the locally available disks with an identical capacity. The disks in the lowest numbered slots in the enclosure (if available) are preferred.

For ethernet-attached storage configurations, one disk from each failure domain is selected with an identical capacity. The disks in the lowest numbered slots in the enclosure (if available) are preferred.

**NOTE**: the most common volume type is a "raid 1.2"

## Create a Volume Selection Criteria

Disk attributes and tags provided by Blockbridge Disk Services allows a volume to be constructed from specific subsets of the disks available. This allows for disks of a particular slot range, type, model, capacity, bus-type, enclosure, etc. to be selected. Attributes may be "selected" to choose disks matching the selection, or "rejected" to reject disks matching the selection.

Create a volume named *vol.1* in a *RAID1* mirror with *2* disks, choosing disks of matching capacity from slots 0-11 only:

    volumectl create --name vol.1 --raid 1.2 --select slot=0-11

Create a volume named *vol.2* in a *RAID1* mirror with *2* disks, choosing disks of matching capacity with model *9300_MTFDHAL7T6TDP* only:

    volumectl create --name vol.2 --raid 1.2 --select model=9300_MTFDHAL7T6TDP

## Remove a Volume

Remove a volume named *vol.3* that is no longer needed.

    volumectl rm vol.3

**NOTE**: To remove a volume it must no longer be in-use. If it is used in a datastore, it must first be destaged and removed from the datastore.

## Disk Replacement

Blockbridge Volume Manager works to ensure volumes are healthy and data is replicated according to policy at all times. Inevitably, when a disk failure occurs, Volume Manager monitors the health of the volume, removes the failed disk, and repairs the volume by choosing a suitable replacement. Volume Manager does everything possible to prefer replacement with a valid disk that was a previous member of the volume. This allows for an optimized data recovery procedure, in the case of offline disks coming back and temporary network failures. However, after a timeout period, data integrity of the volume must be maintained, and a new replacement disk must be selected.

Volume Manager searches for a new replacement disk using the selection criteria configured for the volume. A disk is selected that matches the capacity of other disks in the volume. Failure domain policies, selection criteria, and reject criteria are used to determine the subset of valid replacement disks to choose from. A matching disk is chosen and added to the volume. Volume recovery is performed to synchronize data to the new member disk.

If no valid replacement disk is available, Volume Manager continues to search for one until one is found.

In the case of disk media failure, it is recommended to remove the failed media from its slot as soon as possible, and replace it with a new disk of equal capacity in the same slot. Volume Manager will recognize the new disk, and choose it as a replacement to recover the volume.

## Manual Consistency Check

Volumes are checked for data integrity periodically according to the check schedule. By default, a volume check is performed every 30 days, during off-hours. However, it is sometimes desired to run a manual check. You may want to run a manual check soon after volume create to ensure the volume was initialized properly, or after a disk was added and volume was repaired. While these manual checks are not necessary, they can bring peace of mind and provide an early extra check on the data integrity of the volume. Particularly, if a volume was created with "assume clean" and disks were zeroed out of band, a manual check ensures that the out of band process was performed by an administrator correctly. This out of band volume initialization is useful to skip a lengthy volume resynchronization during volume create, when disk-level secure erase operations ensure data is zeroed.

View the automatic check schedule:

    volumectl check schedule

To perform a manual check on *vol.0*, use the **volumectl** command to start:

    volumectl check start vol.0

Check progress for the volume is shown in the volume listing:

    volumectl ls

## Spare Disk Management

In any storage system, disk media failure is inevitable. To prepare for disk media failure, and ensure no loss of data protection, configure spare disks in the available enclosures. A spare disk is one that is currently unused in any volume, but matches the disk selection criteria for a volume, and is suitable for immediate replacement. A spare disk allows for Volume Manager to repair and recover a volume due to disk media failure, and allows an administrator to replace the failed media urgently, but not as a critical emergency.

It is recommended that one spare disk be available for every volume configured. This 1-1 ratio of spare disk to volume ensures protection against disk media failure but gives an administrator time to perform disk replacement in the enclosure. However, as the ideal ratio may not always be possible depending on the number of volumes configured and the number of slots available in the enclosure, a plan to have at least one shared spare available across the volumes should be considered. With no spares, any single disk failure requires an immediate disk replacement action to ensure data protection is not degraded.

## Rebuild Performance Policy

The Rebuild Performance Policy dictates per-volume bandwidth limits and the number of volumes simultaneously allowed to perform data repair and recovery operations. These limits apply to new volumes that are performing synchronization after create, and to volumes that are performing recovery to replacement disks. It is recommended to set the rebuild concurrency to the number of volumes configured, and the per-volume bandwidth limit to one about 25% of the disk bandwidth capabilities. For a typical volume composed of NVMe disk media, setting per-volume bandwidth to 1GiB is acceptable.

Show the current limits:

    volumectl rebuild show

Set per-volume rebuild bandwidth limit:

    volumectl rebuild --bw-limit 1GiB

Set rebuild volume concurrency:

    volumectl rebuild --volcount 5

## Check Performance Policy

The Check Performance Policy sets the per-volume bandwidth and volume concurrency for data consistency check operations. These limits apply to both automatic scheduled check operations and manual consistency check operations. The policy also dictates the number of days between automatic scheduled checks.

It is recommended that each volume is checked for data consistency at least once every 30 days. The default bandwidth of 50MiB per-volume and a volume check concurrency of 2 should be sufficient. View the workload estimate to ensure that the bandwidth and volume concurrency settings complete all volume checks within the desired interval.

View or modify the check schedule. **NOTE** times shown are in system local time.

    volumectl check schedule

Set per-volume check bandwidth limit:

    volumectl check --bw-limit 50MiB

Set check volume concurrency:

    volumectl rebuild --volcount 2

Set the desired interval (days) between volume checks:

    volumectl rebuild --interval 30

Ensure workload estimate falls within the desired interval:

    volumectl check show

    == Workload
    Total capacity        839.167GiB
    Estimated runtime     1 day

# Troubleshooting

## Description of Volume States

| Volume State | Description |
| :----------  | :--------- |
| online              | Volume is online and healthy |
| online (checking)   | Volume is online; data integrity check in progress |
| online (resyncing)  | Volume is online; data is synchronizing after creation, failover, or power failure |
| online (recovering) | Volume is online; data is synchronizing data to a replacement disk |
| repairing           | Volume is online but degraded; missing a disk and searching for a replacement |
| building            | Volume is offline; created and attempting to find disks and initialize disks |
| recover             | Volume is offline; attempting to start an existing volume |
| stopping            | Volume is stopping due to service move or administrator action |
| stopped             | Volume is stopped and offline, unavailable |

## Description of Volume Alerts

| Volume Alert | Description |
| :----------- | :---------- |
| VolumeProtectionDegraded | Volume is missing a disk or performing data recovery to a replacement disk |
| VolumeRepairing          | Volume is synchronizing data to a replacement disk |
| VolumeUnableToRepair     | Volume is missing a disk and unable to find a replacement |
| VolumeOffline            | Service Outage; volume is unable to start due to double disk failure |
| VolumeMismatchesFound    | Volume data integrity check found inconsistencies between member disks |

# See Also

For a complete guide on using the volumectl command see the [volumectl manual](/manual/volumectl)
