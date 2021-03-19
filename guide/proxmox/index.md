---
layout: page
title: PROXMOX VE STORAGE GUIDE
description: Guide to Proxmox VE Shared Storage with Blockbridge
permalink: /guide/proxmox/index.html
keywords: proxmox iSCSI shared
toc: false

---

This guide provides technical details for deploying Proxmox VE with Blockbridge iSCSI storage using the Blockbridge storage driver for Proxmox.

Most readers will want to start with the Quickstart section. It’s an ordered list of configuration steps and is the fastest path to an installation. The rest of the document provides details on all aspects of using Proxmox with Blockbridge.

---

FEATURE OVERVIEW
================

Formats & Content Types
------------------------

Blockbridge provides **block-level storage** optimized for performance, security, and efficiency. Block storage is used by Proxmox to store raw disk **images**. Disk images are attached to virtual machines and typically formatted with a filesystem for use by the guest.

Proxmox supports several built-in storage types. Environments with existing
enterprise or datacenter storage systems can use the LVM or iSCSI/kernel
storage types for shared storage in support of high-availability. For service
providers, however, these solutions are simply not scalable.  The configuration
management required to implement and maintain Proxmox on traditional shared
storage systems is too large a burden. We developed our Proxmox-native driver
specifically to address these challenges.

