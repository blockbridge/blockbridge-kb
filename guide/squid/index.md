---
layout: page
title: Installing and configuring Squid
description: Follow this procedure to install and configure a Squid Proxy server
permalink: /guide/squid/index.html
keywords: security,proxy,squid
toc: false
---

This document describes how to install and configure the Squid HTTP proxy server
on a CentOS 7 host. This will allow network-isolated Blockbridge nodes to use
various Internet-based support functions. (e.g., remote support, software
update and service alerts.)

Configure network access
------------------------

The proxy host provides internal clients with a means to access the outside world:

* Blockbridge nodes on a restricted subnet must be allowed to connect to the
proxy host.
* The proxy host must be allowed to connect to the Internet.

In this example we'll be assuming the following network topology:

* All internal clients are on the `10.10.10.0/24` network.
* The proxy server's IP address on the private network is `10.10.10.6`.
* The proxy listens for service on the default port of 3128.

Install and enable Squid
------------------------

Using yum, install the `squid` package:

    $ sudo yum install -y squid

Enable and start `squid`:

    $ sudo systemctl enable --now squid

Confirm that the proxy service is running and healthy:

    $ systemctl status squid
    ● squid.service - Squid caching proxy
       Loaded: loaded (/usr/lib/systemd/system/squid.service; enabled; vendor preset: disabled)
       Active: active (running) since Thu 2020-05-28 16:35:49 UTC; 1min 30s ago
      Process: 16517 ExecStart=/usr/sbin/squid $SQUID_OPTS -f $SQUID_CONF (code=exited, status=0/SUCCESS)
      Process: 16511 ExecStartPre=/usr/libexec/squid/cache_swap.sh (code=exited, status=0/SUCCESS)
     Main PID: 16519 (squid)
       CGroup: /system.slice/squid.service
               ├─16519 /usr/sbin/squid -f /etc/squid/squid.conf
               ├─16521 (squid-1) -f /etc/squid/squid.conf
               └─16522 (logfile-daemon) /var/log/squid/access.log
    
    May 28 16:35:49 mcdebug.localnet systemd[1]: Starting Squid caching proxy...
    May 28 16:35:49 mcdebug.localnet squid[16519]: Squid Parent: will start 1 kids
    May 28 16:35:49 mcdebug.localnet squid[16519]: Squid Parent: (squid-1) process 16521 started
    May 28 16:35:49 mcdebug.localnet systemd[1]: Started Squid caching proxy.

Review and Customize Configuration
----------------------------------

Squid's service configuration file is located at `/etc/squid/squid.conf`. While
the CentOS squid package ships with some reasonable defaults, we recommend
reviewing the configuration to make sure it fits with your company and network
policies.

By default, a `localnet` acl permits client access from address ranges typically
used for internal or link-local networks:

    acl localnet src 10.0.0.0/8     # RFC1918 possible internal network
    acl localnet src 172.16.0.0/12  # RFC1918 possible internal network
    acl localnet src 192.168.0.0/16 # RFC1918 possible internal network
    acl localnet src fc00::/7       # RFC 4193 local private network range
    acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines

Add or remove acl entries if the pre-configured `localnet` ACL is too permissive
or doesn't cover your client IP range. For our example, we tighten up the
permitted range of client addresses:

    # acl localnet src 10.0.0.0/8     # RFC1918 possible internal network
    # acl localnet src 172.16.0.0/12  # RFC1918 possible internal network
    # acl localnet src 192.168.0.0/16 # RFC1918 possible internal network
    # acl localnet src fc00::/7       # RFC 4193 local private network range
    # acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines
    acl localnet src 10.10.10.0/24    # Only permit internal client access

The `SSL_ports` and `Safe_ports` ACLs are used to restrict what ports the proxy
is allowed to connect _to_. To proxy Blockbridge software updates and remote
support, you'll need:

    acl SSL_ports port 443
    acl Safe_ports port 80
    acl Safe_ports port 443

Feel free to restrict other ports, as needed.

To specify the port Squid is listening on, use the `http_port` directive. By
default, squid accepts connections on all locally configured IP addresses. We
recommend binding squid's listening port to its internal IP address. This puts
an additional safeguard in place to prevent externally sourced traffic from
reaching the proxy service. The `http_port` directive allows an address to be
specified.

For our example configuration, we bind to the proxy server's address on the
internal subnet. For testing purposes, we also bind to localhost:

    http_port 10.10.10.6:3128
    http_port localhost:3128

After modifying `/etc/squid/squid.conf`, restart the squid service and confirm
that it's running and healthy:

    $ sudo systemctl restart squid
    $ systemctl status squid
    ● squid.service - Squid caching proxy
       Loaded: loaded (/usr/lib/systemd/system/squid.service; enabled; vendor preset: disabled)
       Active: active (running) since Fri 2020-05-29 17:07:34 UTC; 4s ago
      Process: 23097 ExecStop=/usr/sbin/squid -k shutdown -f $SQUID_CONF (code=exited, status=0/SUCCESS)
      Process: 23106 ExecStart=/usr/sbin/squid $SQUID_OPTS -f $SQUID_CONF (code=exited, status=0/SUCCESS)
      Process: 23100 ExecStartPre=/usr/libexec/squid/cache_swap.sh (code=exited, status=0/SUCCESS)
     Main PID: 23108 (squid)
       CGroup: /system.slice/squid.service
               ├─23108 /usr/sbin/squid -f /etc/squid/squid.conf
               ├─23110 (squid-1) -f /etc/squid/squid.conf
               └─23111 (logfile-daemon) /var/log/squid/access.log
    
    May 29 17:07:34 mcdebug.localnet systemd[1]: Starting Squid caching proxy...
    May 29 17:07:34 mcdebug.localnet squid[23108]: Squid Parent: will start 1 kids
    May 29 17:07:34 mcdebug.localnet squid[23108]: Squid Parent: (squid-1) process 23110 started
    May 29 17:07:34 mcdebug.localnet systemd[1]: Started Squid caching proxy.

Verifying Proxy Configuration
-----------------------------

The command line utility `curl` is an easy way to verify your proxy server
configuration. To start with, perform a couple tests from the proxy server
itself. This ensures the service is running and able to reach the Internet.
First test `http` requests:

    $ all_proxy=http://localhost:3128 curl --head -sS http://get.blockbridge.com/install
    HTTP/1.1 200 OK
    [...additional output...]

Next ensure the proxy server handles `https` requests:

    $ all_proxy=http://localhost:3128 curl --head -sS https://get.blockbridge.com/install
    HTTP/1.1 200 Connection established
    [...additional output...]

Finally, repeat the tests from an internal client node, replacing `localhost`
with the proxy server's internal service address:

    $ all_proxy=http://10.10.10.6:3128 curl --head -sS http://get.blockbridge.com/install
    HTTP/1.1 200 OK
    [...additional output...]

    $ all_proxy=http://10.10.10.6:3128 curl --head -sS https://get.blockbridge.com/install
    HTTP/1.1 200 Connection established
    [...additional output...]
