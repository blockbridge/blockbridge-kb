---
layout: page
title: PROXMOX VE SHARED STORAGE GUIDE
description: Proxmox Shared Storage Guide with Blockbridge
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

Proxmox supports several built-in storage types. Environments with existing enterprise or datacenter storage systems can use the LVM or iSCSI/kernel storage types for shared storage in support of high-availability. For service providers, these solutions are not scalable from a configuration management perspective. We developed our Proxmox-native driver specifically to address these challenges.

The table below provides a high-level overview of the capabilities of popular block storage types. For a complete list of storage types, visit the [Proxmox Storage Wiki](https://pve.proxmox.com/wiki/Storage).

| Description       | Level | High-Availability | Shared  | Snapshots | Stable |
| :---------------- | :---: | :---------------: | :-----: | :-------: | :----: |
| iSCSI/Blockbridge | block |        yes        |   yes   |    yes    |  yes   |
| Ceph/RBD          | block |        yes        |   yes   |    yes    |  yes   |
| iSCSI/kernel      | block |    inherit [1]    |   yes   |    no     |  yes   |
| LVM               | block |    inherit [1]    | yes [2] |    no     |  yes   |
| LVM-thin          | block |        no         |   no    |    yes    |  yes   |
| iSCSI/ZFS         | block |        no         |   yes   |    yes    |  yes   |

Note 1: LVM and iSCSI inherit the availability characteristics of the underlying storage.<br>Note 2: LVM can be deployed on iSCSI-based storage to get shared storage.

High-Availability
-----------------

Blockbridge provides highly-available storage that is self-healing.  Controlplane (i.e., API) and dataplane (i.e., iSCSI) services transparently failover in the event of hardware failure. Depending on your network configuration, it may be appropriate to deploy Linux multipathing for protection against network failure. Automated multipath management is supported by the Blockbridge driver.

Multi-Tenancy & Multi-Proxmox
----------------------

Blockbridge implements features critical for multi-tenant environments, including management segregation, automated performance shaping, and always-on encryption. The Blockbridge driver leverages these functions and allows you to create storage pools dedicated for different users, applications, and performance tiers. Service providers can safely deploy multiple Proxmox clusters on Blockbridge storage without the risk of collision.


High-Performance
----------------

Blockbridge is heavily optimized for performance. Expect approximately a 5x write latency and IOPS advantage when compared to native Promox CEPH/RBD solution. Optionally, the Blockbridge driver can tune your hosts for the best possible latency and performance.

At-Rest & In-Flight Encryption
------------------------------

Blockbridge implements always-on per-virtual disk encryption, automated key management, and instant secure erase for at-rest security. The Blockbridge driver also supports in-flight encryption for end-to-end protection.


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
| :---------: | -------------- | ------------ | ------------ | ------------- | ------------------- | ------------------ |
|     6.0     | 10.0 (Buster)  | 4.0.0        | 5.0          | July 2019     | 5.1                 | 1.0                |
|     6.1     | 10.2 (Buster)  | 4.1.1        | 5.3          | March 2020    | 5.1                 | 1.0                |
|     6.2     | 10.4 (Buster)  | 5.0          | 5.4 LTS      | May 2020      | 5.1                 | 1.0                |
|     6.3     | 10.6 (Buster)  | 5.1          | 5.4 LTS      | November 2020 | 5.1                 | 1.0                |

Driver Packages
---------------

### Blockbridge-cli


On each Proxmox node, install the Blockbridge cli package:

```
wget http://zion/shared/josh/blockbridge-cli_5.0.0-1422_amd64.deb
apt install ./blockbridge-cli_5.0.0-1419_amd64.deb
```

### blockbridge-proxmox
On each Proxmox node, install the Blockbridge storage plugin:

```
wget http://zion/shared/josh/blockbridge-proxmox_5.0.0-3_all.deb
apt install ./blockbridge-proxmox_5.0.0-3_all.deb
```

### optional packages
If you want to use TLS, install stunnel

```
apt install stunnel
```

Driver Options
--------------

| Parameter            | Type        | Values         | Description                                      |
| :------------------- | :---------- | :------------- | :----------------------------------------------- |
| api_url              | string      |                |                                                  |
| auth_token           | string      |                | Blockbridge controlplane API authentiction token |
| ssl_verify_peer      | boolean     | 0,1 (default)  | Enable or disable peer certificate verification  |
| service_type         | string      |                | Override default provisioning template selection |
| query_include        | string-list |                | Require specific tags when provisioning storage  |
| query_exclude        | string-list |                | Reject specific tags when provisioning storage   |
| transport_encryption | enum        | 'tls','none' (default) | Transport data encryption protocol               |
| multipath            | boolean     | 1,0 (default)  | Automatically detect and configure storage paths |


Driver Authentication
---------------------

### Create a persistent authorization for Proxmox use:

Login to Blockbridge controlplane as system user:

```
root@proxmox-1:~# bb auth login
Enter a default management host: dogfood.blockbridge.com
Authenticating to https://dogfood.blockbridge.com/api

Enter user or access token: system
Password for system:
Authenticated; token expires in 3599 seconds.
== Authenticated as user system.
```

Create new Proxmox dedicate account for storage and management isolation:

```
root@proxmox-1:~# bb account create --name proxmox --password
Enter password:
== Created account: proxmox (ACT0762194C407BA625)

== Account: proxmox (ACT0762194C407BA625)
name                  proxmox
label                 proxmox
serial                ACT0762194C407BA625
created               2021-01-27 16:58:53 -0500
disabled              no
```

Login as newly created Proxmox account:

```
root@proxmox-1:~# bb auth login
Authenticating to https://dogfood.blockbridge.com/api

Enter user or access token: proxmox
Password for proxmox:
Authenticated; token expires in 3599 seconds.

== Authenticated as user proxmox3.
```

Create an authentication token for Proxmox storage setup:

```
root@proxmox-1:~# bb authorization create --notes "Proxmox Cluster token"
== Created authorization: ATH4762194C412D97FE

== Authorization: ATH4762194C412D97FE
notes                 Proxmox Cluster token
serial                ATH4762194C412D97FE
account               proxmox (ACT0762194C407BA625)
user                  proxmox (USR1B62194C407BA0E5)
enabled               yes
created at            2021-01-27 16:59:08 -0500
access type           online
token suffix          rDznjz8A
restrict              auth
enforce 2-factor      false

== Access Token
access token          1/LtVVws54+bGvb/l...njz8A

*** Remember to record your access token!
```

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
```

After editing `storage.cfg` (or updating the blockbridge plugin) we recommend restarting`pvedaemon`, `pveproxy` and `pvestatd` services.

```
systemctl restart pvedaemon pveproxy pvestatd
```

Blockbridge Storage Templates
-----------------------------

Proxmox offers multiple interfaces for storage management.

 * The GUI offers storage management scoped to the context of virtual machine.
 * The `pvesm` command provides granular storage management for specific node.
 * The `qm` command allows for VM specific volume management.
 * The `pvesh` API tool provides granular storage and VM management, and can operate on any node in your Proxmox cluster.

PROXMOX STORAGE PRIMITIVES
===================

Device Naming Specification
---------------------------

Is it essential to understand that **Proxmox does not maintain internal state about storage devices or connectivity**. Proxmox relies on device naming to know which devices are associated with virtual machines and how those device are connected to the virtual storage controller. The general device name format appear below:

```
Device Filename Specification:
vm-<vmid>-disk-<unique-id>

<vmid>: <integer> (100 - N)
Specify owner VM

<disk-id>: <integer> (1 - N)
Unique naming of disk files
```

NOTE: Interfaces that accept device filenames do not thoroughly validate naming. Our advice is to stick with the format described above.


Show Storage Pools
------------------

Proxmox supports operation of multiple pools of storage. This flexibility allows for otimization of storage resources based on requirements. For example, the default CephFS pool works well for shared file storage, for such resources as ISOs, Snippets, etc. The Blockbridge is apropriate for block storage, where high-performance and low-latency are preferred.

Not all storage pools allow for shared access. As such, the interfaces used to view storage pools are scoped to a node. When using a shared storage type, such as Blockbridge of CephFS, each node will return consistent results.


### PVESM


```
# Show available storage types on the local node

$ pvesm status
Name                      Type  Status      Total      Used  Available       %
backup                     pbs  active   65792536   7402332   55018432  11.25%
local                      dir  active    7933384   6342208    1168472  79.94%
shared-block-gp    blockbridge  active  268435456  83886080  184549376  31.25%
shared-block-iops  blockbridge  active  268435456  33669120  234766336  12.54%
shared-file             cephfs  active   59158528    995328   58163200   1.68%
```

### PVESH


```
# Show available storage types on proxmox-1

$ pvesh get /nodes/proxmox-1/storage/
┌──────────────────────┬───────────────────┬─────────────┬────────┬────────────┬─────────┬────────┬────────────┬────────────┬─────────┐
│ content              │ storage           │ type        │ active │      avail │ enabled │ shared │      total │       used │  used % │
╞══════════════════════╪═══════════════════╪═════════════╪════════╪════════════╪═════════╪════════╪════════════╪════════════╪═════════╡
│ backup               │ backup            │ pbs         │ 1      │  52.47 GiB │ 1       │ 0      │  62.74 GiB │   7.06 GiB │  11.25% │
├──────────────────────┼───────────────────┼─────────────┼────────┼────────────┼─────────┼────────┼────────────┼────────────┼─────────┤
│ images               │ shared-block-gp   │ blockbridge │ 1      │ 240.00 GiB │ 1       │ 1      │ 256.00 GiB │  16.00 GiB │   6.25% │
├──────────────────────┼───────────────────┼─────────────┼────────┼────────────┼─────────┼────────┼────────────┼────────────┼─────────┤
│ images               │ shared-block-iops │ blockbridge │ 1      │ 191.89 GiB │ 1       │ 1      │ 256.00 GiB │  64.11 GiB │  25.04% │
├──────────────────────┼───────────────────┼─────────────┼────────┼────────────┼─────────┼────────┼────────────┼────────────┼─────────┤
│ iso,images,vztmpl,.. │ local             │ dir         │ 1      │   1.11 GiB │ 1       │ 0      │   7.57 GiB │   6.05 GiB │  79.99% │
├─────────────────────-┼───────────────────┼─────────────┼────────┼────────────┼─────────┼────────┼────────────┼────────────┼─────────┤
│ vztmpl,backup,iso    │ shared-file       │ cephfs      │ 1      │  55.47 GiB │ 1       │ 1      │  56.42 GiB │ 972.00 MiB │   1.68% │
└──────────────────────┴───────────────────┴─────────────┴────────┴────────────┴─────────┴────────┴────────────┴────────────┴─────────┘
```

List Volumes
------------

You can enumerate volumes stored in a storage pool are using the GUI, `pvesm`, and `pvesh` tools.

TIP: Blockbridge is shared storage. The contents of a storage pool can be enumerated from any node in your Proxmox Cluster.

### GUI

To generate a list of all volumes in a storage pool, we recommend `Folder View`. To see devices connected to a specific virtual machine, select the VM from the primary navigation plane. Then, select `Hardware`.



To see a list of all device in the storage pool, select a storage pool from the Storage folder in the primary navigation plane: add nodes have a consistent view of storage. Then, select VM Disks`.

### PVESM
```
pvesm list <storage> [--vmid <integer>]
```

| Parameter |  Format  | Description                                 |
| --------- | :------: | ------------------------------------------- |
| storage   |  string  | Storage pool identifier from `pvesm status` |
| vmid      | integer  | Optional Virtual machine owner ID           |

**Example**

```
# List all volumes from the shared-block-iops pool.

$ pvesm list shared-block-iops
Volid                              Format  Type             Size VMID
shared-block-iops:vm-101-disk-0    raw     images    34359738368 101
shared-block-iops:vm-101-disk-1    raw     images    42949672960 101
shared-block-iops:vm-101-disk-2    raw     images    34359738368 101
shared-block-iops:vm-101-state-foo raw     images     4819255296 101
shared-block-iops:vm-10444-disk-1  raw     images    34359738368 10444
shared-block-iops:vm-2000-disk-0   raw     images      117440512 2000
```
```
# List volumes of VM 101 stored in the shared-block-iops pool.

$ pvesm list shared-block-iops --vmid 101
Volid                              Format  Type             Size VMID
shared-block-iops:vm-101-disk-0    raw     images    34359738368 101
shared-block-iops:vm-101-disk-1    raw     images    42949672960 101
shared-block-iops:vm-101-disk-2    raw     images    34359738368 101
shared-block-iops:vm-101-state-foo raw     images     4819255296 101
```

### PVESH

```
pvesh get <api_path> [-vmid <integer>]
```

| Parameter |  Format  | Description                                             |
| --------- | :------: | ------------------------------------------------------- |
| api_path  |  string  | `/nodes/{node}/storage/{storage}/content`               |
| node      |  string  | Any pve node listed in the output of `pvesh get /nodes` |
| storage   |  string  | Storage pool identifier from `pvesh get /storage`       |
| vmid      | integer  | Optional Virtual machine owner ID                       |


```
# volumes from the shared-block-iops poo

$ pvesh get /nodes/proxmox-1/storage/shared-block-iops/content --vmid 101
┌────────┬────────────┬────────────────────────────────────┬────────────┬───────────┬───────┬────────┬──────┬──────────────┬───────┐
│ format │       size │ volid                              │      ctime │ encrypted │ notes │ parent │ used │ verification │  vmid │
╞════════╪════════════╪════════════════════════════════════╪════════════╪═══════════╪═══════╪════════╪══════╪══════════════╪═══════╡
│ raw    │  32.00 GiB │ shared-block-iops:vm-101-disk-0    │ 1612628760 │           │       │        │      │              │   101 │
├────────┼────────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼───────┤
│ raw    │  40.00 GiB │ shared-block-iops:vm-101-disk-1    │ 1612627879 │           │       │        │      │              │   101 │
├────────┼────────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼───────┤
│ raw    │  32.00 GiB │ shared-block-iops:vm-101-disk-2    │ 1612564950 │           │       │        │      │              │   101 │
├────────┼────────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼───────┤
│ raw    │   4.49 GiB │ shared-block-iops:vm-101-state-foo │ 1612725210 │           │       │        │      │              │   101 │
├────────┼────────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼───────┤
│ raw    │  32.00 GiB │ shared-block-iops:vm-10444-disk-1  │ 1612566379 │           │       │        │      │              │ 10444 │
├────────┼────────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼───────┤
│ raw    │ 112.00 MiB │ shared-block-iops:vm-2000-disk-0   │ 1612478241 │           │       │        │      │              │  2000 │
└────────┴────────────┴────────────────────────────────────┴────────────┴───────────┴───────┴────────┴──────┴──────────────┴───────┘
```

```
# List volumes of VM 101 stored in the shared-block-iops pool.

$ pvesh get /nodes/proxmox-1/storage/shared-block-iops/content
┌────────┬───────────┬────────────────────────────────────┬────────────┬───────────┬───────┬────────┬──────┬──────────────┬──────┐
│ format │      size │ volid                              │      ctime │ encrypted │ notes │ parent │ used │ verification │ vmid │
╞════════╪═══════════╪════════════════════════════════════╪════════════╪═══════════╪═══════╪════════╪══════╪══════════════╪══════╡
│ raw    │ 32.00 GiB │ shared-block-iops:vm-101-disk-0    │ 1612628760 │           │       │        │      │              │  101 │
├────────┼───────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼──────┤
│ raw    │ 40.00 GiB │ shared-block-iops:vm-101-disk-1    │ 1612627879 │           │       │        │      │              │  101 │
├────────┼───────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼──────┤
│ raw    │ 32.00 GiB │ shared-block-iops:vm-101-disk-2    │ 1612564950 │           │       │        │      │              │  101 │
├────────┼───────────┼────────────────────────────────────┼────────────┼───────────┼───────┼────────┼──────┼──────────────┼──────┤
│ raw    │  4.49 GiB │ shared-block-iops:vm-101-state-foo │ 1612725210 │           │       │        │      │              │  101 │
└────────┴───────────┴────────────────────────────────────┴────────────┴───────────┴───────┴────────┴──────┴──────────────┴──────┘
```

Allocate A Volume
-----------------

Allocate storage without attachment to a VM.

Proxmox volumes are provisioned in the context of a VM. In fact, the naming scheme for volumes includes the VMID. When using the GUI, volume allocation automatically attaches the volume to the VM. When `pvesm` or `pvesh` are used, you are required to attach volumes as a separate step (see: [Attach A Volume](#attach-a-volume)). This section covers explicit allocation of volumes as a distinct action.


### PVESM

```
pvesm alloc <storage> <vmid> <filename> <size>
```

**Arguments**

| Parameter |  Format  | Description                                                  |
| --------- | :------: | ------------------------------------------------------------ |
| storage   |  string  | Storage pool identifier from `pvesm status`                  |
| vmid      | integer  | Virtual machine owner ID                                     |
| filename  |  string  | See: [Device Naming Specification](#device-naming-specification) |
| size      | \d+[MG]? | Default is KiB (1024). Optional suffixes M (MiB, 1024K) and G (GiB, 1024M) |

**Example**

```
# Allocate a 10G volume for VMID 100 from the general purpose performance pool.

$ pvesm alloc shared-block-gp 100 vm-100-disk-1 10G
successfully created 'shared-block-gp:vm-100-disk-1'
```

TIP: Proxmox allows you to allocate volumes for VMID that do not exist: you must specify a name that conforms to the name specification. Failure to do so may result in an error such as `illegal name 'vm-101-disk-2' - should be 'vm-10444-*'


### PVESH

```
pvesh create <api_path> -vmid <vmid> -filename <fileame> -size <size>
```

**Arguments**

Volume management with `pvesh` is node relative. However, Blockbridge is a shared storage type that permits uniform access to storage from all Proxmox nodes. You are free to execute allocation requests against any cluster member achieving the same result globally.

| Parameter |  Format  | Description                                                      |
| --------- | :------: | ---------------------------------------------------------------- |
| api_path  |  string  | `/nodes/{node}/storage/{storage}/content`                        |
| node      |  string  | Any pve node listed in the output of `pvesh get /nodes`          |
| storage   |  string  | Storage pool identifier from `pvesh get /storage`                     |
| vmid      | integer  | Virtual machine owner ID                                         |
| filename  |  string  | See: [Device Naming Specification](#device-naming-specification) |
| size      | \d+[MG]? | Default: KiB (1024). Other Suffixes: M (MiB, 1024K) and G (GiB, 1024M) |

**Example**

```
# Allocate a 10G volume for VMID 100 from the general purpose performance pool.

$ pvesh create /nodes/proxmox-1/storage/shared-block-gp/content -vmid 100 -filename vm-100-disk-1 -size 10G
shared-block-gp:vm-100-disk-1
```

Delete A Volume
-----------------

You can use either `pvesm` or `pvesh` commands to delete a volume. It may appear as though the tools use inconsistent terminology. However, keep in mind that `pvesh` is submitting a `delete` HTTP request to the resource URL.

NOTE: You can delete a volume that is attached to a VM. Failure to detach before release results in a stale attachment: a VM reference to storage that no longer exists. You can remove the stale attachment with the [Detach command](#detach a volume).

TIP: The delete operation with Blockbridge automatically performs an instantaneous secure-erase.

TIP: Blockbridge is shared storage. You can execute the delete operation against any node in your Proxmox cluster.

### PVESM

```
pvesm free <volume> --storage <storage>
```

| Parameter | Format | Description               |
| --------- | :----: | ------------------------- |
| volume    | string | Name of volume to destroy |
| storage   | string | Storage pool identifier   |

**Example**

```
# Destroy a volume allocated from the general purpose perfomance pool.

$ pvesm free vm-100-disk-10 --storage shared-block-gp
Removed volume 'shared-block-gp:vm-100-disk-10'
```

### PVESH

```
pvesh delete <api_path>
```

| Parameter | Format | Description                                             |
| --------- | :----: | ------------------------------------------------------- |
| api_path  | string | `/nodes/{node}/storage/{storage}/content/{volume}`      |
| node      | string | Any pve node listed in the output of `pvesh get /nodes` |
| storage   | string | Storage pool identifier                                 |
| volume    | string | Name of volume to destroy                               |

**Example**

```
# Destroy a volume allocated from the general purpose perfomance pool.

$ pvesh delete /nodes/proxmox-1/storage/shared-block-gp/content/vm-100-disk-1
Removed volume 'shared-block-gp:vm-100-disk-1'
```

Attach A Volume
-----------------
An attachment is effectively a VM configuration reference to a storage device. An attachment describes how a storage device is connected to the VM and how the guest OS sees it. The attach operation is principally a VM operation.

TIP: Proxmox considers storage devices that are allocated, but not attached, as `unused`.

TIP: The`attach` and `detach` commands are essential primitives required to move a disk between virtual machines.

WARN: it is possible to accidentally attach the same device multiple times.

### GUI

The GUI allows you to `attach` devices from the `Hardware` list that are identified as `Unused`. Select an `Unused` disk from the `Hardware` table and click the `Edit` button. Assign a `Bus` and `Device` number. Then, `Add` the device to the VM.

TIP: You may need to execute `qm rescan --vmid <vmid>` on the Proxmox node that owns the VM, if you suspect that an unusued device is missing.

### QM

```
qm set <vmid> --scsihw <scsi-adapter> --scsi<N> <storage>:<volume>
```

| Parameter    | Format  | Description                                                  |
| ------------ | :----:  | ------------------------------------------------------------ |
| vmid         | string  | The (unique) ID of the VM.                                   |
| scsi-adapter | string  | SCSI controller model (`man qm` for more details)            |
| N            | integer | SCSI target/device number (min: 0, max: 30)                  |
| storage      | string  | Storage pool identifier                                      |
| volume       | string  | Name of volume to attach                                     |

**Example**

```
# Attach device vm-100-disk-1 to VM 100

$ qm set 100 --scsihw virtio-scsi-pci --scsi1 shared-block-gp:vm-100-disk-1
update VM 100: -scsi1 shared-block-gp:vm-100-disk-1 -scsihw virtio-scsi-pci
```

TIP: Although Blockbridge is a shared storage type, the Proxmox `qm` command must execute on the home node of the VM.

### PVESH

```
pvesh create <api_path> -scsihw <scsi-adapter> -scsi<n> <storage>:<volume>
```

| Parameter    | Format  | Description                                            |
| ------------ | :-----: | ------------------------------------------------------ |
| api_path     | string  | `/nodes/{node}/qemu/{vmid}/config`                     |
| node         | string  | pve node owner of the VM                               |
| scsi-adapter | string  | SCSI controller model (`man qm` for more details)      |
| N            | integer | SCSI target/device number (min: 0, max: 30)            |
| storage      | string  | Storage pool identifier                                |
| volume       | string  | Name of volume to attach                               |


**Example**

```
# Attach device vm-100-disk-1 to VM 100

$ pvesh create /nodes/proxmox-1/qemu/100/config -scsihw virtio-scsi-pci -scsi1 shared-block-gp:vm-100-disk-1
update VM 100: -scsi1 shared-block-gp:vm-100-disk-1 -scsihw virtio-scsi-pci
```

TIP: You can perform an attach operation using the `pvesh` command while operating on any node in your Proxmox cluster.

Detach A Volume
-----------------

The detach operation updates the configuration of a VM to remove references to a storage device. If the VM is running, the device will disappear from the guest. Detach is a non-destructive operation and does not release storage.

NOTE: The Proxmox interfaces use inconsistent terminology for this operation across management interfaces. The `detach` in the GUI is synonymous with `unlink` in `pvesh` and `qm`.

### GUI

The GUI allows you to `detach` devices in `Hardware` list. Select a disk from the `Hardware` table and click the `Detach` button.

### QM

```
qm unlink <vmid> --idlist scsi<N>
```

| Parameter | Format  | Description                                                  |
| --------- | :-----: | ------------------------------------------------------------ |
| vmid      | string  | The (unique) ID of the VM.                                   |
| N         | integer | SCSI target/device number (min: 0, max: 30)                  |

**Example**

```
# Unlink the scsi1 device from VM 100

$ qm unlink 100 --idlist scsi1
update VM 100: -delete scsi1
```

TIP: You can display a list of storage devices attached to a VM using the `qm config <VMID>` command.

### PVESH

```
pvesh set <api_path> -idlist scsi<N>
```

| Parameter | Format  | Description                        |
| --------- | :-----: | ---------------------------------- |
| api_path  | string  | `/nodes/{node}/qemu/{vmid}/unlink` |
| node      | string  | pve node owner of the VM           |
| vmid      | string  | The (unique) ID of the VM.         |
| N         | integer | SCSI target/device number (min: 0, max: 30)                  |


**Example**

```
# Unlink the scsi1 device from VM 100

$ pvesh set /nodes/proxmox-1/qemu/100/unlink -idlist scsi1
update VM 100: -delete scsi1
```

TIP: You can display a list of storage devices attached to a VM using `pvesh get /nodes/<node>/qemu/<vmid>/config`.

Resize A Volume
-----------------

The resize operation extends the logical address space of a storage device. Reducing the size of a device is not permitted by Proxmox. The resize operation can only execute against devices that are attached to a VM.

TIP: If you need to extend a filesystem, resizing the underlying storage device is only one step of many. See the Proxox Wiki for [Resize disks](https://pve.proxmox.com/wiki/Resize_disks) for additional information on partition management, LVM, and guest specific considerations.

### GUI

The GUI allows you to `resize` devices available from `Hardware` list. Select a disk from the `Hardware` table and click the `Resize` button.

### QM

```
qm resize <vmid> scsi<N> <size>
```

| Parameter | Format  | Description                |
| --------- | :----:  | -------------------------- |
| vmid      | string  | The (unique) ID of the VM. |
| N         | integer | SCSI target/device number (min: 0, max: 30) |
| size      | \+?\d+(\.\d+)?[KMGT]? | With the + sign the value is added to the actual size of the volume. Without it, the value is taken as absolute.|


**Example**

```
# Extend the device attached to scsi1 of VM 100 by 1GiB

$ qm resize 100 scsi1 +1G
```

### PVESH

```
pvesh set <api_path> -disk scsi<N> -size <size>
```

| Parameter | Format  | Description                                                  |
| --------- | :-----: | ------------------------------------------------------------ |
| api_path  | string  | `/nodes/{node}/qemu/{vmid}/resize`                           |
| node      | string  | pve node owner of the VM                                     |
| vmid      | string  | The (unique) ID of the VM.                                   |
| N         | integer | SCSI target/device number (min: 0, max: 30) |
| size      | \+?\d+(\.\d+)?[KMGT]? | With the + sign the value is added to the actual size of the volume. Without it, the value is taken as absolute.|

**Example**

```
# Extend the device attached to scsi1 of VM 100 by 1GiB

$ pvesh set /nodes/proxmox-1/qemu/100/resize -disk scsi1 -size +1G
```

Create A Snapshot
-----------------

Snapshots provide a recovery point for a virtual machine's state, configuration, and data. Proxmox orchestrates snapshots via QEMU and backend storage providers. When you snapshot a Proxmox VM that uses virtual disks backed by Blockbridge, your disk snapshots are thin, complete instantly, and avoid copy-on-write (COW) performance penalties.

WARN: If multiple devices are attached to a single VM, Promox will snapshot each active device. Devices that are detached (i.e., `unused`) are ignored by Proxmox.

### GUI

In the `Snapshots` panel for the VM, click `Take Snapshot`. The duration of the operation depends on whether VM state is preserved.

TIP: Closing the dialog does not terminate the operation. It will continue to operate in the background.

### QM

```
qm snapshot <vmid> <snapname> --description <desc> --vmstate <save>
```

| Parameter | Format  | Description                      |
| --------- | :----:  | -------------------------------- |
| vmid      | string  | The (unique) ID of the VM.       |
| snapname  | string  | The name of the snapshot.        |
| desc      | string  | Snapshot description - Optional  |
| save      | boolean | [0,1] Save VM RAM state - Optional |

**Example**

```
# Take a snapshot of VM 100, including RAM.

qm snapshot 100 snap_1 --description "hello world" --vmstate 1
```

### PVESH

```
pvesh create <api_path> -snapname -description <desc> -vmstate <save>
```

| Parameter | Format  | Description                          |
| --------- | :-----: | ------------------------------------ |
| api_path  | string  | `/nodes/{node}/qemu/{vmid}/snapshot` |
| node      | string  | pve node owner of the VM.            |
| vmid      | string  | The (unique) ID of the VM.           |
| snapname  | string  | The name of the snapshot.            |
| desc      | string  | Snapshot description - Optional      |
| save      | boolean | [0,1] Save VM RAM state - Optional   |

**Example**

```
# Take a snapshot of VM 100, including RAM.

pvesh create /nodes/proxmox-1/qemu/100/snapshot -snapname snap_1 -description "hello world" -vmstate 1
```


Remove A Snapshot
-----------------

Delete a VM snapshot and release associated storage resources.

### GUI

In the `Snapshots` panel for the VM, select the snapshot to remove, and then click `Remove`. A dialog will appear to confirm your intent.

### QM

```
qm delsnapshot <vmid> <snapname> --force <force>
```

| Parameter | Format  |  Description                |
| --------- | :-----: |  -------------------------- |
| vmid      | string  | The (unique) ID of the VM.  |
| snapname  | string  | The name of the snapshot.   |
| force     | boolean | Remove config, even if storage removal fails. - Optional |

**Example**

```
# Gracefully delete snapshot snap1 of VM 100

qm delsnapshot 100 snap1
```

### PVESH

```
pvesh delete <api_path> -force <force>
```

| Parameter | Format  | Description                                     |
| --------- | :-----: | ----------------------------------------------- |
| api_path  | string  | `/nodes/{node}/qemu/{vmid}/snapshot/{snapname}` |
| node      | string  | pve node owner of the VM                        |
| vmid      | string  | The (unique) ID of the VM.                      |
| snapname  | string  | The name of the snapshot to delete.             |
| force     | boolean | Remove config, even if storage removal fails. - Optional |

**Example**

```
# Gracefully Delete snapshot snap1 of VM 100

pvesh delete /nodes/proxmox-1/qemu/100/snapshot/snap1
```

Restoring From A Volume Snapshot
--------------------------------

<!---

PROXMOX STORAGE MANAGEMENT
==========================

Full Clone From VM
-----------------

A clone of a Virtual Machine is always a complete copy and is fully independent of the original VM. It requires the same amount of disk space as the original.

### GUI

Right click on the VM in the "Folder View" and select "Clone". Enter required information for the new cloned VM



### QM

```qm clone 2000 3001 --full true --name bb-full-clone-2000-1```

### PVESH

```pvesh create /nodes/proxmox-1/qemu/2000/clone -newid 3001 -full 1 -name bb-full-clone-2000-1```

Linked Clone From VM
-----------------

A Linked Clone can only be created from a VM Template.

Full Clone From Template
-----------------

A full clone of a Template is a complete copy and is fully independent of the Template. It requires the same amount of disk space as the template.

### GUI

Right click on the VM Template in the "Folder View" and select "Clone". Choose "Linked" in the "Mode" drop-down menu.

### QM

```qm clone 2000 3001 --full true --name bb-full-clone-2000-1```

### PVESH

```pvesh create /nodes/proxmox-1/qemu/2000/clone -newid 3001 -full 1 -name bb-full-clone-2000-1```

Linked Clone From Template
-----------------

A linked clone VM requires less disk space but cannot run without access to the base VM Template. When using Blockbridge as a backend storage, Proxmox will take advantage of Blockbridge Snapshot/Clone functionality.

### GUI

Right click on the VM Template in the "Folder View" and select "Clone". Choose "Full" in the "Mode" drop-down menu.

### QM

```qm clone 2000 3002 --full false --name bb-link-clone-2000-1```

### PVESH

```pvesh create /nodes/proxmox-1/qemu/2000/clone -newid 3002 -full 0 -name bb-link-clone-2000-1```

VM Creation From ISO
-----------------

ISO can be attached to a VM for Boot and OS installation. The ISO must be placed on file-based storage that is available to the VM. Ideally this location is available to all members of the Proxmox cluster. If it is not, the VM cannot be automatically migrated between Proxmox nodes.

VM Creation from Disk Image
-----------------

A disk image, such as Cloud Image, can be imported directly onto Blockbridge backed Volume for further boot from it.

Note: You must already have created a Virtual Machine for "import" to work.

### GUI

You can only import disk using CLI tools.

### QM

Note: the image file must be locally accessible to the "qm" command.

qm importdisk 2000 cirros-0.5.1-x86_64-disk.img dogfood

qm set 2000 --scsi0 dogfood:vm-2000-disk-0

### PVESH

Note: "importdisk" functionality is only available via "qm" interface.

pvesh create /nodes/proxmox-1/qemu/2000/config -scsi0 dogfood:vm-2000-disk-0

Adding Storage To Running VM
-----------------

### GUI

### QM/PVESM

Note: `pvesm` interface only operates on storage, to insert the volume into VM configuration you must use `qm.`

pvesm alloc dogfood 3003 vm-3003-disk-1 4G

Note: `qm` only operates on Virtual Machine configuration, to create the volume you must use `pvesm`.

qm set 3003 --scsihw virtio-scsi-pci --scsi1 dogfood:vm-3003-disk-1

### PVESH

Note: using Proxmox API/pvesh interface you can execute both creation and assignment operations.

pvesh create /nodes/proxmox-1/storage/dogfood/content -size 4G -vmid 3003 -filename vm-3003-disk-1

pvesh create /nodes/proxmox-3/qemu/3003/config -scsi1 dogfood:vm-3003-disk-1



Deleting Storage From Running VM
-----------------

Before deleting storage from a VM make sure that the disk is not in use or mounted on boot, otherwise the OS can experience hung IO or can fail to boot.

### GUI

### QM/PVESM

qm unlink 3003 --idlist scsi1

qm set 3003 --delete unused0

pvesm free dogfood:vm-3000-disk-1

### PVESH

pvesh set /nodes/proxmox-3/qemu/3003/unlink -idlist scsi1

pvesh set /nodes/proxmox-3/qemu/3003/config --delete unused0

pvesh delete .... ?

Moving A Volume Between VMs
-----------------

Proxmox does not provide a packaged procedure on moving a volume between Virtual Machines. However Blockbridge backed volume can be moved easily not only between Proxmox VMs but also between Proxmox and other Hypervisors or even Baremetal servers.

### GUI

N/A

### QM

qm unlink 3003 --idlist scsi1

pvesh set /nodes/proxmox-3/qemu/3003/unlink -idlist scsi1

bb vss update --vss vm-3003-disk-1 --label vm-3004-disk-1

qm set 3003 --delete unused0

pvesh set /nodes/proxmox-3/qemu/3003/config --delete unused0

qm rescan (no equivalent?)

qm set 3004 --scsi1 dogfood:vm-3004-disk-1,ssd=1

pvesh create /nodes/proxmox-3/qemu/3004/config -scsi1 dogfood:vm-3004-disk-1

### PVESH

Migrating A Volume Between Pools
-----------------

When moving Volume between the pools a full copy of the volume will be created by Proxmox using host-side tools. You will need the same available capacity to your volume size in the target pool.
Note that the source disk is not deleted automatically after the volume was moved. It will appear as "unusedX" entry in "Hardware" tab and you will need to delete it manually to release the used space.

### GUI

### QM

​       qm move_disk <vmid> <disk> <storage> [OPTIONS]

### PVESH

pvesh create /nodes/{node}/qemu/{vmid}/move_disk

PROXMOX BACKUP & RECOVERY
==========================

Full Backup
-----------------

### GUI

### QM

### PVESH

Incremental Backup
-----------------

### GUI

### QM

### PVESH

Restore From Backup
-----------------

### GUI

### QM

### PVESH

Restore From Rollback
-----------------

### GUI

### QM

### PVESH

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

PROXMOX HOST TUNING
============

Multipath IO Scheduling
------------------

NIC Large Receive Offload
------------------

NIC Interrupt Affinity
------------------

NIC Interrupt Coalescing
------------------

Linux iSCSI Affinity
------------------

Jumbo Frames
------------------

VLAN Considerations
------------------

-->

KNOWN ISSUES
============

GUI Storage Types
------------------

GUI Storage Usage
------------------

GUI Storage Configuration
------------------

Thin Clones of Snapshots
------------------

Container Storage
------------------

Space Reporting (status api call)
---------------------------------

The driver currently always reports 1000000000 bytes of storage total with 50%
used. I am not sure what we want to do here... we punted on space reporting for
openstack, but when I did the same thing for proxmox it just considers the
storage to be offline... I keep forgetting about this. Needs some sort of
investigation.

ADDITIONAL RESOURCES
====================

[https://pve.proxmox.com/wiki/Main_Page](https://pve.proxmox.com/wiki/Main_Page)

[https://pve.proxmox.com/pve-docs/api-viewer](https://pve.proxmox.com/wiki/Main_Page)

[https://pve.proxmox.com/pve-docs/qm.1.html](https://pve.proxmox.com/wiki/Main_Page)

[https://pve.proxmox.com/pve-docs](https://pve.proxmox.com/wiki/Main_Page)
