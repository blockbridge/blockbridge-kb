---
layout: page
title: Installing a Custom TLS Key and Certificate
description: Follow this procedure to install your organization's web certificate in the Blockbridge Controlplane.
permalink: /guide/custom-certs/index.html
keywords: security,ssl,certificate
toc: false
---

This document describes how to install your organization's web certificate on a
Blockbridge Controlplane, enabling secure authentication of your clients
with the Blockbridge Web UI, API and command line tools.

Copy private key and certificate files
--------------------------------------

To begin, locate your certificate and private key files. If your CA supplied you
with an intermediate certificate, you’ll need that as well.

* **Ensure all files are PEM-encoded.**
* Copy the certificate to the `/etc/pki/tls/certs` directory.
* If you have an intermediate certificate, place it in `/etc/pki/tls/certs` as well.
* Copy the private key to the `/etc/pki/tls/private` directory.
* Ensure the certificate and key files are owned by root: `chown root <filename>`.
* Set the mode to `600` for all certificate and key files: `chmod 600 <filename>`.  The files must not be readable by group or world.

{% include note.html content="The certificate and key files must be present
on **both** `cm1` and `cm2` cluster members." %}

Create a custom Apache configuration file
-----------------------------------------

Copy the configuration directives from the [Apache Configuration
Template](#apache-configuration-template) section below into a new file named
`zz-blockbridge-tls.conf`. Replace the following placeholders with information
appropriate to your installation:

* `FQDN` - The fully-qualifiied domain name (as specified in your TLS
  certificate). Be sure to fill in your FQDN in both VirtualHost directives.
* `CERT_PATH` - The full path to your certificate file.
* `INTERMEDIATE_CERT_PATH` - The full path to your CA-provided intermediate
  certificate file, if you have one. If you’ve got an intermediate certificate,
  be sure to uncomment the `SSLCertificateChainFile` directive.
* `PRIVATE_KEY_PATH` - The full path to your private key file.

Install the custom Apache configuration file
--------------------------------------------

Copy your newly created `zz-blockbridge-tls.conf` file into
`/etc/httpd/conf.d` on each primary cluster member.

Reload Apache’s configuration
-----------------------------

Confirm which cluster member is running services with `blockbridge cluster
status`. On the active member, reload the apache configuration with `systemctl
reload httpd`.


Apache Configuration Template
-----------------------------

{% include note.html
content="Download the configuration file here: [zz-blockbridge-tls.conf](./zz-blockbridge-tls.conf)" %}

```
<VirtualHost *:443>
    ServerName FQDN

    ServerAdmin admin@blockbridge.com
    DocumentRoot /bb/www/html
    ErrorLog /bb/www/logs/error_log
    CustomLog /bb/www/logs/access_log common
    ProxyRequests off

    # by default, proxy all traffic to the API adapter
    SSLProxyEngine On
    SSLProxyCheckPeerCN off
    SSLProxyCheckPeerExpire off
    ProxyPass /api https://127.0.0.1:9000/api retry=0 timeout=300
    ProxyPassReverse /api https://127.0.0.1:9000/api

    # ssl configuration
    SSLEngine on
    SSLProtocol ALL -SSLv2 -SSLv3
    SSLCipherSuite ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS
    SSLHonorCipherOrder on
    SSLCertificateFile CERT_PATH
    # SSLCertificateChainFile INTERMEDIATE_CERT_PATH
    SSLCertificateKeyFile PRIVATE_KEY_PATH

    <IfModule mod_authz_core.c>
        SSLProxyCheckPeerName off
        <Directory *>
            Require all granted
        </Directory>
        <Proxy *>
        Require all granted
        </Proxy>
    </IfModule>

    <IfModule !mod_authz_core.c>
        <Directory *>
            Order deny,allow
            Allow from all
        </Directory>
        <Proxy *>
            Order deny,allow
            Allow from all
        </Proxy>
    </IfModule>

    <IfModule mod_expires.c>
        <DirectoryMatch "^/bb/www/html/assets">
            <filesMatch "-[a-f0-9]{24,}\.(png|css|html|gif|js)$">
                # Use of ETag is discouraged when Last-Modified is present
                Header unset ETag
                FileETag None
                # RFC says only cache for 1 year
                ExpiresActive On
                ExpiresDefault "access plus 1 year"
            </filesMatch>
        </DirectoryMatch>
    </IfModule>

    <IfModule mod_deflate.c>
        <Directory "/bb/www/html/assets">
            SetOutputFilter DEFLATE
            AddOutputFilterByType DEFLATE application/javascript
        </Directory>
    </IfModule>
</VirtualHost>

<VirtualHost *:80>
RewriteEngine On
RewriteCond %{HTTPS} !on
RewriteRule ^(.*)$ https://FQDN%{REQUEST_URI}
</VirtualHost>
```
