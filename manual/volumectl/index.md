---
layout: page
title: 'manual: volumectl'
description: volumectl manual
permalink: /manual/volumectl/index.html
keywords: volumectl volume volumes
toc: true
---

## Summary

The Blockbridge Volume Manager builds software RAID array volumes, monitors them, and repairs them autonomously. Using properties such as failure domain, media type, fabric, and slot, the volume manager assembles volumes by querying the available devices and building a volume with the specified data protection requirements.

On failure of a device in a volume, the Volume Manager again queries available devices, chooses an appropriate replacement, and repairs the volume back to a healthy state.

## Synopsis

$ volumectl

$ volumectl ls

$ volumectl create --name *\<volume>* --raid *\<raid-level>.\<raid-disks>*
        
$ volumectl info *\<volume>*

$ volumectl rm *\<volume>*

$ volumectl check
    
## volumectl

User interaction with the volume manager is done through the **volumectl** command-line utility. Using **volumectl**, a user can create a volume, list existing volumes, get detailed information about an existing volume, stop or remove a volume, and perform specific volume actions.

## CREATE A VOLUME

### Command

*volumectl create*

### Required Parameters

**--name** *\<volume>*

The unique name for the volume.

**--raid** *\<raid-level>.\<raid-disks>[.replication-factor]*

Specify the RAID level, the number of disks in the volume, and (optional) replication factor.

RAID levels 1, 1E, and 10 are supported. The number of disks must be a minimum of 2 for RAID1, 3 for RAID1E,  and 3 for RAID10. RAID10 requires an odd number of disks. By default, for those RAID levels where it makes sense, the replication factor is equal to the number of disks. The default replication factor is good for most volumes. If a different replication factor is desired (for example, a RAID10 with 4 disks and a near-layout replication factor of 2), specify the additional replication factor parameter.

### Attribute Provisioning Options

**--select** *\<attributes>*

From the set of disks specified in **--from** (or all disks, if no **--from** specified), select only those disks that match the given attributes. This is a logical AND operation. Like **--from**, **--select** applies to disks selected for volume creation as well as those selected for repair.

*\<attributes>* is specified as a **key=val** pair, e.g.: **bus=scsi**

**--reject** *\<attributes>*

From the set of disks specified in **--from** (or all disks, if no **--from** specified), reject those disks that match the given attributes.

*\<attributes>* is specified as a **key=val** pair, e.g.: **bus=scsi**

**--from** *\<attributes>*

Create and repair volume using only disks with the following attributes. May be specified multiple times to incorporate more disks with different sets of attributes. This is a logical OR operation.

*\<attributes>* is specified as a **key=val** pair, e.g.: **bus=scsi**

**--unique** *\<attribute>*

Require disks in the volume to be unique across the specified attribute. If a volume is desired to be built across failure domains, or across a particular disk attribute, the **--unique** option can be used to ensure unique disk selection. Perhaps a volume is desired to always use one disk from each enclosure or bus or vendor in the system.

*\<attribute>* is specified as a **key** value of an attribute, e.g.: **agent_id**

**NOTE:** To ensure disks are selected from unique disk services in an ethernet-attached installation, specify **--unique agent_id**.

### Array Options

**--chunk-size** *\<bytes>*

The volume chunk size. The *chunk* is the size unit of which data is replicated between drives. The chunk size can impact performance of the volume. It is only valid for RAID10.

**--bitmap** *(default: true)*

Specifying the **--bitmap** option creates an external bitmap regardless of volume size, and can also improve performance by placing the bitmap on a fast class of drive. The bitmap is used for optimized volume recovery when adding back a previous member disk of a volume. Bitmaps are created by default.

**--bitmap-chunk** *\<bytes>*

Specify bitmap chunk size. Specifies the size that one bit represents in
the write-intent bitmap. This impacts the size of bitmap required to represent
data in the volume, and also impacts the amount of data that needs to be
re-synchronized in case of failure. Larger chunk size means smaller bitmap.
But larger chunk size means potential more data transfer for re-synchronize.

**--assume-clean** *\<true/false>* *(default: false)*

When creating a volume, assume that all drives are zeroed/clean. By assuming clean, no synchronize operation is required when the volume is first created.  For large arrays, this can save substantial time and data transfer. However, assume clean is not recommended as array "check" operations will show array inconsistencies because all drive data has not been initialized. The default is to disable assume clean (ie: drives will be initialized). Specify this option to change the default.

NOTE: If performing a volume check on the array, the 'mismatch_cnt' may be non-zero for volumes created with **--assume-clean**. This does not mean that there is an error
in this case.

### Examples

