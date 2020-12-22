---
layout: page
title: Using Blockbridge Storage with Proxmox VE
description: Follow this procedure to install and configure the Blockbridge Proxmox Plugin
permalink: /guide/proxmox/index.html
keywords: proxmox
toc: false
---

## Quickstart

### Install blockbridge-cli

On each Proxmox node, install the cli package. This version is from a special branch with proxmox enhancements/fixes:

```
wget http://zion/shared/josh/blockbridge-cli_5.0.0-1422_amd64.deb
apt install ./blockbridge-cli_5.0.0-1419_amd64.deb
```

### Install blockbridge-proxmox

On each Proxmox node, install the Blockbridge storage plugin:

```
wget http://zion/shared/josh/blockbridge-proxmox_5.0.0-3_all.deb
apt install ./blockbridge-proxmox_5.0.0-3_all.deb
```

### Install optional bits

If you want to use TLS, install stunnel

```
apt install stunnel
```

### Create a persistent authorization for Proxmox use

You know how to do this :)

### Add a blockbridge storage definition

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

## Notes

### Space Reporting (status api call)

The driver currently always reports 1000000000 bytes of storage total with 50%
used. I am not sure what we want to do here... we punted on space reporting for
openstack, but when I did the same thing for proxmox it just considers the
storage to be offline... I keep forgetting about this. Needs some sort of
investigation.

### Logs

The driver logs all incoming API calls with their parameters to syslog at
LOG_INFO level. It also logs the arguments used when executing any `bb`
commands. You can see the logs using `journalctl -f | grep blockbridge:`.

### Driver configuration options

Here's the full dump of driver options from the driver source:

```
api_url => {
    description => "Blockbridge management API URL",
    type => 'string',
},
auth_token => {
    description => "API access token",
    type => 'string',
},
ssl_verify_peer => {
    description => "Enable or disable peer certificate verification",
    type => 'boolean',
},
service_type => {
    description => "Override default service template selection",
    type => 'string',
},
query_include => {
    description => "List of tags to include when provisioning storage",
    type => 'string',
    format => 'string-list',
},
query_exclude => {
    description => "List of tags to exclude when provisioning storage",
    type => 'string',
    format => 'string-list',
},
transport_encryption => {
    description => "Specify transport encryption protocol",
    type => 'string',
    enum => [ 'tls', 'ipsec', 'none' ],
},
multipath => {
    description => "Specify transport encryption protocol",
    type => 'boolean',
}
```
