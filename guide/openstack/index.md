---
layout: page
title: BLOCKBRIDGE OPENSTACK STORAGE GUIDE
description: Configure the Blockbridge Cinder Volume Driver
permalink: /guide/openstack/index.html
keywords: openstack cinder
toc: false
---

This guide provides technical details for deploying OpenStack with Blockbridge
iSCSI storage using the Blockbridge Cinder Volume driver.

Most readers will want to start with the Quickstart section. The rest of the
guide has detailed information about features, driver configuration options and
troubleshooting.

Supported Versions
------------------

This guide covers the
[2.0.0](https://github.com/blockbridge/blockbridge-cinder/releases/tag/v2.0.0)
release of the Blockbridge volume driver.

The 2.0.0 release has been qualified with the following OpenStack releases:

  * Victoria
  * Ussuri

Additionally, this release is supported with the following Blockbridge releases:

  * 5.1.0
  * 4.4.14

Quickstart
==========

For simplicity, we'll be configuring the volume driver in _single tenant_ mode.
In single tenant mode there is a one-to-one correspondance between a Cinder
back-end and a Blockbridge account. To read more about the other ways of
configuring Blockbridge, skip ahead to the [Deployment & Management] section.

The quickstart also assumes there's only one OpenStack node running the Cinder
Volume services. If you've got more than one, pick one so you can follow along.

Installing the Driver
---------------------

The Blockbridge Cinder driver consists of a single python source file. We're
currently in the process of including the driver in the upstream OpenStack
cinder distribution; until then, RPM packages are available for CentOS 7 and 8.

The driver must be installed on all OpenStack nodes running the cinder-volume
service.

For CentOS 7, install the el7 package:

    yum install -y https://github.com/blockbridge/blockbridge-cinder/releases/download/v2.0.0/python3-blockbridge_cinder-2.0.0-14.el7.noarch.rpm

For CentOS 8, install the el8 package:

    yum install -y https://github.com/blockbridge/blockbridge-cinder/releases/download/v2.0.0/python3-blockbridge_cinder-2.0.0-14.el78.noarch.rpm

For assistance with other Linux distributions, contact <support@blockbridge.com>.

Blockbridge Configuration
-------------------------

First, we'll create a tenant account on the Blockbridge backend. Log in to the
management node. Confirm you're running a supported release using `blockbridge
version` command:

    # blockbridge version
    Blockbridge Shell
    =================
    version:   5.1.0
    release:   6130.1
    build:     3249
    
    Node Software
    =============
    version:   5.1.0
    release:   6130.1
    branch:    master
    timestamp: Feb 04 2021 14:04:35

Using the `bb` command line utility, create a `bbcinder1` tenant account. Start by
authenticating as the `system` user:

    $ bb -kH localhost auth login
    Authenticating to https://localhost/api
    
    Enter user or access token: system
    Password for system:
    Authenticated; token expires in 3599 seconds.
    
    == Authenticated as user system.

Next, create the `bbcinder1` account and authenticate as the new tenant:

    $ bb -kH localhost account create --name bbcinder1
    == Created account: bbcinder1 (ACT0762194C407FBCF4)
    
    == Account: bbcinder1 (ACT0762194C407FBCF4)
    name                  bbcinder1
    label                 bbcinder1
    serial                ACT0762194C407FBCF4
    created               2021-03-10 17:11:35 -0500
    disabled              no
    
    $ bb -kH localhost auth login --su bbcinder1
    Authenticating to https://localhost/api
    
    Enter user or access token: system
    Password for system:
    Acquiring access token for bbcinder1.
    Authenticated; token expires in 3599 seconds.
    
    == Authenticated as user bbcinder1.

Finally, create a persistent authorization to use for the cinder volume driver
API access:

    $ bb -kH localhost authorization create --notes 'cinder volume driver api access'
    == Created authorization: ATH4762194C413F7FD0
    
    == Authorization: ATH4762194C413F7FD0
    notes                 cinder volume driver api access
    serial                ATH4762194C413F7FD0
    account               bbcinder1 (ACT0762194C407FBCF4)
    user                  bbcinder1 (USR1B62194C407FBEBD)
    enabled               yes
    created at            2021-03-10 17:12:28 -0500
    access type           online
    token suffix          lMlB2wLA
    restrict              auth
    enforce 2-factor      false
    
    == Access Token
    access token          1/j2JUTZQdum2HnO76HbF9adhol0ucgXDataE6tXcV7U8PeQlMlB2wLA
    
    *** Remember to record your access token!

Make note of the displayed access token; if you lose it, you'll have to create
another persistent authorization.

OpenStack Configuration
-----------------------

On your OpenStack Cinder node, configure a new backend by adding a named
configuration group to the `/etc/cinder/cinder.conf` file. Set the
`blockbridge_api_host` to the DNS name or IP address of the Blockbridge
management node. If you've got a clustered management installation, be sure to
use a cluster-managed VIP, otherwise cinder won't be able to communicate with
the backend after service failover. For `blockbridge_auth_token`, use the access
token generated in the previous step.

    [bbcinder1]
    volume_backend_name = bbcinder1
    blockbridge_pools = pool:
    blockbridge_api_host = blockbridge-storage
    blockbridge_auth_token = 1/j2JUTZQdum2HnO76HbF9adhol0ucgXDataE6tXcV7U8PeQlMlB2wLA
    blockbridge_tenant_mode = single
    blockbridge_ssl_verify_peer = False

While not recommended for production, to keep things simple we've disabled peer
certificate verification.

You'll also need to add `bbcinder1` to the `enabled_backends` list in the
`[DEFAULT]` group:

    [DEFAULT]
    enabled_backends=lvm,bbcinder1

IMPORTANT: If your `cinder.conf` doesn't currently have an `enabled_backends`
setting _and_ you have existing cinder volumes hosted on this node, you'll need
to update your existing volumes' `host` value. To see how this is done, read the
OpenStack documentation for [configuring multiple storage back
ends](https://docs.openstack.org/cinder/latest/admin/blockstorage-multi-backend.html).

Note that even though we've used `bbcinder1` for our configuration group name
and the `volume_backend_name`, they don't have to match. The `enabled_backends`
is a list of group names, _not_ of `volume_backend_name` values. Be sure to
restart the cinder-volume service after editing the `cinder.conf` configuration
file.

The `volume_backend_name` is Cinder's internal volume type identifier. To expose
a volume type to users, so they may create volumes with a given backend, the
internal backend name needs to be mapped to a public volume type.

First, create the volume type:

    openstack --os-username admin --os-tenant-name admin volume type create blockbridge
   
Next, map the volume type to its corresponding `volume_backend_name`:
```
    openstack --os-username admin --os-tenant-name admin volume type set blockbridge \
      --property volume_backend_name=bbcinder1
```

Architecture reference
======================

Control paths
-------------
The Blockbridge driver is packaged with the core distribution of OpenStack. Operationally, it executes in the context of the Block Storage service. The driver communicates with an OpenStack-specific API provided by the Blockbridge EPS platform. Blockbridge optionally communicates with Identity, Compute, and Block Storage services.

Block storage API
-----------------
Blockbridge is API driven software-defined storage. The system implements a native HTTP API that is tailored to the specific needs of OpenStack. Each Block Storage service operation maps to a single back-end API request that provides ACID semantics. The API is specifically designed to reduce, if not eliminate, the possibility of inconsistencies between the Block Storage service and external storage infrastructure in the event of hardware, software or data center failure.

Extended management
-------------------
OpenStack users may utilize Blockbridge interfaces to manage replication, auditing, statistics, and performance information on a per-project and per-volume basis. In addition, they can manage low-level data security functions including verification of data authenticity and encryption key delegation. Native integration with the Identity Service allows tenants to use a single set of credentials. Integration with Block storage and Compute services provides dynamic metadata mapping when using Blockbridge management APIs and tools.

Attribute-based provisioning
----------------------------
Blockbridge organizes resources using descriptive identifiers called attributes. Attributes are assigned by administrators of the infrastructure. They are used to describe the characteristics of storage in an application-friendly way. Applications construct queries that describe storage provisioning constraints and the Blockbridge storage stack assembles the resources as described.

Any given instance of a Blockbridge volume driver specifies a query for resources. For example, a query could specify '+ssd +10.0.0.0 +6nines -production iops.reserve=1000 capacity.reserve=30%'. This query is satisfied by selecting SSD resources, accessible on the 10.0.0.0 network, with high resiliency, for non-production workloads, with guaranteed IOPS of 1000 and a storage reservation for 30% of the volume capacity specified at create time. Queries and parameters are completely administrator defined: they reflect the layout, resource, and organizational goals of a specific deployment.

Supported operations
--------------------
Create, delete, clone, attach, and detach volumes
Create and delete volume snapshots
Create a volume from a snapshot
Copy an image to a volume
Copy a volume to an image
Extend a volume
Get volume statistics

Supported protocols
-------------------
Blockbridge provides iSCSI access to storage. A unique iSCSI data fabric is programmatically assembled when a volume is attached to an instance. A fabric is disassembled when a volume is detached from an instance. Each volume is an isolated SCSI device that supports persistent reservations.

Configuration
=============

Create an authentication token
------------------------------
Whenever possible, avoid using password-based authentication. Even if you have created a role-restricted administrative user via Blockbridge, token-based authentication is preferred. You can generate persistent authentication tokens using the Blockbridge command-line tool as follows:

```
$ bb -H bb-mn authorization create --notes "OpenStack" --restrict none
Authenticating to https://bb-mn/api

Enter user or access token: system
Password for system:
Authenticated; token expires in 3599 seconds.

== Authorization: ATH4762894C40626410
notes                 OpenStack
serial                ATH4762894C40626410
account               system (ACT0762594C40626440)
user                  system (USR1B62094C40626440)
enabled               yes
created at            2015-10-24 22:08:48 +0000
access type           online
token suffix          xaKUy3gw
restrict              none

== Access Token
access token          1/elvMWilMvcLAajl...3ms3U1u2KzfaMw6W8xaKUy3gw

*** Remember to record your access token!
```

Create volume type
------------------
Before configuring and enabling the Blockbridge volume driver, register an OpenStack volume type and associate it with a volume_backend_name. In this example, a volume type, ‘Production’, is associated with the volume_backend_name ‘blockbridge_prod’:

```
$ cinder type-create Production
$ cinder type-key Production volume_backend_name=blockbridge_prod
```

Specify volume driver
---------------------
Configure the Blockbridge volume driver in /etc/cinder/cinder.conf. Your volume_backend_name must match the value specified in the cinder type-key command in the previous step.

```
volume_driver = cinder.volume.drivers.blockbridge.BlockbridgeISCSIDriver
volume_backend_name = blockbridge_prod
```

Specify API endpoint and authentication
---------------------------------------
Configure the API endpoint and authentication. The following example uses an authentication token. You must create your own as described in Create an authentication token.

```
blockbridge_api_host = [ip or dns of management cluster]
blockbridge_auth_token = 1/elvMWilMvcLAajl...3ms3U1u2KzfaMw6W8xaKUy3gw
```

Specify resource query
----------------------
By default, a single pool is configured (implied) with a default resource query of '+openstack'. Within Blockbridge, datastore resources that advertise the ‘openstack’ attribute will be selected to fulfill OpenStack provisioning requests. If you prefer a more specific query, define a custom pool configuration.

```
blockbridge_pools = Production: +production +qos iops.reserve=5000
```

Pools support storage systems that offer multiple classes of service. You may wish to configure multiple pools to implement more sophisticated scheduling capabilities.

Configuration options
----------------------
Description of BlockBridge EPS volume driver configuration options

| Configuration option = Default value            | Description                                                                        |
|-------------------------------------------------|------------------------------------------------------------------------------------|
| [DEFAULT]                                       |                                                                                    |
| blockbridge_api_host = None                     | (String) IP address/hostname of Blockbridge API.                                   |
| blockbridge_api_port = None                     | (Integer) Override HTTPS port to connect to Blockbridge API server.                |
| blockbridge_auth_password = None                | (String) Blockbridge API password (for auth scheme ‘password’)                     |
| blockbridge_auth_scheme = token                 | (String) Blockbridge API authentication scheme (token or password)                 |
| blockbridge_auth_token = None                   | (String) Blockbridge API token (for auth scheme ‘token’)                           |
| blockbridge_auth_user = None                    | (String) Blockbridge API user (for auth scheme ‘password’)                         |
| blockbridge_default_pool = None                 | (String) Default pool name if unspecified.                                         |
| blockbridge_pools = {'OpenStack': '+openstack'} | (Dict) Defines the set of exposed pools and their associated backend query strings |

Configuration example
---------------------
cinder.conf example file

```
[Default]
enabled_backends = bb_devel bb_prod

[bb_prod]
volume_driver = cinder.volume.drivers.blockbridge.BlockbridgeISCSIDriver
volume_backend_name = blockbridge_prod
blockbridge_api_host = [ip or dns of management cluster]
blockbridge_auth_token = 1/elvMWilMvcLAajl...3ms3U1u2KzfaMw6W8xaKUy3gw
blockbridge_pools = Production: +production +qos iops.reserve=5000

[bb_devel]
volume_driver = cinder.volume.drivers.blockbridge.BlockbridgeISCSIDriver
volume_backend_name = blockbridge_devel
blockbridge_api_host = [ip or dns of management cluster]
blockbridge_auth_token = 1/elvMWilMvcLAajl...3ms3U1u2KzfaMw6W8xaKUy3gw
blockbridge_pools = Development: +development
```

Multiple volume types
---------------------
Volume types are exposed to tenants, pools are not. To offer multiple classes of storage to OpenStack tenants, you should define multiple volume types. Simply repeat the process above for each desired type. Be sure to specify a unique volume_backend_name and pool configuration for each type. The cinder.conf example included with this documentation illustrates configuration of multiple types.

Testing resources
-----------------
Blockbridge is freely available for testing purposes and deploys in seconds as a Docker container. This is the same container used to run continuous integration for OpenStack. For more information visit www.blockbridge.io.