Create a RAID10 volume with 5 disks

    $ volumectl create --name raid10a.vol --raid 10.5
    == Volume: raid10a.vol
    uuid                  9168f398-3e64-4166-a08e-137a19edb2ff
    capacity              1.0913TiB                           
    created               2016-10-05T14:58:30-04:00           
    modified              2016-10-05T14:58:30-04:00           
    raid level            raid10                              
    raid disks            5                                   
    device                /dev/md/raid10a.vol                  
    state                 online                              
        
    == MD parameters
    chunk size            512.0KiB
        
    == Disks in Volume
    ID [3]                Devname  Enclosure [1]       Slot [2]  Raw Size   Model     
    --------------------  -------  ------------------  --------  ---------  ----------
    ZBC090DC0000822150Z3  sdd      0x500304801ec1553f  0         400.088GB  S630DC-400
    ZBC090CG0000822150Z3  sdf      0x500304801ec1553f  1         400.088GB  S630DC-400
    ZBC090FY0000822150Z3  sde      0x500304801ec1553f  2         400.088GB  S630DC-400
    ZBC090FR0000822150Z3  sdg      0x500304801ec1553f  3         400.088GB  S630DC-400
    ZBC090FM0000822150Z3  sdh      0x500304801ec1553f  4         400.088GB  S630DC-400

Create a RAID10 volume with 5 disks of a specific model number

    $ volumectl create --name raid10b.vol --raid 10.5 --select model=S630DC-400
    == Volume: raid10b.vol
    uuid                  c99edbae-4239-4731-ab24-9cb0ae712989
    capacity              1.0913TiB                           
    created               2016-10-05T14:59:12-04:00           
    modified              2016-10-05T14:59:12-04:00           
    raid level            raid10b                               
    raid disks            5                                   
    device                /dev/md/raid10b.vol                   
    state                 online                              
    
    == MD parameters
    chunk size            512.0KiB
    
    == Disk Attribute Requirements
    select                model=S630DC-400
    
    == Disks in Volume
    ID [3]                Devname  Enclosure [1]       Slot [2]  Raw Size   Model     
    --------------------  -------  ------------------  --------  ---------  ----------
    ZBC090030000822150Z3  sdj      0x500304801ec1553f  6         400.088GB  S630DC-400
    ZBC090GY0000822150Z3  sdk      0x500304801ec1553f  7         400.088GB  S630DC-400
    ZBC090GG0000822150Z3  sdl      0x500304801ec1553f  8         400.088GB  S630DC-400
    ZBC090FZ0000822150Z3  sdm      0x500304801ec1553f  9         400.088GB  S630DC-400
    ZBC090CH0000822150Z3  sdn      0x500304801ec1553f  10        400.088GB  S630DC-400

## LIST VOLUMES

### Command

*volumectl*

*volumectl ls*

*volumectl list*

Display a summary of currently configured volumes.

### Examples

Display volume summary

    $ volumectl ls
    Name [1]    State   Capacity  Level   Chunk size  Disks  Device            
    ----------  ------  --------  ------  ----------  -----  ------------------
    raid1.vol   online  31.983GB  raid1   N/A         3      /dev/md/raid1.vol 
    raid10a.vol online  1.1999TB  raid10  512.0KiB    5      /dev/md/raid10a.vol 
    raid10b.vol online  1.1999TB  raid10  512.0KiB    5      /dev/md/raid10b.vol

## SHOW VOLUME INFORMATION

### Command

*volumectl info*

*volumectl info \<volume>*

Display detailed volume information about currently configured volumes, or the volume name specified.

## START A VOLUME

### Command

*volumectl start \<volume>*

Start an existing volume that is in the **stopped** state.

## STOP A VOLUME

### Command

*volumectl stop \<volume>*

Stop an existing volume that is currently running.

**NOTE:** if a volume is *in-use*, it will not be able to stop. This could mean the dataplane currently has the volume open. If you need to stop a volume that is being used by the dataplane, the dataplane services must first be stopped.

## REMOVE A VOLUME

### Command

*volumectl rm \<volume>*

Remove an existing volume.

**NOTE:** This is a **destructive** operation. All data on the volume will be lost. Make sure your data is backed up, or no longer needed.

## UPDATE VOLUME'S ATTRIBUTE PROVISIONING OPTIONS

### Command

*volumectl update \<volume>*

### Attribute Provisioning Options

**--select** *\<attributes>*

From the set of disks specified in **--from** (or all disks, if no **--from** specified), select only those disks that match the given attributes. This is a logical AND operation.

*\<attributes>* is specified as a **key=val** pair, e.g.: **bus=scsi**

**--reject** *\<attributes>*

From the set of disks specified in **--from** (or all disks, if no **--from** specified), reject those disks that match the given attributes.

*\<attributes>* is specified as a **key=val** pair, e.g.: **bus=scsi**

**--from** *\<attributes>*

Create and repair volume using only disks with the following attributes. May be specified multiple times to incorporate more disks with different sets of attributes. This is a logical OR operation.

