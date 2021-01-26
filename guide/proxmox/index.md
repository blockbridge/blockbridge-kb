---
layout: page
title: BLOCKBRIDGE PROXMOX VE STORAGE GUIDE
description: Configure the Blockbridge Proxmox Plugin
permalink: /guide/proxmox/index.html
keywords: proxmox
toc: false
---

This guide provides technical details for deploying Proxmox VE with Blockbridge iSCSI storage using the Blockbridge storage driver for Proxmox.

Most readers will want to start with the Deployment and Tuning Quickstart section. It’s an ordered list of configuration steps and is the fastest path to an installation. The rest of the document provides detail on all aspects of using Promox with Blockbridge.

FEATURE OVERVIEW
================

Formats & Content Types
------------------------

Blockbridge provides **block-level storage** optimized for peformance, security, and efficiency. Block storage is used by Proxmox to store raw disk **images**. Disk images are attached to virtual machines and typically formatted with a filesystem for use by the guest.

Proxmox supports several built-in storage types. Environments with existing enterprise or datacenter storage systems can use the LVM or iSCSI/kernel storage types for shared storage in support of high-availability. For service providers, these solutions are not scalable from a configuration management perspective. We developed out Proxmox-native driver specifically to address these challenges.

The table below provides a high-level overview of the capabilities of popular block storage types. For a complete list of storage types, visit the [Proxmox Storage Wiki](https://pve.proxmox.com/wiki/Storage).

| Description | Level | High-Availability  | Shared | Snapshots | Stable |
| :---        | :---: | :----------------: | :----: | :-------: | :----: |
| iSCSI/Blockbridge | block | yes | yes | yes | yes |
| Ceph/RBD          | block | yes | yes | yes | yes |
| iSCSI/kernel      | block | inherit [1] | yes  | no | yes |
| LVM               | block | inherit [1] | yes [2]  | no | yes |
| LVM-thin          | block | no | no  | yes | yes |
| iSCSI/ZFS         | block | no  | yes | yes | yes |

Note 1: LCM and iSCSI inherit the availability characteristics of the underlying storage.<br>
Note 2: LVM can be deployed on iSCSI-based storage to get shared storage.

High-Availability
-----------------

Blockbridge proviudes highly-available storage that is self-healing.  Controlplane (i.e., API) and dataplane (i.e., iSCSI) services transparently failover in the event of hardware failure. Depending on your network configuration, it may be appropriate to deploy Linux multipathing for protection against network failure. Automated multipath management is supported by the Blockbridge driver.

Multi-Tenancy & Multi-Proxmox
----------------------

Blockbridge implements features critical for multi-tenant environments, including management segregation, automated performance shaping, and always-on encryption. The Blockbridge driver leverages these functions and allows you to create storage pools dedicated for different users, applications, and performance tiers. Service providers can safely deploy multiple Proxmox clusters on Blockbridge storage without the risk of collision.


High-Performance
----------------

Blockbridge is heavily optimized for performance. Expect approximately a 5x write latency and IOPS advantage when compared to native Promox CEPH/RBD solution. Optionally, the Blockbridge driver can tune your hosts for the best possible latency and performance.

At-Rest & In-Flight Encryption
------------------------------

Blockbridge implements always-on per-virtual disk encryption, automated key management, and instant secure erase for at-rest security. The Blockbridge driver also supports inflight encryption for end-to-end protection.


Snapshots & Clones
------------------

Snapshots and Clones are thin and instantaneous. Both technologies take advantage of an allocate-on-write storage architecture, for significantly improved latency compared to copy-on-write strategies. 


Thin Provisioning & Data Reduction
-----------------------------------

Blockbridge supports thin-provision, pattern elimination, and latency-optimized adaptive data reduction. These features are transparent to Proxmox.

DEPLOYMENT PLANNING
===================

Supported Versions
------------------

| PVE Version | Debian Version | QEMU Version | Linux Kernel | Release Date  | Blockbridge Version | Blockbridge Driver |
| :---------: |----------------|--------------|--------------|---------------|---------------------|--------------------|
| 6.0         | 10.0 (Buster)  | 4.0.0        | 5.0          | July 2019     | 5.1                 | 1.0                |
| 6.1         | 10.2 (Buster)  | 4.1.1        | 5.3          | March 2020    | 5.1                 | 1.0                |
| 6.2         | 10.4 (Buster)  | 5.0          | 5.4 LTS      | May 2020      | 5.1                 | 1.0                |
| 6.3         | 10.6 (Buster)  | 5.1          | 5.4 LTS      | November 2020 | 5.1                 | 1.0                |

Driver Packages
---------------

###blockbridge-cli


On each Proxmox node, install the cli package. This version is from a special branch with proxmox enhancements/fixes:

```
wget http://zion/shared/josh/blockbridge-cli_5.0.0-1422_amd64.deb
apt install ./blockbridge-cli_5.0.0-1419_amd64.deb
```

###blockbridge-proxmox
On each Proxmox node, install the Blockbridge storage plugin:

```
wget http://zion/shared/josh/blockbridge-proxmox_5.0.0-3_all.deb
apt install ./blockbridge-proxmox_5.0.0-3_all.deb
```

###optional bits
If you want to use TLS, install stunnel

```
apt install stunnel
```

Driver Options
--------------

| Parameter            | Type        | Values                 | Description                                      |
|:---------------------|:----------- |:-----------------------|:-------------------------------------------------|
| api_url              | string      |                        | Blockbridge controlplane API URL                 |
| auth_token           | string      |                        | Blockbridge controlplane API authentiction token |
| ssl_verify_peer      | boolean     | ['true','false']       | Enable or disable peer certificate verification  |
| service_type         | string      |                        | Override default provisioning template selection |
| query_include        | string-list |                        | Require specific tags when provisioning storage  |
| query_exclude        | string-list |                        | Reject specific tags when provisioning storage   |
| transport_encryption | enum        | ['tls','ipsec','none'] | Transport data encryption protocol               |
| multipath            | boolean     | ['true','false']       | Automatically detect and configure storage paths |


Driver Authentication
---------------------

XXX - Create a persistent authorization for Proxmox use. Can we do this from the Proxmox node?



Driver Debug
------------
The driver logs all incoming API calls with their parameters to syslog at
LOG_INFO level. It also logs the arguments used when executing any `bb`
commands. You can see the logs using `journalctl -f | grep blockbridge:`.


Proxmox Storage Definition
------------------------------------
Configure a blockbridge storage backend by additing a block to
`/etc/pve/storage.cfg`. The `/etc/pve` directory is an automatically
synchronized filesystem (proxmox cluster filesystem, or just pmxcfs), so you
only need to edit the file on one node and it will be synchronized to all nodes.
For example:

```
blockbridge: dogfood
	api_url https://dogfood.blockbridge.com/api
	auth_token 1/nalF+/S1pO............2qitqUX79LWtpw
	ssl_verify_peer 1
	shared 1
```

You must include the `shared 1` configuration, otherwise proxmox won't consider
it to be "shared" storage, and will attempt to manually copy data when migrating
a VM, instead of just attaching the device on the target hypervisor. I haven't
figured out how to get the driver to just report it's always shared. (interally
there is a list of plugin types that are known to be shared, but I don't see any
way to alter that list.)

