---
layout: page
title: Blockbridge Volume Management
description: A detailed howto for Volume Management.
permalink: /howto/volumes/index.html
keywords: volumes volume management
toc: false
---

## Introduction

Blockbridge Volume Manager builds volumes, monitors them, and repairs them autonomously using pre-defined heuristics. A volume consists of local or remote disks, assembled using properties such as failure domain, media type, fabric, and slot. The properties are attribute provisioning requirements, used to choose disks for the volume when building and repairing. Specific data protection requirements are enforced. On failure of a device in a volume, Volume Manager performs a query to find a suitable replacement using the defined replacement attributes for the volume. Once a replacement is found, the volume is repaired and brought back to a healthy state.

Volume Manager guarantees that volumes are assembled and repaired using only valid disks for each volume. This means that specific restrictions and protections are in place, ensuring out of date disks previously in the volume are rejected and not used again, either in assembly or repair of the volume. Disks selected to repair a volume are appropriately initialized and synchronized.

Volumes are managed by the **volumectl** command. In a cluster, the **volumectl** command must be executed on the active cluster member with services running.

Blockbridge Volume Manager operates by interaction with Blockbridge Disk Services. The set of disks available to Volume Manager, their properties, failure domain, and enclosure are all defined and managed by Disk Services. It is important to have an understanding of Disk Services and the specific properties associated with disks available to the system to build and manage volumes.

Please see the "Blockbridge Disk Services" guide for more information on showing and using the available disks in the system.

# Behavior

## Volume Types

The vast majority of volumes are created as RAID1 mirrors, typically with two disks. For more advanced use cases a RAID10 volume is supported with a minimum of 3 disks. All disks in a given volume must be an identical capacity.

### RAID1

RAID1 volumes are recommended for most solo installations, and most 2 or 3-node cluster installations. For ethernet-attached installations, Volume Manager automatically enforces a rule to select one disk from each failure domain (host). This ensures any one node (host) failure allows the volume to continue operation, and the data to be available in a degraded state. Any loss of a disk due to an offline host or a disk failure must be resolved as soon as possible. If multiple disks are lost permanently in a volume data loss occurs.

Once initialized, each device in a RAID1 array contains exactly the same data. Changes are written to all devices in parallel. Data is read from any one device. The volume attempts to distribute read requests across all devices to maximize performance.

### RAID10

Volume Manager RAID10 volumes operate in what is known as a RAID-1E configuration. This requires a minimum of 3 disks per volume, and only an odd number of disks are supported in a volume (3, 5, 7, etc.). However, the vast majority of RAID10 volume configurations contain 3 disks. For direct-attached SANS, it may be desired to have more than 3 disks in a volume, but this is rare. For 3 disk RAID-1E volumes, a loss of one single disk enables continued operation of the volume and availability of the data in a degraded state. The volume should be repaired as soon as possible. Any multiple disk failure (due to offline host or disk failure) will result in data being unavailable, and any permanent failure will result in data loss.

Volumes of this type assemble in a "near-2" RAID-1E layout. This means each data chunk is mirrored on the next disk in volume, and 2 copies of each chunk are written. For a typical 3 disks RAID-1E, the layout of data on-disk looks like this:

| Offset | Disk1 | Disk2 | Disk3 |
| ------ | ----- | ----- | ----- |
| 0 | A1 | A1 | B1 |
| 1 | B1 | C1 | C1 |
| 2 | A2 | A2 | B2 |
| 3 | B2 | C2 | C2

Changes are written to each of the two disks mirroring the chunk in parallel. Reads for a particular chunk are attempted to be spread across the two disks to maximize performance.

As you can see, any loss of one disk leaves one mirrored copy of each data chunk on the remaining set of disks. However, a loss of 2 disks causes data to be unavailable and the volume to no longer be viable. If a lost disk comes back (due to host coming back online, or disk functioning again), the volume is repaired.

## Automated Repairs and Timers

In the event of a disk failure, the disk is kicked out of the volume and the volume is degraded. Disk failures can be caused by offline enclosures, offline remote hosts, or actual disk media failures.

Volume Manager attempts to recover the volume from previous member disks before giving up and choosing a new disk replacement. Repair timers ensure a period of time for previous member disks to come back online and be available for optimized recovery.

*Time to Repair*: the time to repair timer defaults to 5 minutes. Within this 5 minute period, if a previous member disk that was kicked out of the array comes back online, it is re-added to the volume. Re-add is only possible if the disk's data is still intact. An optimized recovery is performed for the volume.