The table below provides a high-level overview of the capabilities of popular block storage types. For a complete list of storage types, visit the [Proxmox Storage Wiki](https://pve.proxmox.com/wiki/Storage).

| Description       | Level | High-Availability | Shared  | Snapshots | Stable |
| :---------------- | :---: | :---------------: | :-----: | :-------: | :----: |
| iSCSI/Blockbridge | block |        yes        |   yes   |    yes    |  yes   |
| Ceph/RBD          | block |        yes        |   yes   |    yes    |  yes   |
| iSCSI/kernel      | block |    inherit [1]    |   yes   |    no     |  yes   |
| LVM               | block |    inherit [1]    | yes [2] |    no     |  yes   |
| LVM-thin          | block |        no         |   no    |    yes    |  yes   |
| iSCSI/ZFS         | block |        no         |   yes   |    yes    |  yes   |

Note 1: LVM and iSCSI inherit the availability characteristics of the underlying storage.<br>Note 2: LVM can be deployed on iSCSI-based storage to achieve shared storage.

High Availability
-----------------

Blockbridge provides highly-available storage that is self-healing.
Controlplane (i.e., API) and dataplane (i.e., iSCSI) services transparently
failover in the event of hardware failure. Depending on your network
configuration, it may be appropriate to deploy Linux multipathing for
protection against network failure. The Blockbridge driver supports automated multipath management.

Multi-Tenancy & Multi-Proxmox
----------------------

Blockbridge implements features critical for multi-tenant environments,
including management segregation, automated performance shaping, and always-on
encryption. The Blockbridge driver leverages these functions, allowing you to
create storage pools dedicated for different users, applications, and
performance tiers. Service providers can safely deploy multiple Proxmox
clusters on Blockbridge storage without the risk of collision.

High Performance
----------------

Blockbridge is heavily optimized for performance. Expect approximately a 5x write latency and IOPS advantage when compared to native Proxmox CEPH/RBD solution. Optionally, the Blockbridge driver can tune your hosts for the best possible latency and performance.

At-Rest & In-Flight Encryption
------------------------------

Blockbridge implements always-on per-virtual disk encryption, automated key management, and instant secure erase for at-rest security. The Blockbridge driver also supports in-flight encryption for end-to-end protection.

Snapshots & Clones
------------------

Snapshots and Clones are thin and instantaneous. Both technologies take advantage of an allocate-on-write storage architecture for significantly improved latency compared to copy-on-write strategies.

Thin Provisioning & Data Reduction
-----------------------------------

Blockbridge supports thin-provisioning, pattern elimination, and
latency-optimized adaptive data reduction. These features are transparent to
Proxmox.

---

QUICKSTART
==========

This is a quick reference for installing and configuring the Blockbridge
Proxmox VE shared storage plugin.

Some of these topics have more information available by selecting the
information **&#9432;** links next to items where they appear.


Driver Installation
-------------------

Repeat this section's instructions on each Proxmox node.

1. **Import the Blockbridge release signing key.**

        sudo apt update
        sudo apt install apt-transport-https ca-certificates curl \
          gnupg-agent software-properties-common
        curl -fsSL https://get.blockbridge.com/tools/5.1/debian/gpg | sudo apt-key add -

1. **Verify the key fingerprint.**

        sudo apt-key fingerprint 7ECF5373

        pub   rsa4096 2016-11-01 [SC]
              9C1D E2AE 5970 CFD4 ADC5  E0BA DDDE 845D 7ECF 5373
        uid           [ unknown] Blockbridge (Official Signing Key) <security@blockbridge.com>
        sub   rsa4096 2016-11-01 [E]

1. **Add the Blockbridge Tools repository and install the plugin.**

        sudo apt-add-repository \
          "deb https://get.blockbridge.com/tools/5.1/debian $(lsb_release -cs) main"
        sudo apt update
        sudo apt install blockbridge-proxmox

Authentication Token
--------------------

This section describes creating a dedicated Blockbridge account for your
Proxmox storage, and then creating an authorization token to use it.  These
steps only need to happen once.

1. **Log in to your Blockbridge controlplane as the `system` user.**

        root@proxmox-1:~# bb auth login
        Enter a default management host: blockbridge.yourcompany.com
        Authenticating to https://blockbridge.yourcompany.com/api
        
        Enter user or access token: system
        Password for system:
        Authenticated; token expires in 3599 seconds.
        == Authenticated as user system.

1. **Create a dedicated `proxmox` account.**

        root@proxmox-1:~# bb account create --name proxmox

1. **Use the 'substitute user' option to switch your session to the newly created `proxmox` account.**

    *Note that you will have to re-authenticate as the **system** user.*

        root@proxmox-1:~# bb auth login --su proxmox
        Authenticating to https://blockbridge.yourcompany.com/api
        
        Enter user or access token: system
        Password for system: ......
        Authenticated; token expires in 3599 seconds.
        
        == Authenticated as user proxmox.

1. **Create a persistent authorization token.**

        root@proxmox-1:~# bb authorization create --notes "Proxmox Cluster token"
        == Created authorization: ATH4762194C412D97FE
        ... [output trimmed] ...
        
        == Access Token
        access token          1/LtVVws54+bGvb/l...njz8A

    *Remember to record your access token!*


Proxmox Configuration
---------------------

1. **Edit `/etc/pve/storage.cfg` on any node to add a Blockbridge storage pool.
   The changes will be propagated to the other nodes.**
   
        blockbridge: shared-block-gp
                api_url https://blockbridge.yourcompany.com/api
                auth_token 1/nalF+/S1pO............2qitqUX79LWtpw

1. **Restart the `pvedaemon`, `pveproxy` and `pvestatd` services.**

    Though the configuration is automatically synchronized to all Proxmox nodes,
    you must restart services on all Proxmox nodes.

        systemctl restart pvedaemon pveproxy pvestatd

---

DEPLOYMENT & MANAGEMENT
=======================

This section describes how to install and configure the Blockbridge Proxmox
storage plugin.

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


### Import the Blockbridge Release Signing Key

On each Proxmox node, import the Blockbridge release signing key.

```
sudo apt update
sudo apt install apt-transport-https ca-certificates curl \
    gnupg-agent software-properties-common
curl -fsSL https://get.blockbridge.com/tools/5.1/debian/gpg | sudo apt-key add -
```

Verify the key fingerprint:

```
sudo apt-key fingerprint 7ECF5373
pub   rsa4096 2016-11-01 [SC]
      9C1D E2AE 5970 CFD4 ADC5  E0BA DDDE 845D 7ECF 5373
uid           [ unknown] Blockbridge (Official Signing Key) <security@blockbridge.com>
sub   rsa4096 2016-11-01 [E]
```

### Add the Blockbridge Tools Repository and Install the Plugin

On each Proxmox node, install the Blockbridge storage plugin.

```
sudo apt-add-repository \
  "deb https://get.blockbridge.com/tools/5.1/debian $(lsb_release -cs) main"
sudo apt update
sudo apt install blockbridge-proxmox
```

### Optional Packages

To use TLS transport encryption for iSCSI traffic, install the `stunnel` package.

```
apt install stunnel
```

{% include note.html content="There is a performance penalty for using stunnel
to encrypt iSCSI data flows, but it's not as bad as you might expect.  Consult
with Blockbridge support on how best to deploy high-performance SSL-secured
storage." %}

Driver Options
--------------

| Parameter            | Type        | Values         | Description                                      |
| :------------------- | :---------- | :------------- | :----------------------------------------------- |
| `api_url`              | string      |                |                                                  |
| `auth_token`           | string      |                | Blockbridge controlplane API authentiction token |
| `ssl_verify_peer`      | boolean     | 0,1 (default)  | Enable or disable peer certificate verification  |
| `service_type`         | string      |                | Override default provisioning template selection |
| `query_include`        | string-list |                | Require specific tags when provisioning storage  |
| `query_exclude`        | string-list |                | Reject specific tags when provisioning storage   |
| `transport_encryption` | enum        | 'tls','none' (default) | Transport data encryption protocol               |
| `multipath`            | boolean     | 1,0 (default)  | Automatically detect and configure storage paths |


Driver Authentication
---------------------

### Create a persistent authorization for Proxmox use

Log in to your Blockbridge controlplane as the `system` user.

```
root@proxmox-1:~# bb auth login
Enter a default management host: blockbridge.yourcompany.com
Authenticating to https://blockbridge.yourcompany.com/api

Enter user or access token: system
Password for system:
Authenticated; token expires in 3599 seconds.
== Authenticated as user system.
```

Create a dedicated `proxmox` account for storage and management isolation.

```
root@proxmox-1:~# bb account create --name proxmox
== Created account: proxmox (ACT0762194C407BA625)

== Account: proxmox (ACT0762194C407BA625)
name                  proxmox
label                 proxmox
serial                ACT0762194C407BA625
created               2021-01-27 16:58:53 -0500
disabled              no
```

With the `system` username and password, use the "substitute user" function to
switch to the newly created `proxmox` account:

```
root@proxmox-1:~# bb auth login --su proxmox
Authenticating to https://blockbridge.yourcompany.com/api

Enter user or access token: system
Password for system: ......
Authenticated; token expires in 3599 seconds.

== Authenticated as user proxmox.
```

Create a persistent authorization for use by the Blockbridge storage plugin.

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

Proxmox Storage Definition
--------------------------

Configure a blockbridge storage backend by addicting a new section to `/etc/pve/storage.cfg`. The `/etc/pve` directory is an automatically synchronized filesystem (proxmox cluster filesystem, or just `pmxcfs`), so you only need to edit the file on a single node; the changes are synchronized to all cluster members.

For example, edit `storage.cfg` to add this section:

```
blockbridge: shared-block-gp
        api_url https://blockbridge.yourcompany.com/api
        auth_token 1/nalF+/S1pO............2qitqUX79LWtpw
```

After editing `storage.cfg` (or updating the blockbridge plugin), restart
the `pvedaemon`, `pveproxy` and `pvestatd` services.

```
systemctl restart pvedaemon pveproxy pvestatd
```

{% include note.html content="Though the configuration is automatically
synchronized to all Proxmox nodes, you'll still have to restart services on all
cluster members." %}

Troubleshooting
---------------

The Blockbridge plugin logs all interactions with both Proxmox and your
Blockbridge installation to syslog at `LOG_INFO` level.  You can see the logs
with `journalctl -f | grep blockbridge:`.

---

PROXMOX STORAGE PRIMITIVES
==========================

Proxmox offers multiple interfaces for storage management.

 * The GUI offers storage management scoped to the context of virtual machine.
 * The [pvesm](https://pve.proxmox.com/pve-docs/pvesm.1.html) command provides
   granular storage management for specific node.
 * The [qm](https://pve.proxmox.com/pve-docs/qm.1.html) command allows for VM
   specific volume management.
 * The [pvesh](https://pve.proxmox.com/pve-docs/pvesh.1.html) API tool provides
   fine-grained storage and VM management, and can operate on any node in your
   Proxmox cluster. To see the available resources, check out the [browsable
   api viewer](https://pve.proxmox.com/pve-docs/api-viewer/)

For additional detail and for topics not covered in this guide, head over to the
[Proxmox VE Documentation Index](https://pve.proxmox.com/pve-docs/).

Device Naming Specification
---------------------------

Proxmox does not maintain internal state about storage devices or
connectivity.  In practice, this means that **Proxmox relies on device naming to
know which devices are associated with virtual machines and how those device
are connected to the virtual storage controller.**  The general device name
format is as follows:

```
Device Filename Specification:
vm-<vmid>-disk-<unique-id>

<vmid>: <integer> (100 - N)
Specify owner VM

<disk-id>: <integer> (1 - N)
Unique naming of disk files
```

{% include tip.html content="Interfaces that accept device filenames do not
thoroughly validate naming. We advise you to stick rigorously to the format
described above." %}

Show Storage Pools
------------------

Proxmox supports multiple pools of storage. This flexibility allows for
optimization of storage resources based on requirements.  With Blockbridge, you
can offer different classes of storage.  For example, one pool can be
IOPS-limited, while another can impose quality-of-service with strict performance
guarantees.

Not all Proxmox storage pools allow for shared access. As such, the interfaces
that you use to view storage pools are scoped to a node. When working with
shared storage types, such as Blockbridge, each node will return its own view
of the storage, consistent with the other nodes' views.


### PVESM

Show available storage types on the local node:

```
$ pvesm status
Name                      Type  Status      Total      Used  Available       %
backup                     pbs  active   65792536   7402332   55018432  11.25%
local                      dir  active    7933384   6342208    1168472  79.94%
shared-block-gp    blockbridge  active  268435456  83886080  184549376  31.25%
shared-block-iops  blockbridge  active  268435456  33669120  234766336  12.54%
shared-file             cephfs  active   59158528    995328   58163200   1.68%
```

### PVESH

Show available storage types on proxmox-1

```
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

You can enumerate volumes stored in a storage pool using the GUI, `pvesm`, and `pvesh` tools.

{% include tip.html content="Blockbridge is shared storage. You can enumerate
the contents of a storage pool from any node in your Proxmox Cluster." %}

### GUI

To generate a list of all volumes in a storage pool, we recommend `Folder View`. To see devices connected to a specific virtual machine, select the VM from the primary navigation plane. Then select `Hardware`.

To see a list of all devices in the storage pool, select a storage pool from
the Storage folder in the primary navigation plane (all nodes have a consistent
view of storage.) Then select VM Disks.

### PVESM

```
pvesm list <storage> [--vmid <integer>]
```

| Parameter |  Format  | Description                                 |
| --------- | :------: | ------------------------------------------- |
| storage   |  string  | Storage pool identifier from `pvesm status` |
| vmid      | integer  | Optional Virtual machine owner ID           |

**Example**

List all volumes from the shared-block-iops pool.

```
$ pvesm list shared-block-iops
Volid                              Format  Type             Size VMID
shared-block-iops:vm-101-disk-0    raw     images    34359738368 101
shared-block-iops:vm-101-disk-1    raw     images    42949672960 101
shared-block-iops:vm-101-disk-2    raw     images    34359738368 101
shared-block-iops:vm-101-state-foo raw     images     4819255296 101
shared-block-iops:vm-10444-disk-1  raw     images    34359738368 10444
shared-block-iops:vm-2000-disk-0   raw     images      117440512 2000
```

List volumes of VM 101 stored in the shared-block-iops pool.
```
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


Show volumes from the shared-block-iops pool:

```
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

List volumes of VM 101 that are stored in the shared-block-iops pool:

```
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

Allocate a 10G volume for VMID 100 from the general purpose performance pool.

```
$ pvesm alloc shared-block-gp 100 vm-100-disk-1 10G
successfully created 'shared-block-gp:vm-100-disk-1'
```

{% include tip.html content="Proxmox allows you to allocate volumes for VMIDs
that do not exist.  You must specify a name that conforms to the name
specification. Failure to do so may result in an error such as `illegal name '101-vm-disk-2' - should be 'vm-10444-*'`." %}

### PVESH

```
pvesh create <api_path> -vmid <vmid> -filename <filename> -size <size>
```

**Arguments**

Volume management with `pvesh` is node-relative. However, Blockbridge's shared
storage permits uniform access to storage from all Proxmox nodes. You are free
to execute allocation requests against any cluster member.  The volume will be
available globally.

| Parameter |  Format  | Description                                                      |
| --------- | :------: | ---------------------------------------------------------------- |
| api_path  |  string  | `/nodes/{node}/storage/{storage}/content`                        |
| node      |  string  | Any pve node listed in the output of `pvesh get /nodes`          |
| storage   |  string  | Storage pool identifier from `pvesh get /storage`                     |
| vmid      | integer  | Virtual machine owner ID                                         |
| filename  |  string  | See: [Device Naming Specification](#device-naming-specification) |
| size      | \d+[MG]? | Default: KiB (1024). Other Suffixes: M (MiB, 1024K) and G (GiB, 1024M) |

**Example**

Allocate a 10G volume for VMID 100 from the general purpose performance pool.

```
$ pvesh create /nodes/proxmox-1/storage/shared-block-gp/content -vmid 100 -filename vm-100-disk-1 -size 10G
shared-block-gp:vm-100-disk-1
```

Delete A Volume
-----------------

You can use either `pvesm` or `pvesh` commands to delete a volume. It may appear as though the tools use inconsistent terminology. However, keep in mind that `pvesh` is submitting a `DELETE` HTTP request to the resource URL.

{% include note.html content="You can delete a volume that is attached to a VM. Failure to detach before release results in a stale attachment: a VM reference to storage that no longer exists. You can remove the stale attachment with the [Detach command](#detach a volume)." %}

{% include tip.html content="The delete operation with Blockbridge automatically performs an instantaneous secure-erase." %}

{% include tip.html content="Blockbridge is shared storage. You can execute the delete operation against any node in your Proxmox cluster." %}

### PVESM

```
pvesm free <volume> --storage <storage>
```

| Parameter | Format | Description               |
| --------- | :----: | ------------------------- |
| volume    | string | Name of volume to destroy |
| storage   | string | Storage pool identifier   |

**Example**

Destroy a volume allocated from the general purpose performance pool.

```
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

Destroy a volume allocated from the general purpose performance pool.

```
$ pvesh delete /nodes/proxmox-1/storage/shared-block-gp/content/vm-100-disk-1
Removed volume 'shared-block-gp:vm-100-disk-1'
```

Attach A Volume
-----------------

An attachment is effectively a VM configuration reference to a storage device. An attachment describes how a storage device is connected to a VM and how the guest OS sees it. The attach operation is principally a VM operation.

{% include tip.html content="Proxmox considers storage devices that are allocated, but not attached, as `unused`." %}

{% include tip.html content="The `attach` and `detach` commands are essential primitives required to move a disk between virtual machines." %}

{% include warning.html content="Use these low-level commands with extra caution; it's possible to accidentally attach the same device multiple times." %}

### GUI

The GUI allows you to `attach` devices from the `Hardware` list that are identified as `Unused`. Select an `Unused` disk from the `Hardware` table and click the `Edit` button. Assign a `Bus` and `Device` number. Then `Add` the device to the VM.

{% include tip.html content="You may need to execute `qm rescan --vmid <vmid>` on the Proxmox node that owns the VM, if you suspect that an unused device is missing." %}

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

Attach device vm-100-disk-1 to VM 100.

```
$ qm set 100 --scsihw virtio-scsi-pci --scsi1 shared-block-gp:vm-100-disk-1
update VM 100: -scsi1 shared-block-gp:vm-100-disk-1 -scsihw virtio-scsi-pci
```

{% include tip.html content="Although Blockbridge is a shared storage type, the Proxmox `qm` command must be executed on the home node of the VM." %}

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

Attach device vm-100-disk-1 to VM 100.

```
$ pvesh create /nodes/proxmox-1/qemu/100/config -scsihw virtio-scsi-pci -scsi1 shared-block-gp:vm-100-disk-1
update VM 100: -scsi1 shared-block-gp:vm-100-disk-1 -scsihw virtio-scsi-pci
```

{% include tip.html content="You can perform an attach operation using the `pvesh` command while operating on any node in your Proxmox cluster." %}

Detach A Volume
-----------------

The detach operation updates the configuration of a VM to remove references to
a storage device. If the VM is running, the device will disappear from the
guest. Detach is a non-destructive operation.  It does not overwrite or release
storage.

{% include note.html content="The Proxmox interfaces use inconsistent terminology for this operation across management interfaces. The `detach` in the GUI is synonymous with `unlink` in `pvesh` and `qm`." %}

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

Unlink the scsi1 device from VM 100.

```
$ qm unlink 100 --idlist scsi1
update VM 100: -delete scsi1
```

{% include tip.html content="You can display a list of storage devices attached to a VM using the `qm config <VMID>` command." %}

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

Unlink the scsi1 device from VM 100.

```
$ pvesh set /nodes/proxmox-1/qemu/100/unlink -idlist scsi1
update VM 100: -delete scsi1
```

{% include tip.html content="You can display a list of storage devices attached to a VM using `pvesh get /nodes/<node>/qemu/<vmid>/config`." %}

Resize A Volume
-----------------

The resize operation extends the logical address space of a storage device. Reducing the size of a device is not permitted by Proxmox. The resize operation can only execute against devices that are attached to a VM.

{% include tip.html content="If you need to extend a filesystem, resizing the underlying storage device is only one step of many. See the Proxmox Wiki for [Resize disks](https://pve.proxmox.com/wiki/Resize_disks) for additional information on partition management, LVM, and guest specific considerations." %}

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

Extend the device attached to scsi1 of VM 100 by 1GiB.

```
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

Extend the device attached to scsi1 of VM 100 by 1GiB.

```
$ pvesh set /nodes/proxmox-1/qemu/100/resize -disk scsi1 -size +1G
```

Create A Snapshot
-----------------

Snapshots provide a recovery point for a virtual machine's state,
configuration, and data. Proxmox orchestrates snapshots via QEMU and backend
storage providers. When you snapshot a Proxmox VM that uses virtual disks
backed by Blockbridge, your disk snapshots are thin, they complete instantly,
and they avoid copy-on-write (COW) performance penalties.

{% include note.html content="If multiple devices are attached to a single VM, Proxmox will snapshot each active device. Devices that are detached (i.e., `unused`) are ignored." %}

### GUI

In the `Snapshots` panel for the VM, click `Take Snapshot`. The duration of the operation depends on whether VM state is preserved.

{% include tip.html content="Closing the dialog does not terminate the operation. It will continue to operate in the background." %}

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

Take a snapshot of VM 100, including RAM.

```
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

Take a snapshot of VM 100, including RAM.

```
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

Gracefully delete the snapshot snap1 of VM 100.

```
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

Gracefully Delete the snapshot snap1 of VM 100.

```
pvesh delete /nodes/proxmox-1/qemu/100/snapshot/snap1
```