After editing `storage.cfg` (or updating the blockbridge plugin) I always
restart the `pvedaemon` and `pveproxy` services. It seems to actually be
required to get the GUI backend to use the new plugin code, while the command
line tools load the plugin directly and need no restarting.

```
systemctl restart pvedaemon pveproxy
```

Blockbridge Storage Templates
-----------------------------


PROXMOX STORAGE PRIMITIVES
==========================

Proxmox offers multiple interfaces for storage managament.

 * The GUI offers storage management scoped to the context of virtual machine.
 * The `pvesm` command provides granular storage management for specific node.
 * The `pvesh` API tool provides granular storage management, and can operate any node in your Proxmox cluster.

Device Naming Specification
---------------------------
Is it essential to understand that **Proxmox does not maintain internal state about storage devices or connectivity**. Proxmox relies on device naming to know which devices are associated with virtual machines and how those device are connect to the virtual storage controller. The general device name format appear below:

```
Device Filename Specification:
vm-<vmid>-disk-<lun>

<vmid>: <integer> (1 - N)
Specify owner VM

<lun>: <integer> (1 - N)
A virtual bus relative address for the disk. It also serves to ensure unique naming of disk files.
```

NOTE: Interfaces that accept device filenames do not thouroughly validate naming. Our advice is to stick with the format described above. 


