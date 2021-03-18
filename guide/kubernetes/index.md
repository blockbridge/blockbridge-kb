---
layout: page
title: KUBERNETES CSI STORAGE GUIDE
description: A guide for installing and configuring Blockbridge storage for Kubernetes.
permalink: /guide/kubernetes/index.html
keywords: kubernetes containers K8s
toc: false
---

Blockbridge provides a Container Storage Interface
([CSI](https://github.com/container-storage-interface/spec)) driver to deliver
persistent, secure, multi-tenant, cluster-accessible storage for
[Kubernetes](https://kubernetes-csi.github.io/docs/).  This guide describes how
to deploy Blockbridge as the storage backend for Kubernetes containers.

If you've configured other Kubernetes storage drivers before, you may want to
start with the **[Quickstart](#quickstart)** section. The rest of the guide has
detailed information about features, driver configuration options and
troubleshooting.

REQUIREMENTS & VERSIONS
=======================

Supported Versions
------------------

Blockbridge supports Kubernetes version 1.14. 

| Component                             | Version |
| ------------------------------------  | ------- |
| Blockbridge                           | 5.1     |
| Blockbridge K8s Driver                | 2.0.0   | 
| Kubernetes                            | 1.14    |
| CSI (container storage) Specification | 1.0.0   |

Supported Features
------------------

* Dynamic volume provisioning
* Automatic volume failover and mobility across the cluster
* Integration with RBAC for multi-namespace, multi-tenant deployments
* Quality of Service
* Encryption in-flight for control (always) and data (optional)
* Encryption at rest
* Multiple Storage Classes provide programmable, deterministic storage characteristics

Supported K8s Environments
--------------------------

* Rancher 2.4+
* Mirantis Kubernetes Engine 3.1+ (formerly Docker EE)

Requirements
------------

The following minimum requirements must be met to use the Blockbridge driver in Kubernetes:

* Kubernetes 1.14+.
* `--allow-privileged` flag must be set to true for the Kubernetes API server.
* [MountPropagation must be
  enabled](https://kubernetes.io/docs/concepts/storage/volumes/#mount-propagation)
  (default to true since version 1.10).
* If you use Docker, the Docker daemon of the cluster nodes [must allow shared
  mounts](https://kubernetes.io/docs/concepts/storage/volumes/#configuration).
  
See [CSI Deploying](https://kubernetes-csi.github.io/docs/deploying.html) for
more information.







QUICKSTART
==========

This is a brief guide on how to install and configure the Blockbridge
Kubernetes driver.  In this section, you will:

1. Create a Blockbridge account for your Kubernetes storage.
1. Create an authentication token for the Kubernetes driver.
1. Define a secret in Kubernetes with the token and the Blockbridge API host.
1. Deploy the Kubernetes driver.

Many of these topics have more information available by selecting the
information **&#9432;** links next to items where they appear.


Blockbridge Configuration
-------------------------

These steps use the containerized Blockbridge CLI utility to create an account
and an authorization token.

1. **Set `BLOCKBRIDGE_API_HOST` to point to your Blockbridge API endpoint.**

    ```
    $ export BLOCKBRIDGE_API_HOST=blockbridge.mycompany.example
    ```

2. **Use the containerized CLI to create the account.**

    ```
    $ docker run --rm -it -e BLOCKBRIDGE_API_HOST docker.io/blockbridge/cli:latest-alpine bb --no-ssl-verify-peer account create --name kubernetes
    ```

3. **When prompted, authenticate as the `system` user.**

    ```
    Authenticating to https://blockbridge.mycompany.example/api

    Enter user or access token: system
    Password for system: ....
    Authenticated; token expires in 3599 seconds.
    ```

4. **Use the containerized CLI to create the auth token.**

    ```
    $ export BLOCKBRIDGE_API_HOST=blockbridge.mycompany.example
    $ export BLOCKBRIDGE_API_SU=kubernetes
    $ docker run --rm -it -e BLOCKBRIDGE_API_HOST -e BLOCKBRIDGE_API_SU docker.io/blockbridge/cli:latest-alpine bb --no-ssl-verify-peer authorization create --notes 'csi-blockbridge driver access'
    ```

5. **Again, authenticate as the `system` user.**

    ```
    Authenticating to https://blockbridge.mycompany.example/api

    Enter user or access token: system
    Password for system:
    Authenticated; token expires in 3599 seconds.
    ```

6. **Set the `BLOCKBRIDGE_API_KEY` environment variable to the new token.**

    ```
    $ export BLOCKBRIDGE_API_KEY="1/Nr7qLedL/P0KXxbrB8+jpfrFPBrNi3X+8H9BBwyOYg/mvOot50v2vA"
    ```


Kubernetes Configuration
------------------------

The following steps install and configure the Blockbridge Kubernetes driver on
your cluster.  Your session must already be authenticated with your Kubernetes
cluster to proceed.

1. **Create a file with the definition of a _secret_ for the Blockbridge API.**

    ```
    $ cat > secret.yml <<- EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: blockbridge
      namespace: kube-system
    stringData:
      api-url: "https://${BLOCKBRIDGE_API_HOST}/api"
      access-token: "$BLOCKBRIDGE_API_KEY"
      ssl-verify-peer: "false"
    EOF
    ```

2. **Create the secret in Kubernetes.**

    ```
    $ kubectl create -f ./secret.yml
    ```

3. **Check that the secret exists.**

    ```
    $ kubectl -n kube-system get secrets blockbridge
    NAME          TYPE      DATA      AGE
    blockbridge   Opaque    3         2m
    ```

4. **Deploy the Blockbridge driver.**

    ```
    $ kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/csi/v2.0.0/csi-blockbridge.yaml
    ```

5. **Check that the driver is running.**

    ```
    $ kubectl -n kube-system get pods -l role=csi-blockbridge
    NAME                                    READY     STATUS    RESTARTS   AGE
    csi-blockbridge-controller-0            3/3       Running   0          6s
    csi-blockbridge-node-4679b              2/2       Running   0          5s
    ```

CONFIGURATION & DEPLOYMENT
==========================

This section discusses how to configure the Blockbridge Kubernetes driver in
detail.


Linked Blockbridge Account
--------------------------

The Blockbridge driver creates and maintains its storage under a tenant account
on your Blockbridge installation.

The driver is configured with two pieces of information: the API endpoint and
the authentication token.

| configuration | description |
| :----         | :----       |
| BLOCKBRIDGE_API_URL | Blockbridge controlplane API endpoint URL specified as `https://hostname.example/api` |
| BLOCKBRIDGE_API_KEY | Blockbridge controlplane access token

The API endpoint is specified as a URL pointing to the Blockbridge
controlplane's API. The access token authenticates the driver with the
Blockbridge controlplane, in the context of the specified account.


{% include note.html content="This guide assumes that the Blockbridge
controlplane is running and a system password has been set. For help setting up
the Blockbridge controlplane, please contact [Blockbridge
Support](mailto:support@blockbridge.com)." %}


### Account Creation

Use the containerized Blockbridge CLI to create the account.

```
    $ export BLOCKBRIDGE_API_HOST=blockbridge.mycompany.example
    $ docker run --rm -it -e BLOCKBRIDGE_API_HOST docker.io/blockbridge/cli:latest-alpine bb --no-ssl-verify-peer account create --name kubernetes
```

When prompted, then authenticate to the Blockbridge controlplane as the `system` user.

```
    Authenticating to https://blockbridge.mycompany.example/api

    Enter user or access token: system
    Password for system: ....
    Authenticated; token expires in 3599 seconds.

```

Validate that the account has been created.

```
    == Created account: kubernetes (ACT0762194C40656F03)

    == Account: kubernetes (ACT0762194C40656F03)
    name                  kubernetes
    label                 kubernetes
    serial                ACT0762194C40656F03
    created               2018-11-19 16:15:15 +0000
    disabled              no
```


Authorization Token
-------------------

Blockbridge supports revokable persistent authorization tokens.  This section
demonstrates how to create a persistent authorization token in the freshly
created `kubernetes` account suitable for use as authentication for the driver.

{% include note.html content="Although Blockbridge supports password-based
authentication, tokens are far simpler to use in this context.  It's easier to
revoke a token than change a password." %}

To create the token, first authenticate as the `system` user.  Then use the
containerized Blockbridge CLI tool with the `BLOCKBRIDGE_API_SU` environment
variable to create a persistent authorization in the `kubernetes` account.

```
    $ export BLOCKBRIDGE_API_HOST=blockbridge.mycompany.example
    $ export BLOCKBRIDGE_API_SU=kubernetes
    $ docker run --rm -it -e BLOCKBRIDGE_API_HOST -e BLOCKBRIDGE_API_SU docker.io/blockbridge/cli:latest-alpine bb --no-ssl-verify-peer authorization create --notes 'csi-blockbridge driver access'
```

Once again, authenticate using the `system` username and password.

```
    Authenticating to https://blockbridge.mycompany.example/api

    Enter user or access token: system
    Password for system: 
    Authenticated; token expires in 3599 seconds.
```

This creates the authorization and displays the access token.

```
    == Created authorization: ATH4762194C4062668E

    == Authorization: ATH4762194C4062668E
    serial                ATH4762194C4062668E
    account               kubernetes (ACT0762194C40656F03)
    user                  kubernetes (USR1B62194C40656FBD)
    enabled               yes
    created at            2018-11-19 11:15:47 -0500
    access type           online
    token suffix          ot50v2vA
    restrict              auth
    enforce 2-factor      false

    == Access Token
    access token          1/Nr7qLedL/P0KXxbrB8+jpfrFPBrNi3X+8H9BBwyOYg/mvOot50v2vA

    *** Remember to record your access token!
```

Make a note of the displayed access token somewhere safe. Set the environment
variable to `BLOCKBRIDGE_API_KEY` to use in the forthcoming steps to install
the driver.

```
    $ export BLOCKBRIDGE_API_KEY="1/Nr7qLedL/P0KXxbrB8+jpfrFPBrNi3X+8H9BBwyOYg/mvOot50v2vA"
```

Driver Installation
-------------------

Here's how to install the Blockbridge driver in your Kubernetes cluster.

### Authenticate with Kubernetes

First, ensure your session is authenticated to your Kubernetes cluster. Running
`kubectl version` should show a version for both the client and server
successfully.

```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.7", GitCommit:"1dd5338295409edcfff11505e7bb246f0d325d15", GitTreeState:"clean", BuildDate:"2021-01-13T13:23:52Z", GoVersion:"go1.15.5", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"20", GitVersion:"v1.20.4", GitCommit:"e87da0bd6e03ec3fea7933c4b5263d151aafd07c", GitTreeState:"clean", BuildDate:"2021-02-18T16:03:00Z", GoVersion:"go1.15.8", Compiler:"gc", Platform:"linux/amd64"}
```

{% include note.html content="Setting up `kubectl` authentication is beyond the
scope of this guide.  Please refer to the specific instructions for the
Kubernetes service or installation you are using." %}

### Create a Secret

Next, create a secret containing both the Blockbridge API endpoint URL and access
token.

{% include note.html content="While control traffic is always encrypted, we
specify here to disable peer certificate verification using the
`ssl-verify-peer` flag. This setting implicitly trusts the default controlplane
self-signed certificate. Configuring certificate verification, including
specifying custom-supplied CA certificates, is beyond the scope of this
guide. Please contact [Blockbridge Support](mailto:support@blockbridge.com) for
more information." %}

Use `BLOCKBRIDGE_API_HOST` and `BLOCKBRIDGE_API_KEY` with the correct values
for the Blockbridge controlplane, and the access token you created earlier in
the **kubernetes** account.  Here's how to do it with a "here" document that
expands the variables:

```
    $ cat > secret.yml <<- EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: blockbridge
      namespace: kube-system
    stringData:
      api-url: "https://${BLOCKBRIDGE_API_HOST}/api"
      access-token: "$BLOCKBRIDGE_API_KEY"
      ssl-verify-peer: "false"
    EOF
```

Verify that the contents look correct.

```
    $ cat secret.yml
    apiVersion: v1
    kind: Secret
    metadata:
      name: blockbridge
      namespace: kube-system
    stringData:
      api-url: "https://blockbridge.mycompany.example/api"
      access-token: "1/Nr7qLedL/P0KXxbrB8+jpfrFPBrNi3X+8H9BBwyOYg/mvOot50v2vA"
      ssl-verify-peer: "false"
```

Next, use `secret.yml` to create the secret in Kubernetes.

```
    $ kubectl create -f ./secret.yml
    secret "blockbridge" created
```

Finally, ensure the secret exists in the `kube-system` namespace.

```
    $ kubectl -n kube-system get secrets blockbridge
    NAME          TYPE      DATA      AGE
    blockbridge   Opaque    3         2m
```

### Deploy the Blockbridge Driver

Deploy the Blockbridge Driver as a DaemonSet / StatefulSet using `kubectl`.

```
    $ kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/csi/v2.0.0/csi-blockbridge.yaml
```

If everything was created successfully, the command output should look like
this, with all lines ending in `created`.

```
    csidriver.storage.k8s.io/csi.blockbridge.com created
    storageclass.storage.k8s.io/blockbridge-gp created
    storageclass.storage.k8s.io/blockbridge-tls created
    statefulset.apps/csi-blockbridge-controller created
    serviceaccount/csi-blockbridge-controller-sa created
    clusterrole.rbac.authorization.k8s.io/csi-blockbridge-provisioner-role created
    clusterrolebinding.rbac.authorization.k8s.io/csi-blockbridge-provisioner-binding created
    clusterrole.rbac.authorization.k8s.io/csi-blockbridge-attacher-role created
    clusterrolebinding.rbac.authorization.k8s.io/csi-blockbridge-attacher-binding created
    daemonset.apps/csi-blockbridge-node created
    serviceaccount/csi-blockbridge-node-sa created
    clusterrole.rbac.authorization.k8s.io/csi-blockbridge-node-driver-registrar-role created
    clusterrolebinding.rbac.authorization.k8s.io/csi-blockbridge-node-driver-registrar-binding created
```

For reference, the Blockbridge CSI Driver is deployed using the [recommended
mechanism](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/storage/container-storage-interface.md#recommended-mechanism-for-deploying-csi-drivers-on-kubernetes) of deploying CSI drivers on Kubernetes.

### Ensure the Driver is Operational

Finally, check that the driver is up and running.

```
    $ kubectl -n kube-system get pods -l role=csi-blockbridge
    NAME                                    READY     STATUS    RESTARTS   AGE
    csi-blockbridge-controller-0            3/3       Running   0          6s
    csi-blockbridge-node-4679b              2/2       Running   0          5s
```


Storage Classes
---------------

The Blockbridge driver comes with a default "general purpose" StorageClass
named `blockbridge-gp`.  This is the **default** StorageClass for dynamic
provisioning of storage volumes. It provisions using the default Blockbridge
storage template configured in the Blockbridge controlplane.

There are a variety of additional storage class configuration options available,
including:

1. Using transport encryption (tls).
2. Using a custom tag-based query.
3. Using a named service template.
4. Using explicitly specified provisioned IOPS.

There are several additional example storage classes in
`csi-storageclass.yaml`. You can download, edit, and apply these storage
classes as needed.

```
    $ curl -OsSL https://get.blockbridge.com/kubernetes/deploy/csi/v2.0.0/csi-storageclass.yaml
    $ cat csi-storageclass.yaml
    ... [output trimmed] ...
    ---
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: blockbridge-gp
      namespace: kube-system
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: csi.blockbridge.com
    allowVolumeExpansion: true
```

```
    $ kubectl apply -f ./csi-storageclass.yaml
    storageclass.storage.k8s.io "blockbridge-gp" configured
```


Testing
-------

This section has a few basic tests you can use to validate that your
Blockbridge driver is working properly.

### Create a Volume

This verifies that Blockbridge storage volumes are now available via Kubernetes
persistent volume claims (PVC).

To test this out, create a PersistentVolumeClaim. It will dynamically provision a
volume in Blockbridge and make it accessible to applications.

```
    $ kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/examples/csi-pvc.yaml
```
```
    persistentvolumeclaim "csi-pvc-blockbridge" created
```

Alternatively, download the example volume yaml, modify it as needed, and apply.

```
    $ curl -OsSL https://get.blockbridge.com/kubernetes/deploy/examples/csi-pvc.yaml
```
```
    $ cat csi-pvc.yaml
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: csi-pvc-blockbridge-example
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
      storageClassName: blockbridge-gp
```
```
    $ kubectl apply -f ./csi-pvc.yaml
```
```
    persistentvolumeclaim "csi-pvc-blockbridge" created
```

Use `get pvc csi-pvc-blockbridge` to check that the PVC was created
successfully.

```
    $ kubectl get pvc csi-pvc-blockbridge
```
```
    NAME                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
    csi-pvc-blockbridge   Bound    pvc-6cb93ab2-ec49-11e8-8b89-46facf8570bb   5Gi        RWO            blockbridge-gp   4s
```

### Create a Pod

This test creates a Pod (application) that uses the PVC just created.  When you
create the Pod, it attaches the volume, then formats and mounts it, making it
available to the specified application.

Create the application.

```
    $ kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/examples/csi-app.yaml
```
```
    pod "blockbridge-demo" created
```

Alternatively, download the application yaml, modify as needed, and apply.

```
    $ curl -OsSL https://get.blockbridge.com/kubernetes/deploy/examples/csi-app.yaml
```
```
    $ cat csi-app.yaml
    ---
    kind: Pod
    apiVersion: v1
    metadata:
      name: blockbridge-demo
    spec:
      containers:
        - name: my-frontend
          image: busybox
          volumeMounts:
          - mountPath: "/data"
            name: my-bb-volume
          command: [ "sleep", "1000000" ]
        - name: my-backend
          image: busybox
          volumeMounts:
          - mountPath: "/data"
            name: my-bb-volume
          command: [ "sleep", "1000000" ]
      volumes:
        - name: my-bb-volume
          persistentVolumeClaim:
            claimName: csi-pvc-blockbridge
```

```
    $ kubectl apply -f ./csi-app.yaml
```
```
    pod "blockbridge-demo" created
```

Verify that the pod is running successfully.

```
    $ kubectl get pod blockbridge-demo
```
```
    NAME               READY     STATUS    RESTARTS   AGE
    blockbridge-demo   2/2       Running   0          13s
```

### Write Data From the Pod

Inside the app container, write data to the mounted volume.

```
    $ kubectl exec -ti blockbridge-demo -c my-frontend /bin/sh
```
```
    / # df /data
    Filesystem           1K-blocks      Used Available Use% Mounted on
    /dev/blockbridge/2f93beb2-61eb-456b-809e-22e27e4f73cf
                           5232608     33184   5199424   1% /data

    / # touch /data/hello-world
    / # exit
```
```
    $ kubectl exec -ti blockbridge-demo -c my-backend /bin/sh
```
```
    / # ls /data
    hello-world
```







TROUBLESHOOTING
===============

App Stuck in ContainerCreating
------------------------------

When the application is stuck in ContainerCreating, check to see if the mount
has failed.

### Symptom

Check the app status.

```
$ kubectl get pod/blockbridge-demo
NAME               READY   STATUS              RESTARTS   AGE
blockbridge-demo   0/2     ContainerCreating   0          20s

$ kubectl describe pod/blockbridge-dmo
Events:
  Type     Reason                  Age   From                            Message
  ----     ------                  ----  ----                            -------
  Normal   Scheduled               10s   default-scheduler               Successfully assigned default/blockbridge-demo to kubelet.localnet
  Normal   SuccessfulAttachVolume  10s   attachdetach-controller         AttachVolume.Attach succeeded for volume "pvc-71c37e84-b302-11e9-a93f-0242ac110003"
  Warning  FailedMount             1s    kubelet, kubelet.localnet       MountVolume.MountDevice failed for volume "pvc-71c37e84-b302-11e9-a93f-0242ac110003" : rpc error: code = Unknown desc = runtime_error: /etc/iscsi/initiatorname.iscsi not found; ensure 'iscsi-initiator-utils' is installed.
```

### Resolution

* Ensure the host running the kubelet has iSCSI client support installed on the host/node.
* For CentOS/RHEL, install the `iscsi-initiator-utils` package on the host running the kubelet.

```
    yum install iscsi-initiator-utils
```

* For Ubuntu, install the `open-iscsi-utils` package on the host running the kubelet.

```
    apt install open-iscsi-utils
```
    
* Delete/re-create the application pod to retry.


Provisioning Unauthorized
-------------------------

In this failure mode, provisioning fails with an "unauthorized" message.

### Symptom

Check the PVC describe output.

```
    $ kubectl describe pvc csi-pvc-blockbridge
```

Provisioning failed due to "unauthorized" because the authorization access token is not valid. Ensure the correct access token is entered in the secret.

```
      Warning  ProvisioningFailed    6s (x2 over 19s)  csi.blockbridge.com csi-provisioner-blockbridge-0 2caddb79-ec46-11e8-845d-465903922841  Failed to provision volume with StorageClass "blockbridge-gp": rpc error: code = Internal desc = unauthorized_error: unauthorized: unauthorized
```
 
### Resolution

* Edit `secret.yml` and ensure correct access token and API URL are set.
* delete secret: `kubectl delete -f secret.yml`
* create secret: `kubectl create -f secret.yml`
* remove old configuration:
   * `kubectl delete -f https://get.blockbridge.com/kubernetes/deploy/examples/csi-pvc.yaml`
   * `kubectl delete -f https://get.blockbridge.com/kubernetes/deploy/csi/v2.0.0/csi-blockbridge.yaml`
* re-apply configuration:
   * `kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/csi/v2.0.0/csi-blockbridge.yaml`
   * `kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/examples/csi-pvc.yaml`


Provisioning Storage Class Invalid
----------------------------------

Provisioning fails with an "invalid storage class" error.

### Symptom
Check the PVC describe output:
```
    $ kubectl describe pvc csi-pvc-blockbridge
```

Provisioning failed because the storage class specified was invalid.
```
      Warning  ProvisioningFailed  7s (x3 over 10s)  persistentvolume-controller  storageclass.storage.k8s.io "blockbridge-gp" not found
```

### Resolution

Ensure the StorageClass exists with the same name.

```
    $ kubectl get storageclass blockbridge-gp
    Error from server (NotFound): storageclasses.storage.k8s.io "blockbridge-gp" not found
```

* If it doesn't exist, then create the storageclass.

```
    $ kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/csi/v1.0.0/csi-storageclass.yaml
```

* Alternatively, download and edit the desired storageclass.

```
    $ curl -OsSL https://get.blockbridge.com/kubernetes/deploy/csi/v1.0.0/csi-storageclass.yaml
    $ edit csi-storageclass.yaml
    $ kubectl -f apply ./csi-storageclass.yaml
```

In the background, the PVC continually retries.  Once the above changes are
complete, it will pick up the storage class change.

```
    $ kubectl get pvc
    NAME                    STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
    csi-pvc-blockbridge     Bound     pvc-6cb93ab2-ec49-11e8-8b89-46facf8570bb   5Gi        RWO            blockbridge-gp     4s
```

App Stuck in Pending
--------------------

One of the causes for an application stuck in pending is a missing Persistent
Volume Claim (PVC).

### Symptom

The output of `get pod` show that the app is stuck in pending.

```
    $ kubectl get pod blockbridge-demo
    NAME               READY     STATUS    RESTARTS   AGE
    blockbridge-demo   0/2       Pending   0          14s
```

Use `describe pod` to reveal more information.  In this case, the PVC is not
found.

```
    $ kubectl describe pod blockbridge-demo

    Events:
      Type     Reason            Age                From               Message
      ----     ------            ----               ----               -------
      Warning  FailedScheduling  12s (x6 over 28s)  default-scheduler  persistentvolumeclaim "csi-pvc-blockbridge" not found
```

### Resolution

Create the PVC if necessary and ensure that it's valid.  First, validate that
it's missing.

```
    $ kubectl get pvc csi-pvc-blockbridge
    Error from server (NotFound): persistentvolumeclaims "csi-pvc-blockbridge" not found
```

If it's missing, create it.

```
    $ kubectl apply -f https://get.blockbridge.com/kubernetes/deploy/examples/csi-pvc.yaml
persistentvolumeclaim "csi-pvc-blockbridge" created
```

In the background, the application retries automatically and succeeds in
starting.

```
    $ kubectl describe pod blockbridge-demo
      Normal   Scheduled               8s  default-scheduler                  Successfully assigned blockbridge-demo to aks-nodepool1-56242131-0
      Normal   SuccessfulAttachVolume  8s  attachdetach-controller            AttachVolume.Attach succeeded for volume "pvc-5332e169-ec4f-11e8-8b89-46facf8570bb"
      Normal   SuccessfulMountVolume   8s  kubelet, aks-nodepool1-56242131-0  MountVolume.SetUp succeeded for volume "default-token-bx8b9"
```
