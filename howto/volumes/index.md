---
layout: page
title: Volume Management
description: A detailed howto for Blockbridge Volume Management.
permalink: /howto/volumes/index.html
keywords: volumes volume management
toc: false
---

## Introduction

The **Blockbridge Volume Manager** implements device-level redundancy for data
protection and resiliency in the event of component failure. The Volume Manager
assembles, monitors, and repairs volumes autonomously using pre-defined system
policies and optional user-specified policies.

Use the **volumectl** command for administration.
```
   # volumectl --help
   Usage:
       volumectl [OPTIONS] [SUBCOMMAND] [ARG] ...

   Parameters:
       [SUBCOMMAND]                  subcommand (default: "list")
       [ARG] ...                     subcommand arguments

   Subcommands:
       create                        create a new volume
       start                         start a volume
       stop                          stop a volume
       remove, rm, delete            delete a volume
       info                          retrieve information about a volume
       list, ls                      retrieve information about all volumes
       update                        update parameters of a volume
       shutdown_all                  gracefully shutdown all volumes
       disk_fail                     fail disk in volume
       check                         consistency check settings/status
       rebuild                       consistency rebuild settings
       repair                        volume repair
       config                        configuration settings

   Options:
       -h, --help                    print help
```

{% include tip.html content="In a highly availability cluster, the
**volumectl** command must be executed on the active cluster member." %}

# Behavior

## Device Selection ##

A **Volume** consists of devices distributed across failure domains such that the
failure of any component in the system affects at most a single disk in a
volume. The Volume Manager enforces data distribution policies based on
hardware capabilities and configuration:

* Systems that consist of **single-port SATA or single-port NVMe devices**
  connected by high-speed ethernet have enclosure-scoped failure
  domains. Devices within a single volume must be distributed across
  independent enclosures.

* Systems that leverage **dual-port SAS or dual-port NVMe devices** and that
  implement path-level redundancy to devices within an enclosure have
  device-scoped failure domains. Disks within a single volume may optionally
  reside in the same enclosure.

## Volume Types

### Mirrored Volumes

A **Mirrored Volume** (i.e., RAID1) synchronously replicates data uniformly
across devices. The contents of the devices are identical. The following table
illustrates the distribution of data for a volume with 3 disks:

| Offset | Disk1 | Disk2 | Disk3 |
|:------:|:-----:|:-----:|:-----:|
| 0 | A1 | A1 | A1 |
| 1 | B1 | B1 | B1 |
| 2 | C1 | C1 | C1 |
| 3 | D1 | D1 | D1

Writes execute in parallel and are acknowledged after completion on all
devices. Read requests are actively balanced across disks to distribute the
load. Permanent data loss occurs after the failure of all devices in a
volume. The use of devices with volatile write caches is unsupported and may
result in data loss in the event of unexpected power loss.

### Striped Mirrored Volumes

A **Striped Mirrored Volume** (i.e., RAID1E) synchronously replicates chunks of
data across devices. Mirrored chunks of data are uniformly distributed across
devices. An odd number of devices greater than or equal to 3 disks per volume
is required. The specific data layout for striped mirrored volumes is
"near-2". The following table illustrates the distribution of data for a volume
with 3 disks:

| Offset | Disk1 | Disk2 | Disk3 |
|:------:|:-----:|:-----:|:-----:|
| 0 | A1 | A1 | B1 |
| 1 | B1 | C1 | C1 |
| 2 | A2 | A2 | B2 |
| 3 | B2 | C2 | C2

Writes execute in parallel and are acknowledged after completion on all devices
where a chunk resides. Read requests are actively balanced across disks to
distribute the load. Permanent data loss occurs after the failure of N-1 of the
devices, where N is the number of mirrors. The use of devices with volatile
write caches is unsupported and may result in data loss in the event of
unexpected power loss.

## Repair Optimizations

Volumes are configured for optimized repair and difference based
synchronization by default, to minimize recovery time and maximize resiliency
and availability. The system actively tracks data regions that require
synchronization in the event of unexpected power outages, reboot, and
failover. The Volume Manager automatically coordinates optimized repair without
additional configuration or management.

## Autonomous Repair

Volumes provide continued operation in the event of device
failure. Causes of device failure may include power loss, controller
malfunction, network failure, enclosure failure, and defective media.

Many failure scenarios are transient and recoverable. The Volume
Manager uses timer-based heuristics to minimize the duration of
degraded redundancy.  The Volume Manager prefers to synchronize
differences between devices over executing full device synchronization.

If a permanent device failure occurs, the Volume Manager automatically
repairs volumes based on the availability of eligible replacement
devices (i.e., spares). Replacement device eligibility may be
constrained by per-volume policy, if specified.

The following controls determine the precise timing of recovery
actions taken by the Volume Manager:

* **TimeToRepair** is the duration of time that the Volume Manager waits
before searching for a replacement device. If the cause of device
failure resolves within *TimeToRepair* and the device data appears
intact, it may be re-added to the volume for optimized recovery. The
default value of *TimeToRepair* is 5 minutes.

* Upon the expiration of *TimeToRepair*, the volume manager begins
searching for a replacement device. When a replacement device becomes
available, the Volume Manager waits **TimeToReplace** before
initiating replacement. If the cause of device failure resolves within
*TimeToReplace* and the device data appears intact, it may be re-added
to the volume for optimized recovery. Otherwise, the device is
invalidated, and replacement occurs immediately along with full device
synchronization.

{% include tip.html content="*TimeToReplace* allows for optimized recovery from
infrastructure failures that uniformly affect the accessibility of volume members
and available replacements." %}

# Administration

## List Volumes

### Display the currently configured volumes

    volumectl ls

    Name [1]         State    Capacity   Level  Chunk size  Disks  Device
    ---------------  -------  ---------  -----  ----------  -----  -----------------------
    vol.1            online   949.963GB  raid1  N/A         2/2    /dev/md/vol.1
    vol.2            online   949.963GB  raid1  N/A         2/2    /dev/md/vol.2

### Display detailed information for a single volume

    volumectl info <volume>

    volumectl info vol.1

    == Volume: vol.1
    uuid                  7e3959f0-00be-4801-854a-6c9eb8d7ccc5
    capacity              884.722GiB
    created               2020-03-30T18:46:44+00:00
    modified              2020-03-30T18:46:48+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/vol.1   (md124)
    container             /dev/md/vol.1:c (md125)
    state                 online
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    e9e956f6-506a-4394-a879-04ef16f10923  /dev/sdf        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    257169ee-d4ad-40c5-a739-7c6e2631f54e  /dev/nvme2n3    949.999GB  9300_MTFDHAL7T6TDP  active in-sync

### Display detailed information for all volumes

    volumectl info

    == Volume: vol.1
    uuid                  7e3959f0-00be-4801-854a-6c9eb8d7ccc5
    capacity              884.722GiB
    created               2020-03-30T18:46:44+00:00
    modified              2020-03-30T18:46:48+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/vol.1   (md124)
    container             /dev/md/vol.1:c (md125)
    state                 online
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    e9e956f6-506a-4394-a879-04ef16f10923  /dev/sdf        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    257169ee-d4ad-40c5-a739-7c6e2631f54e  /dev/nvme2n3    949.999GB  9300_MTFDHAL7T6TDP  active in-sync

    == Volume: vol.2
    uuid                  2df09591-0cf7-4269-930d-fb6bc84e6872
    capacity              884.722GiB
    created               2020-03-30T18:46:53+00:00
    modified              2020-03-30T18:46:56+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/vol.2   (md122)
    container             /dev/md/vol.2:c (md123)
    state                 online
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    e80881ae-be73-4ede-b5c1-d44685815b59  /dev/sdg        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    b7877ba2-1dde-49d6-95c7-c66ad2b39f4e  /dev/nvme2n4    949.999GB  9300_MTFDHAL7T6TDP  active in-sync

## Create a Volume

Blockbridge configuration specifies default device selection rules
that match the availability requirements of the underlying storage
architecture. In some cases, a more sophisticated provisioning
workflow is required for:

* device segregation in multi-complex dataplanes
* increased data redundancy
* bandwidth aggregation for journal devices
* placement constraints for disaggregated infrastructures

### Create a volume using system defaults

The default volume is a 2 disk mirror. Disks are automatically
selected from independent failure domains or a single failure domain
that is internally resilient.

    volumectl create --name <volume>

    volumectl create --name my.vol

    == Volume: my.vol
    uuid                  ce66ef84-61d4-49c1-b52b-c1332d30be8e
    capacity              884.722GiB
    created               2020-03-30T18:51:50+00:00
    modified              2020-03-30T18:51:53+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/my.vol   (md120)
    container             /dev/md/my.vol:c (md121)
    state                 online (resyncing, 0%)
    status                volume is resyncing after creation or unclean shutdown
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    f3047efc-76eb-4d56-96c0-57d6df5066f6  /dev/sdc        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    4168eda4-81db-4641-8c8e-abd53e067ed5  /dev/nvme2n2p1  949.999GB  9300_MTFDHAL7T6TDP  active in-sync

{% include warning.html content="It is not possible to rename a volume
after creation. Consider future requirements for re-organization when
choosing a naming scheme." %}

### Create a volume specifying device selection constraints

Command argument syntax

    volumectl create --name <volume> --select <query>

Example using a device slot select constaint

    volumectl create --name my.vol --select slot=0-10

    == Volume: my.vol
    uuid                  ce66ef84-61d4-49c1-b52b-c1332d30be8e
    capacity              884.722GiB
    created               2020-03-30T18:51:50+00:00
    modified              2020-03-30T18:51:53+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/my.vol   (md120)
    container             /dev/md/my.vol:c (md121)
    state                 online (resyncing, 0%)
    status                volume is resyncing after creation or unclean shutdown
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    select                slot=0-10
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    f3047efc-76eb-4d56-96c0-57d6df5066f6  /dev/sdc        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    4168eda4-81db-4641-8c8e-abd53e067ed5  /dev/nvme2n2    949.999GB  9300_MTFDHAL7T6TDP  active in-sync

Example using a device model number select constaint

    volumectl create --name my.vol --select model=9300_MTFDHAL7T6TDP

    == Volume: my.vol
    uuid                  ce66ef84-61d4-49c1-b52b-c1332d30be8e
    capacity              884.722GiB
    created               2020-03-30T18:51:50+00:00
    modified              2020-03-30T18:51:53+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/my.vol   (md120)
    container             /dev/md/my.vol:c (md121)
    state                 online (resyncing, 0%)
    status                volume is resyncing after creation or unclean shutdown
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    select                model=9300_MTFDHAL7T6TDP
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    f3047efc-76eb-4d56-96c0-57d6df5066f6  /dev/sdc        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    4168eda4-81db-4641-8c8e-abd53e067ed5  /dev/nvme2n2    949.999GB  9300_MTFDHAL7T6TDP  active in-sync
                                           
Example using a device bus reject constaint

    volumectl create --name my.vol --reject bus=sata

    == Volume: my.vol
    uuid                  ce66ef84-61d4-49c1-b52b-c1332d30be8e
    capacity              884.722GiB
    created               2020-03-30T18:51:50+00:00
    modified              2020-03-30T18:51:53+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/my.vol   (md120)
    container             /dev/md/my.vol:c (md121)
    state                 online (resyncing, 0%)
    status                volume is resyncing after creation or unclean shutdown
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    reject                bus=sata
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    f3047efc-76eb-4d56-96c0-57d6df5066f6  /dev/sdc        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    4168eda4-81db-4641-8c8e-abd53e067ed5  /dev/nvme2n2    949.999GB  9300_MTFDHAL7T6TDP  active in-sync

Example using multiple constraints

    volumectl create --name my.vol --select bus=nvme --select model=9300_MTFDHAL7T6TDP --reject slot=0

    == Volume: my.vol
    uuid                  ce66ef84-61d4-49c1-b52b-c1332d30be8e
    capacity              884.722GiB
    created               2020-03-30T18:51:50+00:00
    modified              2020-03-30T18:51:53+00:00
    raid level            raid1
    raid disks            2
    active disks          2
    device                /dev/md/my.vol   (md120)
    container             /dev/md/my.vol:c (md121)
    state                 online (resyncing, 0%)
    status                volume is resyncing after creation or unclean shutdown
    
    == MD parameters
    chunk size            N/A
    
    == Disk Query Attributes
    select                bus=nvme, model=9300_MTFDHAL7T6TDP
    reject                slot=0
    unique                agent_id
    
    == Disks in Volume
    ID                                    Devname         Raw Size   Model               State [1]
    ------------------------------------  --------------  ---------  ------------------  --------------
    f3047efc-76eb-4d56-96c0-57d6df5066f6  /dev/sdc        949.999GB  9300_MTFDHAL7T6TDP  active in-sync
    4168eda4-81db-4641-8c8e-abd53e067ed5  /dev/nvme2n2    949.999GB  9300_MTFDHAL7T6TDP  active in-sync

{% include warning.html content="Selection criteria constraints affect
the eligible devices for both creation and replacement. The constraint
can be modified at any time." %}

{% include tip.html content="The disk service discovers and catalogs
the attributes that are available for use in selection
constraints. Use the `diskctl` command to manage custom attributes and
rules for applying custom attributes." %}

### Create a volume with a custom data protection mode
The **RAID** parameter is specified as *\<raid-level>*.*\<number-of-disks>*

Command argument syntax

    volumectl create --name <volume> --raid <level>.<disks>

Example specifying a 3 disk mirror

    volumectl create --name my.vol --raid 1.3

Example specifying a 3 disk striped mirror (i.e., RAID1E)

    volumectl create --name my.vol --raid 10.3

## Remove a Volume

{% include warning.html content="A volume cannot be removed if it is
in use. Destage the volume from the corresponding datastore before
removal." %}

Command argument syntax

    volumectl rm <volume>...

Example removing a volume

    volumectl rm my.vol

## Manual Consistency Check

Volumes are automatically checked for data consistency and media
defects according to the check schedule. You may optionally run a
manual check for an immediate assurance that a volume was correctly
initialized or repaired.

{% include tip.html content="If you create a volume with
`--assume-clean`, we recommend that you run a manual check before the
volume enters production to ensure that devices are consistent." %}

### View progress on active consistency checks

    volumectl ls

    Name [1]         State                   Capacity   Level  Chunk size  Disks  Device
    ---------------  ----------------------  ---------  -----  ----------  -----  -----------------------
    vol.1            online (checking, 27%)  949.963GB  raid1  N/A         2/2    /dev/md/vol.1
    vol.2            online (checking, 12%)  949.963GB  raid1  N/A         2/2    /dev/md/vol.2

### View the consistency check schedule

    volumectl check schedule

    # healctl check
    == History
    Name [1]         Last Checked               When         Mismatches
    ---------------  -------------------------  -----------  ----------
    vol.1            2020-03-30 19:18:43 +0000  Today        0
    vol.2            2020-03-30 19:21:14 +0000  Today        0
    
    == Schedule
    Index  Day of Week  Start  End
    -----  -----------  -----  -----
    0      Monday       01:00  05:00
    1      Tuesday      01:00  05:00
    2      Wednesday    01:00  05:00
    3      Thursday     01:00  05:00
    4      Friday       01:00  05:00
    5      Saturday     01:00  05:00
    6      Sunday       01:00  05:00
    
    == Settings
    Volume bandwidth limit  1.0GiB
    Volume concurrency      2
    Check interval          Every 30 days
    
    == Workload
    Total capacity        3.4559TiB
    Estimated runtime     1 day

### Start a manual consistency check

    volumectl check start vol.1

### Interaction with Automated Checking

Does a successful manual check count as a successful automatic check
from a scheduling perspective?

* Yes.

What happens if a manual check is requested while an automatic check
is running?

* If the request for a manual check specifies a volume that is
  currently running an automated check, the automated check continues.
* If the request for a manual check specifies a volume that is
  currently idle, the manual check will supersede a currently running
  check.

## Consistency Check Performance Policy

The Consistency Check Performance Policy defines the per-volume
bandwidth, concurrency constraints, and frequency of consistency check
operations. The performance aspects of the policy apply to both
scheduled and manual check operations.

We recommend that each volume is checked for consistency at least once
every 30 days. Use the workload estimate to ensure that the bandwidth
and volume concurrency settings are sufficient to ensure that all
volumes are checked with appropriate frequency.

{% include tip.html content="The times shown in the check scheduler
are in system local time." %}

### View the check schedule

    volumectl check schedule

    == Schedule
    Index  Day of Week  Start  End
    -----  -----------  -----  -----
    0      Monday       01:00  05:00
    1      Tuesday      01:00  05:00
    2      Wednesday    01:00  05:00
    3      Thursday     01:00  05:00
    4      Friday       01:00  05:00
    5      Saturday     01:00  05:00
    6      Sunday       01:00  05:00

### Set the per-volume check bandwidth limit

    volumectl check --bw-limit 50MiB

    == Settings
    Volume bandwidth limit  50.0MiB
    Volume concurrency      2
    Check interval          Every 30 days

### Set the check volume concurrency

    volumectl check --volcount 2

    == Settings
    Volume bandwidth limit  50.0MiB
    Volume concurrency      2
    Check interval          Every 30 days

### Set the desired interval (days) between volume checks

    volumectl check --interval 30

    == Settings
    Volume bandwidth limit  50.0MiB
    Volume concurrency      2
    Check interval          Every 30 days

### Validate the workload estimate complies with desired interval

    volumectl check show

    == Workload
    Total capacity        839.167GiB
    Estimated runtime     1 day

## Rebuild Performance Policy

The Rebuild Performance Policy specifies the per-volume bandwidth
limits and concurrency of recovery, repair, and synchronization
operations.

We recommend that you set rebuild concurrency and per-volume bandwidth
based on the speed of your backend interconnect and the sequential
write bandwidth capabilities of your devices. Per-device bandwidth
should not exceed 50% of the maximum sequential write bandwidth of a
device. Aggregate bandwidth should not exceed 50% of the backend
interconnect bandwidth. The following table provides a general
recommendation:

| Device Type | Per-Device BW | Concurrency | Total Rebuild BW
|:------:|:-----:|:-----:|:-----:|:-----:|
| NVMe | 800 | 4 | 3200
| SAS  | 400 | 4 | 1600
| SATA | 200 | 4 | 800

### Show the current rebuild performance policy
    volumectl rebuild show

    == Volume Rebuild Settings
    Volume bandwidth limit  1.0GiB
    Rebuild concurrency     2

### Set the per-volume rebuild bandwidth limit
    volumectl rebuild --bw-limit 1GiB

    == Volume Rebuild Settings
    Volume bandwidth limit  1.0GiB
    Rebuild concurrency     2

### Set the rebuild volume concurrency
    volumectl rebuild --volcount 5

    == Volume Rebuild Settings
    Volume bandwidth limit  1.0GiB
    Rebuild concurrency     5

## Spare Disk Management

The Volume Manager works to ensure that volumes are online and healthy
at all times. When a permanent device failure occurs, the Volume
Manager attempts to repair the volume using an available replacement
device (i.e., spare).

The Volume Manager searches for a replacement disk using the selection
criteria set in volume configuration. It is essential to know that the
selection criteria affect the eligibility of replacement devices.

**Successful automatic replacement occurs when:**
* A volume must is `degraded`, but `online`.
* An unused device is available that matches the volume's device selection criteria.
* The unused device has the exact capacity of the failed device.

If a replacement device is unavailable, the Volume Manager asserts the
`VolumeUnableToRepair` alert and continues to search indefinitely.

{% include tip.html content="We recommend that you deploy a single
unused device per enclosure. If you have mixed capacity devices, you
should configure a spare for each capacity." %}

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

## Manual: volumectl

For a complete guide on using the volumectl command see the [volumectl manual](/manual/volumectl)