*\<attributes>* is specified as a **key=val** pair, e.g.: **bus=scsi**

**--unique** *\<attribute>*

Require disks in the volume to be unique across the specified attribute. If a volume is desired to be built across failure domains, or across a particular disk attribute, the **--unique** option can be used to ensure unique disk selection. Perhaps a volume is desired to always use one disk from each enclosure or bus or vendor in the system.

*\<attribute>* is specified as a **key** value of an attribute, e.g.: **agent_id**

**NOTE:** To ensure disks are selected from unique disk services in an ethernet-attached installation, specify **--unique agent_id**.

**--clear-from**

Clear the **from** attributes.

**--clear-select**

Clear the **select** attributes.

**--clear-rejects**

Clear the **reject** attributes.

## VOLUME CONSISTENCY CHECK INFORMATION

### Command

*volumectl check*

*volumectl check show*

*volumectl check info*

*volumectl check ls*

Show volume consistency check history, schedule, settings, and workload estimate.

### Examples

Show volume consistency check information.

	$ volumectl check
	== History
	Name [1]    Last Checked               When   Mismatches
	--------    -------------------------  -----  ----------
	raid1.vol   2019-06-11 04:46:43 -0400  Today  0         
	raid10a.vol 2019-06-11 04:55:16 -0400  Today  0         
	raid10b.vol 2019-06-11 04:47:13 -0400  Today  0         
	
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
	Total capacity        1.0038TiB
	Estimated runtime     1 day    

## VOLUME CONSISTENCY CHECK SETTINGS

### Bandwidth Limit

*volumectl check --bw-limit \<limit>*

Set the per-volume bandwidth limit. This is the maximum bandwidth that a consistency check will use for a volume.

### Example

	$ volumectl check --bw-limit 1GiB

### Volume Count

*volumectl check --volcount \<count>*

Set the number of volumes that can simultaneously perform a consistency check.

### Example

	$ volumectl check --volcount 2

### Check Interval

*volumectl check --interval \<days>*

Set the number of days between consistency checks for a volume. A volume will be checked every *\<days>* days.

### Example

	$ volumectl check --interval 30

## VOLUME CONSISTENCY CHECK SCHEDULE

### Command

*volumectl check schedule*

Show volume consistency check schedule.

**NOTE:** The volume consistency check schedule start/end times are displayed and interpreted in the timezone configured on the host. If the host configured as UTC, the times in the check schedule are considered UTC. If the host configured as America/New_York, the times in the check schedule are considered America/New_York.

### Examples

    $ volumectl check schedule
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

## ADD TIME RANGE TO VOLUME CONSISTENCY CHECK SCHEDULE

*volumectl check schedule add*

### Required Parameters

**DAY** the day of the week (Monday-Sunday)

**START** the start time of the range from 00-23

**END** the end time of the range from 00-23

### Example

Add a time range to the check schedule on Sundays

	$ volumectl check schedule add sunday 6 12
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
	7      Sunday       06:00  12:00

## REMOVE TIME RANGE FROM VOLUME CONSISTENCY CHECK SCHEDULE

*volumectl check schedule remove*

### Required Parameters

**INDEX** the check schedule index as shown in **volumectl check schedule**

### Example

Remove a time range from the check schedule:

	$ volumectl check schedule remove 7
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

## CLEAR THE CHECK SCHEDULE

*volumectl check schedule clear*

**NOTE:** by clearing the check schedule, no volume consistency checks will be performed at any time, unless manually done by the user.

### Example

Remove a time range from the check schedule:

	$ volumectl check schedule clear
	== Schedule
	Index  Day of Week  Start  End  
	-----  -----------  -----  -----

## SET DEFAULT CHECK SCHEDULE

*volumectl check schedule default*

### Example

Set the consistency check schedule back to the default

	$ volumectl check schedule default
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

## VOLUME REBUILD SETTINGS

Volume rebuild settings are used when a volume requires recovery, such as when data is being synchronized when a volume is first created, or when data is being recovered such as when a new replacement disk is added to a volume after a failure. These settings are global.

### Bandwidth Limit

*volumectl rebuild --bw-limit \<limit>*

Set the per-volume bandwidth limit. This is the maximum bandwidth that a volume recovery operation will use for a volume.

### Example

	$ volumectl rebuild --bw-limit 1GiB

### Volume Count

*volumectl rebuild --volcount \<count>*

Set the number of volumes that can simultaneously perform a recovery operation.

### Example

	$ volumectl rebuild --volcount 2

### Show volume rebuild settings

*volumectl rebuild*

*volumectl rebuild show*

### Example

Show the volume rebuild settings.

	$ volumectl rebuild
	== Volume Rebuild Settings
	Volume bandwidth limit  1.0GiB
	Rebuild concurrency     1     

## REPORTING BUGS

Please send bug reports to <support@blockbridge.com>