Allocate A Volume
-----------------
### GUI

### PVESM

```
pvesm alloc <storage> <vmid> <filename> <size>
```

| Parameter |  Format  | Description                                                                             |
|-----------|:--------:|------------|
| storage   |  string  | Storage pool identifier |
| vmid      |  integer | Virtual machine owner ID |
| filename  |  string  | See: [Device Naming Specification](#device-naming-specification) |
| size      | \d+[MG]? | Default is KiB (1024). Optional suffixes M (MiB, 1024K) and G (GiB, 1024M) |

**Example**

```
!!! NEED EXAMPLE
```

NOTE: the `pvesm alloc` command creates a device that is logically associated with a virtual machine. However, it does not automatically add it. See the section on [Attaching A Volume](#attaching-a-volume) for more information.

### PVESH
```
pvesh create <api_path> -vmid <vmid> -filename <fileame> -size <size>
```

| Parameter |  Format  | Description                                                                             |
|-----------|:--------:|------------|
| api_path  |  string  | `/nodes/{node}/storage/{storage}/content` |
| node      |  string  | Any pve node listed in the output of `pvesh get /nodes` |
| storage   |  string  | Storage pool identifier |
| vmid      |  integer | Virtual machine owner ID |
| filename  |  string  | See: [Device Naming Specification](#device-naming-specification) |
| size      | \d+[MG]? | Default is KiB (1024). Optional suffixes M (MiB, 1024K) and G (GiB, 1024M) |

**Example**

```
!!! NEED EXAMPLE
```

NOTE: the `pvesm create` command creates a device that is logically associated with a virtual machine. However, it does not automatically add it. See the section on [Attaching A Volume](#attaching-a-volume) for more information.

Free A Volume
-----------------

### GUI

### PVESM

```
pvesm free <volume> --storage <storage>
```

| Parameter |  Format  | Description                                                                             |
|-----------|:--------:|------------|
| volume    |  string  | Name of volume to destroy |
| storage   |  string  | Storage pool identifier |

**Example**

```
!!! NEED EXAMPLE
```

### PVESH
```
pvesh delete <api_path>
```

| Parameter |  Format  | Description                                                                             |
|-----------|:--------:|------------|
| api_path  |  string  | `/nodes/{node}/storage/{storage}/content/{volume}` |
| node      |  string  | Any pve node listed in the output of `pvesh get /nodes` |
| storage   |  string  | Storage pool identifier |
| volume    |  string  | Name of volume to destroy |

**Example**

```
!!! NEED EXAMPLE
```

Attach A Volume
-----------------

### GUI

This function is not available via the GUI.

### PVESM

### PVESH

Detach A Volume
-----------------

### GUI

This function is not available via the GUI.

### PVESM

### PVESH

Resize A Volume
-----------------

### GUI

### PVESM

### PVESH

Create A Volume Snapshot
-----------------

### GUI

### PVESM

### PVESH

Remove A Volume Snapshot
-----------------

### GUI

### PVESM

### PVESH


PROXMOX STORAGE MANAGEMENT
==========================


QEMU GUEST TUNING
============

QEMU SCSI Controllers
---------------------

QEMU IO Threads
---------------

QEMU SSD Emulation
------------------

QEMU Device Passthrough
-----------------------


KNOWN ISSUES
============

Space Reporting (status api call)
---------------------------------
The driver currently always reports 1000000000 bytes of storage total with 50%
used. I am not sure what we want to do here... we punted on space reporting for
openstack, but when I did the same thing for proxmox it just considers the
storage to be offline... I keep forgetting about this. Needs some sort of
investigation.
