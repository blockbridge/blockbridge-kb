---
layout: page
title: Using Blockbridge Storage at FDCservers
description: A guided introduction to accessing Blockbridge storage
permalink: /guide/fdcservers/index.html
keywords: fdcservers,blockbridge,bare metal
toc: false
---

This document describes how to get started with Blockbridge storage at
FDCservers.

Provision Dedicated Storage
-------------------------------------

If you've already purchased storage, skip to the next section.

...

(Q: do we have a way to supply information to the customer once the complex has
been provisioned? Can we point them to something in their FDCservers account
that would let them access their API endpoint/credentials?)

Install Blockbridge Tools
-------------------------------------

(Note: We should update the Windows CLI package to use Ruby 2.6; The windows CLI
build seems to be busted, likely due to inadvertently making use of features
from a later Ruby version. Or something else. Either way, we should update so
it's not relying on a no-longer-supported version of ruby. Maybe there's even a
better way to bundle the windows CLI with ruby. YUP THERE IS:
[https://github.com/larsch/ocra] -- but perhaps this doesn't matter a lot for
FDCservers... unless we want to support people running Windows. in which case,
there probably ought to be separate Linux and Windows guides.)

Head over to the [https://www.blockbridge.com/tools/](Blockbridge Tools) page
and follow the instructions for your operating system. If your operating system
isn't supported, please contact us at support@blockbridge.com and we'll do our
best to get you going.

Verify you've successfully installed the tools using the `bb version` command:

```
$ bb version
== blockbridge-cli version 5.0.0-1403
build time            2020-10-15 19:30:03 +0000
api library           1.1.0
util library          1.2.1 (fs-inspection)
ruby version          2.6.6 (x86_64-linux)
os release            CentOS Linux release 7.4.1708 (Core)
```

Initial Setup
-----------------------------

After the tools are installed, authenticate to the Blockbridge storage
management API. Enter `fdcservers.blockbridge.com` as your default management
host.

When prompted, enter your Blockbridge administrative access token. Your
credentials are available in your FDCservers customer portal.

```
$ bb auth login
Enter a default management host: fdcservers.blockbridge.com
Authenticating to https://fdcservers.blockbridge.com/api

Enter user or access token: 0/hIY8bs3Bfun/Hx1T2tL2kCz5F....UpYVuzcF0+Q
Detected access token; checking token status: VALID.

== Authenticated as user admin@customer.
```

Once you've successfully authenticated, take a look at your virtual storage
services using the `bb vss list` command:

```
$ bb vss list
label [1]      serial               size       size limit  status
-------------  -------------------  ---------  ----------  ------
us-east        VSS1862194C40E55F2C  0b         32TiB       online
us-west        VSS1862194C40E57ECB  0b         8TiB        online
```

You should see one service for each storage complex subscription.

Provision a Disk
-------------------

Let's allocate an 8TiB disk for PostgreSQL from the `us-east` virtual storage service:

```
bb disk create --vss us-east --capacity 8TiB --label postgres
== Created disk: postgres (DSK1962194C437A5389)

== Virtual disk: postgres (DSK1962194C437A5389)
label                 postgres
serial                DSK1962194C437A5389
created               2020-10-22 15:42:29 -0400
status                online
vss                   us-east (VSS1862194C402CBB5D)
capacity              8.0TiB
encryption            aes128-xts
vault                 unlocked
tags                  -none-
```

Host Attach
-------------------

Next, attach the disk and create an XFS filesystem on it:

```
$ bb host attach -d us-east/postgres
================================================================
us-east/postgres attached (read-write) to myserver-1 as /dev/sdb
================================================================

$ sudo mkfs -t xfs /dev/sdb
meta-data=/dev/sdb               isize=512    agcount=32, agsize=67108863 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2147483616, imaxpct=5
         =                       sunit=1      swidth=32 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=521728, version=2
         =                       sectsz=512   sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

Finally, let's mount the filesystem:

```
$ sudo mount /dev/sdb /mnt
$ df -h /mnt
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb        8.0T   34M  8.0T   1% /mnt
```

Inspecting Attached Storage
----------------------------

The disk attachement status can be inspected using the Blockbridge tools, as
well as the usual Linux tools for managing attached block devices:

```
$ bb host info
== Localhost: myserver-1
Hostname              myserver-1
Initiator Name        iqn.1994-05.com.redhat:38902ee0cd98

== Disks attached to myserver-1
disk [1]                        capacity  paths  transport  mode        device
----------------------------    --------  -----  ---------  ----------  --------
postgres (DSK1962194C437A5389)  8.0TiB    1      TCP/IP     read-write  /dev/sdb
```

```
$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk
└─sda1   8:1    0  40G  0 part /
sdb      8:16   0   8T  0 disk /mnt
```

Host Detach
-------------------

To wrap up, we'll unmount the XFS filesystem and detach the postgres disk:

```
$ sudo umount /mnt
$ bb host detach -d us-east/postgres
==============================================
us-east/postgres detached from host myserver-1
==============================================
```

Next Steps
----------

* Persistent attachments.
* Snapshots? clones?
* Transport security? (this is made more complicated by the fact that persistent
  attachements don't work when paired with transport security. Yet.)
