# Implementation 

## VMs

Each VM instance runs on KVM and is initialized using Cloud-Init with a Debian 12 cloud image. Subsequently, the instances are managed by libvirt and its command-line utilities. The Kubernetes services within each VM are controlled by Systemd.

## TLS

The communication between components in the cluster is protected by TLS. A CA is created as part of the process and  certificates are issued using OpenSSL and deployed in each server. 
The implementation can be found here: scripts/plugins/tls.sh and the configuration template files in this place: extras/tls/


## Design

The script is structured around a core library that handles primary functionalities such as creation and destruction fo clusters, complemented by a suite of plugins that offer customization options for the stack.

### Configuration File (`db.txt`)

The script uses a configuration file named `db.txt` that outlines the components of the cluster and guides the actions necessary for its creation. This file is generated when a new cluster is created using the `new` command and is updated whenever a new worker node is added using the `add` command.

## Structure

### cluster.sh

`cluster.sh` is a command-line script that integrates the cluster management library to offer functionalities such as creation, destruction, startup, and shutdown of clusters, among other options.

### extras

`extras` is a directory that contains configuration templates, OpenSSL config templates, and other support files.

### scripts

- api.sh: This library offers a public API for cluster management.
- controller.sh: Implementation of the api.sh public API.
- Makefile.vm: Makefile that support the creation and destroying of VM.

#### dao

This directory contains the necessary files to access `db.txt`, which guides the cluster creation process. As part of this process, a `cluster.txt` file is created with information about the infrastructure to be deployed. Access to both files is managed by libraries present in this directory.

#### vm

- host.sh: Contains functionality for updating the host files of both the local machine and the cluster's VMs.
- local.sh: Provides services for setting up the local machine.

#### support

This folder contains utilities libraries used by the different parts of the system.

#### plugins

- haproxy.sh: It provides functions to generate haproxy and keepalived configuration files and deploy them on the load balancer VMs.
- kvm.sh: It enables the creation, removal, and administration of virtual machines (VMs).
- net.sh: It includes functionality for configuring new routes for the cluster's virtual machines (VMs).
- tls.sh: It implements the functionality for generating the Certificate Authority (CA), issuing certificates, and deploying them.