*Time to Replace*: once time to repair expires, Volume Manager actively searches for a new replacement disk. If a new replacement disk is available, a 1 minute timer starts. This 1 minute window is an additional grace period to allow previous member disks from the volume to come back online. After the 1 minute expires, **ALL** previous existing member disks are invalidated and optimized recovery is no longer possible. The new disk is chosen as replacement, and a full volume resynchronization occurs.

Full resynchronization is an expensive operation. Volume Manager does everything it can to recover from previous member disks before choosing new replacements. However, a disk media failure cannot be avoided in all cases, and disk replacement must be performed to ensure integrity of the volume data.

Once optimized or full recovery has been performed for the volume, the volume is no longer degraded and data is fully protected.

**NOTE**: disks are chosen for replacement using the full set of attribute provisioning requirements specified in the volume configuration.

## Repair Optimizations

All volumes support optimized repair capabilities. In the case of power outage, reboot, host failure, or repair with a disk previously a member of the volume, volume recovery is performed in an optimized way. With optimized repair, only data that was written recently is required to be synchronized in the volume. This allows for a much reduced recovery time. Without optimized recovery, the volume would not know which data had been written recently and would be required to resynchronize the entire volume. With multi-terabyte volumes, this resynchronization process is quite lengthy. During the resynchronization process volume data protections are degraded (data not fully mirrored across mirrored disks), so it is important to complete the resynchronization as quickly as possible. The builtin optimized repair capabilities provide this critical function.

No additional configuration is necessary, optimized recovery is automatically enabled for all volumes.

# Administration

## List Volumes

Display the currently configured volumes:

    volumectl ls

Display detailed status information about an individual volume or all volumes:

    volumectl info

    volumectl info <volume>

    volumectl info vol.0

## Create a Volume

A volume is created using the **volumectl** command.

In it's most essential form, a volume **NAME** and **RAID** type are required, along with the number of disks in the volume. 

Create a volume named *vol.0* in a *RAID1* mirror with *2* disks:

    volumectl create --name vol.0 --raid 1.2

No attribute provisioning arguments are specified in the default query.

For direct-attached storage configurations, two disks are selected from the locally available disks that are identical in capacity. The disks in the lowest numbered slots in the enclosure (if available) are preferred.

For ethernet-attached storage configurations, one disk from each failure domain are selected that are identical in capacity. The disks in the lowest numbered slots in the enclosure (if available) are preferred.

## Create a Volume Selection Criteria

Disk attributes and tags provided by Blockbridge Disk Services allows a volume to be constructed from specific subsets of the disks available. This allows for disks of a particular slot range, type, model, capacity, bus-type, enclosure, etc. to be selected. Attributes may be "selected" to choose disks matching the selection, or "rejected" to reject disks matching the selection.

Create a volume named *vol.1* in a *RAID1* mirror with *2* disks from slots 0-11 only:

    volumectl create --name vol.1 --raid 1.2 --select slot=0-11

Create a volume named *vol.2* in a *RAID1* mirror with *2* disks matching disk model *9300_MTFDHAL7T6TDP*:

    volumectl create --name vol.2 --raid 1.2 --select model=9300_MTFDHAL7T6TDP

**NOTE**: refer to *Blockbridge Disk Services* guide for a full description of how to determine what sets of disk attributes are available for provisioning.

## Remove a Volume

Remove a volume named *vol.3* that is no longer needed. 

    volumectl rm vol.3

**NOTE**: To remove a volume it must no longer be used. If it was previously used in a datastore, it must first be destaged and removed from the datastore.

## Device Replacement

## Manual Consistency Check

## Spare Device Management

## Rebuild Performance Policy

## Check Performance Policy

# Troubleshooting

## Description of Volume States

| Volume State | Description |
| :----------  | :--------- |
| online       | Volume is online and healthy |
| online (checking) | Volume is online; data integrity check in progress |
| online (resyncing) | Volume is online; data is synchronizing after creation, failover, or power failure |
| online (recovering) | Volume is online; data is synchronizing data to a replacement disk |
| repairing    | Volume is online but degraded; missing a disk and searching for a replacement |
| building     | Volume is offline; created and attempting to find disks and initialize disks |
| recover      | Volume is offline; attempting to start an existing volume |
| stopping     | Volume is stopping due to service move or administrator action |
| stopped      | Volume is stopped and offline, unavailable |

## Description of Volume Alerts

| Volume Alert | Description | 
| :----------- | :---------- |
| VolumeProtectionDegraded | Volume is missing a disk or performing data recovery to a replacement disk |
| VolumeRepairing | Volume is synchronizing data to a replacement disk |
| VolumeUnableToRepair | Volume is missing a disk and unable to find a replacement |
| VolumeOffline | Service Outage; volume is unable to start due to double disk failure |
| VolumeMismatchesFound | Volume data integrity check found inconsistencies between member disks |
