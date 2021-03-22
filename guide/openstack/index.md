---
layout: page
title: OPENSTACK CINDER STORAGE GUIDE
description: A guide to installing and configuring Blockbridge iSCSI storage for OpenStack.
permalink: /guide/openstack/index.html
keywords: openstack cinder
toc: false
---

This guide provides technical details for deploying OpenStack with Blockbridge
iSCSI storage using the Blockbridge Cinder Volume driver.

Most readers will want to start with the **[Quickstart](#quickstart)**
section. The rest of the guide has detailed information about features, driver
configuration options and troubleshooting.

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

---

QUICKSTART
==========

This is a quick reference for installing and configuring the Blockbridge Cinder
driver in single-tenant mode.  We recommend working through the installation in
this order:

1. Install the driver.
2. Configure your Blockbridge installation to permit the driver to connect.
3. Configure the Blockbridge volume type in OpenStack.

Some of these topics have more information available by selecting the
information **&#9432;** links next to items where they appear.


Driver Installation
-------------------

Install the Blockbridge driver on each OpenStack node that will access
Blockbridge volumes.  [**&#9432;**](#cinder-driver)

**For CentOS 7, install the el7 package.**

    yum install -y https://github.com/blockbridge/blockbridge-cinder/releases/download/v2.0.0/python3-blockbridge_cinder-2.0.0-14.el7.noarch.rpm

**For CentOS 8, install the el8 package.**

    yum install -y https://github.com/blockbridge/blockbridge-cinder/releases/download/v2.0.0/python3-blockbridge_cinder-2.0.0-14.el78.noarch.rpm

Blockbridge Configuration
-------------------------

The following steps use the `bb` command-line utility.


1. **Authenticate as the `system` user:** [**&#9432;**](#blockbridge-login)

    ```
    $ bb -kH localhost auth login
    ```

2. **Create the `bbcinder` tenant account:** [**&#9432;**](#account-creation)

    ```
    $ bb -kH localhost account create --name bbcinder
    ```

3. **Log in as the new `bbcinder` tenant, using the "substitute user" switch:** [**&#9432;**](#multi-cloud-tenant-token)

    ```
    $ bb -kH localhost auth login --su bbcinder
    ```

4. **Create a persistent authorization token for the cinder volume driver API access:** [**&#9432;**](#multi-cloud-tenant-token)

    ```
    $ bb -kH localhost authorization create --notes 'cinder volume driver api access'
    ```

*Remember to record the access token!*


OpenStack Configuration
-----------------------

1. **On your OpenStack Cinder node, configure a new backend by adding a named
configuration group to the `/etc/cinder/cinder.conf` file.** [**&#9432;**](#cinder-backend)

    ```
    [bbcinder]
    volume_backend_name = bbcinder
    blockbridge_pools = pool:
    blockbridge_api_host = blockbridge-storage
    blockbridge_auth_token = 1/j2JUTZQdum2HnO76HbF9adhol0ucgXDataE6tXcV7U8PeQlMlB2wLA
    blockbridge_tenant_mode = single
    blockbridge_ssl_verify_peer = False
    ```

2. **Add `bbcinder` to the `enabled_backends` list in the `[DEFAULT]` group:** [**&#9432;**](#cinder-backend)

    ```
    [DEFAULT]
    enabled_backends=lvm,bbcinder
    ```

3. **Restart the cinder-volume service.** [**&#9432;**](#cinder-backend)

    ```
    systemctl restart openstack-cinder-volume
    ```

4. **Create the blockbridge volume type:** [**&#9432;**](#volume-type)

    ```
    openstack --os-username admin --os-tenant-name admin volume type create blockbridge
    ```

5. **Map the volume type to its corresponding `volume_backend_name`:** [**&#9432;**](#volume-type)

    ```
    openstack --os-username admin --os-tenant-name admin volume type set blockbridge \
      --property volume_backend_name=bbcinder
  ```

---

DEPLOYMENT & MANAGEMENT
=======================

This section works through details about how best to deploy Blockbridge in your
OpenStack environment.

Deployment Modes
----------------
When you deploy Blockbridge as a volume backend for OpenStack, you can choose how
to best integrate it with your OpenStack installation.  There are two
deployment modes, which can be mixed and matched: **single-cloud** and
**multi-cloud**.

If you have a single OpenStack cloud, you can integrate it using Blockbridge's
**single-cloud** mode.  In this mode, Blockbridge automatically creates its own
tenant accounts on demand to service your OpenStack users.

In **multi-cloud** mode, you create a Blockbridge account for each of your OpenStack
clouds and define an OpenStack volume backend for that account in the Cinder
configuration for that OpenStack cloud.  You can map the same account into
multiple OpenStack clouds.

With both deployment modes, tenants can log in to Blockbridge to view auditing
and statistics related to their volumes.  In single-cloud mode, tenants use
their OpenStack Keystone credentials to log in.  In multi-cloud mode, they'll
use the credentials from the Blockbridge tenant account.

A single Blockbridge installation can support one OpenStack cloud in
single-cloud mode simultaneously with many OpenStack clouds in multi-cloud
mode.

Cinder Driver
-------------

The Blockbridge Cinder driver consists of a single python source file. We're
currently in the process of including the driver in the upstream OpenStack
cinder distribution; until then, RPM packages are available for CentOS 7 and 8.

The driver must be installed on all OpenStack nodes running the cinder-volume
service.

For CentOS 7, install the el7 package:

```
    yum install -y https://github.com/blockbridge/blockbridge-cinder/releases/download/v2.0.0/python3-blockbridge_cinder-2.0.0-14.el7.noarch.rpm
```

For CentOS 8, install the el8 package:

```
    yum install -y https://github.com/blockbridge/blockbridge-cinder/releases/download/v2.0.0/python3-blockbridge_cinder-2.0.0-14.el78.noarch.rpm
```

For assistance with other Linux distributions, contact <support@blockbridge.com>.


Authentication
--------------

The Blockbridge cinder driver requires a Blockbridge account.  For single-cloud
deployments, the account is an administrative user that includes the
"substitute user" permission.  The driver will `--su` from that admin account
to a tenant's account to work with that tenant's storage.  For multi-cloud
deployments, the tenant's own Blockbridge account is used, and won't need
administrative privileges.

You can use the Blockbridge CLI to create authorization tokens suitable for
cut-and-pasting into `cinder.conf`.  These tokens can be
individually revoked if the need arises.  And, for this reason, we recommend
allocating one for each account on each OpenStack cluster.

{% include note.html content="Although Blockbridge supports password-based
authentication, we don't recommend using it in this context, as the password
must be stored in cleartext on the OpenStack controller." %}

### Blockbridge Login

Log in as the administrative `system` user to a Blockbridge management cluster
using the command-line tool.  Here, the management address is `bb-api`.

```
    $ bb -kH bb-api auth login
    Authenticating to https://bb-api/api
    
    Enter user or access token: system
    Password for system:
    Authenticated; token expires in 3599 seconds.
    
    == Authenticated as user system.
```

### Account Creation

Create a dedicated tenant account (e.g. `bbcinder`) as follows:

```
    $ bb -kH bb-api account create --name bbcinder
    == Created account: bbcinder (ACT0762194C407FBCF4)
    
    == Account: bbcinder (ACT0762194C407FBCF4)
    name                  bbcinder
    label                 bbcinder
    serial                ACT0762194C407FBCF4
    created               2021-03-10 17:11:35 -0500
    disabled              no
```

### Single-Cloud Administrative Token

For single-cloud deployments, create an unrestricted token for the system user
like this: 

```
$ bb -H bb-api authorization create --notes "OpenStack Admin Token" --restrict none
Authenticating to https://bb-api/api

Enter user or access token: system
Password for system:
Authenticated; token expires in 3599 seconds.

== Authorization: ATH4762894C40626410
notes                 OpenStack Admin Token
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

Make note of the displayed access token; if you lose it, you'll have to create
another persistent authorization.

### Multi-Cloud Tenant Token

For tenant accounts in multi-cloud deployments, authenticate as the tenant and
create a token with default options:

```
bb -kH localhost auth login --su bbcinder
... [output trimmed]
bb -kH bb-api authorization create --notes 'Cinder volume driver API access for Cloud-BOS-1'
... [output trimmed]
```

Cinder Backend
--------------

On every OpenStack Cinder node, configure a new backend by adding a named
configuration group to the `/etc/cinder/cinder.conf` file. Set the
`blockbridge_api_host` to the DNS name or IP address of the Blockbridge
management node. If you have a clustered management installation, be sure to
use a cluster-managed VIP, otherwise cinder won't be able to communicate with
the backend after service failover. For `blockbridge_auth_token`, use the
access token generated in the previous step.

    [bbcinder]
    volume_backend_name = bbcinder
    blockbridge_pools = pool: +ssd
    blockbridge_api_host = blockbridge-storage
    blockbridge_auth_token = 1/j2JUTZQdum2HnO76HbF9adhol0ucgXDataE6tXcV7U8PeQlMlB2wLA
    blockbridge_tenant_mode = single
    blockbridge_ssl_verify_peer = False

{% include note.html content="While not recommended for production, to keep
things simple we've disabled peer certificate verification with
`blockbridge_ssl_verify_peer = False`." %}

You'll also need to add `bbcinder` to the `enabled_backends` list in the
`[DEFAULT]` group:

    [DEFAULT]
    enabled_backends=lvm,bbcinder

{% include important.html content="If your `cinder.conf` doesn't currently have an
`enabled_backends` setting _and_ you have existing cinder volumes hosted on
this node, you'll need to update your existing volumes' `host` value. To see
how this is done, read the OpenStack documentation for [configuring multiple
storage back
ends](https://docs.openstack.org/cinder/latest/admin/blockstorage-multi-backend.html)."
%}

Though we've used `bbcinder` for our configuration group name and the
`volume_backend_name`, they don't have to match. The `enabled_backends`
parameter is a list of configuration group names (as specified in square
brackets in `cinder.conf`), _not_ a list of `volume_backend_name` values.  More
information can be found in the [Multiple Volume Types](#multiple-volume-types) section below.

After editing the `cinder.conf` configuration file, restart the cinder-volume
service.

```
    systemctl restart openstack-cinder-volume
```

Volume Type
-----------

The final piece of configuration is to expose a volume type
(e.g. `blockbridge`) to users so that they may create volumes with the
`bbcinder` backend.  (The `volume_backend_name` parameter is Cinder's internal
volume type identifier.)  The process to map this internal parameter to a
public volume type has two steps:

First, create the volume type (here, `blockbridge`):

```
    openstack --os-username admin --os-tenant-name admin volume type create blockbridge
```

And finally, map the volume type to its corresponding `volume_backend_name`:

```
    openstack --os-username admin --os-tenant-name admin volume type set blockbridge \
      --property volume_backend_name=bbcinder
```

Resource Queries
----------------

Each Blockbridge volume backend can include attributes that influence the type
of storage that can be provisioned for the backend.  These are specified in the
`blockbridge_pools` parameter in the backend definition.  For example, a query
could specify `+ssd +10.0.0.0 +6nines -production iops.reserve=1000
capacity.reserve=30%`. This query is satisfied by selecting SSD resources,
accessible on the 10.0.0.0 network, with high resiliency, for non-production
workloads, with guaranteed IOPS of 1000 and a storage reservation for 30% of
the volume capacity specified at create time.

To make this style of attribute-based provisioning work, tag Blockbridge
datastores with the appropriate information.  In the example above, the query
would only provision storage from datastores configured with the `ssd`,
`10.0.0.0`, and `6nines` tags.  It would skip datastores tagged `production`.
The `iops` parameter requires a datastore that supports. IOPS scheduling.

By default, each backend has an implicit `+openstack` query.  Within
Blockbridge, datastores that are tagged `openstack` will be selected to fulfill
OpenStack provisioning requests. If you prefer a more specific query, define a
custom pool configuration.

```
    blockbridge_pools = Production: +production +qos iops.reserve=5000
```

Configuration options
----------------------
Description of Blockbridge EPS volume driver configuration options

| Configuration option = Default value              | Description                                                                        |
|---------------------------------------------------|------------------------------------------------------------------------------------|
| `[DEFAULT]`                                       |                                                                                    |
| `blockbridge_api_host = None`                     | (String) IP address/hostname of Blockbridge API.                                   |
| `blockbridge_api_port = None`                     | (Integer) Override HTTPS port to connect to Blockbridge API server.                |
| `blockbridge_auth_password = None`                | (String) Blockbridge API password (for auth scheme ‘password’)                     |
| `blockbridge_auth_scheme = token`                 | (String) Blockbridge API authentication scheme (token or password)                 |
| `blockbridge_auth_token = None`                   | (String) Blockbridge API token (for auth scheme ‘token’)                           |
| `blockbridge_auth_user = None`                    | (String) Blockbridge API user (for auth scheme ‘password’)                         |
| `blockbridge_default_pool = None`                 | (String) Default pool name if unspecified.                                         |
| `blockbridge_pools = {'OpenStack': '+openstack'}` | (Dict) Defines the set of exposed pools and their associated backend query strings |
| `blockbridge_tenant_mode = multi`                 | (String) Defines the tenant mode.                                                  |

Example cinder.conf
-------------------

```
[Default]
enabled_backends = bb_devel,bb_prod

[bb_prod]
volume_driver = cinder.volume.drivers.blockbridge.BlockbridgeISCSIDriver
volume_backend_name = blockbridge_prod
blockbridge_api_host = [ip or dns of management cluster]
blockbridge_auth_token = 1/elvMWilMvcLAajl...3ms3U1u2KzfaMw6W8xaKUy3gw
blockbridge_pools = Production: +production +qos iops.reserve=5000
blockbridge_tenant_mode = multi

[bb_devel]
volume_driver = cinder.volume.drivers.blockbridge.BlockbridgeISCSIDriver
volume_backend_name = blockbridge_devel
blockbridge_api_host = [ip or dns of management cluster]
blockbridge_auth_token = 1/elvMWilMvcLAajl...3ms3U1u2KzfaMw6W8xaKUy3gw
blockbridge_pools = Development: +development
blockbridge_tenant_mode = single
```


---

REFERENCE
=========

Supported Operations
--------------------

The Blockbridge cinder driver supports the following operations:

| Feature                           | Release |
| --------------------------------- | ------- |
| Create Volume                     | Liberty |
| Delete Volume                     | Liberty |
| Attach Volume                     | Liberty |
| Detach Volume                     | Liberty |
| Extend Volume                     | Liberty |
| Create Snapshot                   | Liberty |
| Delete Snapshot                   | Liberty |
| Create Volume from Snapshot       | Liberty |
| Create Volume from Volume (clone) | Liberty |
| Create Image from Volume          | Liberty |
| Thin Provisioning                 | Liberty |
| Volume Migration (host assisted)  | Ussuri  |

Supported protocols
-------------------

Blockbridge uses iSCSI for data access.  Our Cinder driver communicates
directly with our transactional API to build tenant-isolated SAN fabrics on
demand.

Version History
---------------

* June, 2015: version 1.0.0 driver, Kilo release.
* October, 2015: version 1.1.0 driver, Liberty release.
* March, 2021: version 2.0.0 driver, compatible with Victoria and Ussuri.

