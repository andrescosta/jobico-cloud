# Introduction

This educational project, inspired by [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), initially began as a set of scripts to automate the guide's processes. Over time, it has evolved into a broader initiative that supports various topologies and integrates several Kubernetes extensions as addons. Despite these enhancements, the project remains a valuable tool for deepening my understanding of the technologies involved, such as Kubernetes and its high availability configurations, Bash scripting, and Linux.

# Technical Overview

The following sections outline the various topologies that the tool can create, based on the different command-line options available. Each subsection provides detailed information on the specific configurations and their corresponding command-line parameters.

## Topologies

### Prerequisites

#### Libraries

- SSH
- OpenSSL
- [Cloud-init](https://cloud-init.io/)
- [KVM](https://ubuntu.com/blog/kvm-hyphervisor): The VMs run on KVM, and KVM along with its dependencies can be installed by running the script [here](https://github.com/andrescosta/jobico-cloud/hacks/deps.sh).
- [Helm](https://helm.sh/): Several add-ons are installed using Helm charts.

#### cloud-init cfg files

Before creating a cluster the cfg files for cloud-init must be created:

```bash
$ ./cluster.sh cfg
```
### Single Control Plane Configuration

```bash
cluster.sh new 
# `new` will create a cluster using the defaults values which are 1 control plane server and 2 nodes.
```

![one cpl](img/onecpl.png)

In this setup, there is one dedicated control plane server managing one or more worker nodes, offering a straightforward configuration often used in small-scale deployments.

### High Availability Configuration

```bash
cluster.sh new --cpl 2 --lb 2
# `--cpl` is used to specify the number of control plane servers to create, in this case 2.
# `--lb` is used to specify the number of load balancers to create, 2 for this example.
```

![ha](img/ha.png)

Also known as HA, this topology features multiple control plane servers and one or more worker nodes, designed to ensure redundancy and fault tolerance in production environments.

### Single Node Configuration

```bash
cluster.sh new --nodes 0
# `new` is the command used to create a new cluster
# --nodes is used to specify the number of worker nodes to create.
```

![zernode](img/zeronode.png)

This topology involves a single server that fulfills both the control plane and worker node roles, providing a basic setup typically used for learning and testing purposes.

## TLS

The communication between components in the cluster is protected by TLS. A CA is created as part of the process and  certificates are issued using OpenSSL and deployed in each server. 
The implementation can be found here: scripts/plugins/tls.sh and the configuration template files in this place: extras/tls/

# Cluster Management

## Creation
Before proceeding with cluster creation, install the dependencies described in this section:

### Command Line

```bash
# Most important options
./cluster.sh new [--nodes n] [--cpl n] [--lb n] [--no-addons] [--post] [--schedulable-server]

# Cluster without worker nodes and one control plane server.
./cluster.sh new --nodes 0

# Cluster with two worker nodes and one control plane server.
./cluster.sh new

# Cluster with two worker nodes and one control plane server that can be also schedulable.
./cluster.sh new --schedulable-server

# HA Cluster with three worker nodes, two control plane servers and two load balancer.
./cluster.sh new --nodes 3 --cpl 2

# HA Cluster with ten worker nodes, five control plane servers and three load balancers.
./cluster.sh new --nodes 10 --cpl 5 --lb 3

# HA Cluster with three worker nodes, two control plane servers and one load balancer. After the construction is completed (all pods Ready), it installs the scripts in the /post directory.
./cluster.sh new --nodes 3 --cpl 2 --post
```
### YAML file

The cluster description can be also specified by in a YAML file to faciliate the automation scripts.

#### Schema

```yaml
cluster:
  node:
    size: [NUMBER OF WORKER NODES]
  cpl:
    schedulable: [true if the server is tainted.]
    size: 0
  addons:
    - dir: []
      list:
      [List of addons]
  services:
    - dir: 
      [List of services]
```
### Examples



## Add nodes

## Status management
## Destroy

# Kubernetes Configuration & Add-Ons

During the cluster creation process, a series of add-ons are installed. To omit the deployment of a specific one, create a file named `disabled` in its directory.
Some add-ons require a locally installed Helm chart for deployment. Please refer to the requirements section for details.


# Addons

- [CoreDNS](https://coredns.io/plugins/kubernetes): It provides cluster wide DNS services.
- [K8s Gateway](https://github.com/ori-edge/k8s_gateway): This component acts as a single external DNS interface into the cluster. It supports Ingress, Service of type LoadBalancer and resources from the Gateway API project.    
- [Metallb](https://metallb.universe.tf/): A network load balancer implementation. The pool of IP address can be configured here: /addons/core/metallb
- [NFS](https://github.com/kubernetes-csi/csi-driver-nfs): This driver allows Kubernetes to access NFS server on Linux node.
- [Traefik](https://traefik.io/traefik/): The Traefik Kubernetes Ingress provider is a Kubernetes Ingress controller. It manages access to cluster services by supporting the Ingress specification.
- [Metrics](https://github.com/kubernetes-sigs/metrics-server): It collects resource metrics from Kubelets and exposes them in Kubernetes apiserver through Metrics API for use by Horizontal Pod Autoscaler and Vertical Pod Autoscaler. It can also be accessed by kubectl top.
- [Distribution Registry](https://distribution.github.io/distribution/): It is a server side application that stores and lets you distribute container images and other content. 
- [Grafana and Prometheus](https://github.com/prometheus-operator/kube-prometheus): It installs a collection of Kubernetes manifests, Grafana dashboards, and Prometheus rules.
- [Dashboard](https://github.com/kubernetes/dashboard): A general purpose, web-based UI for Kubernetes clusters. It allows to manage applications running in the cluster.

# Implementation 

## VMs

Each VM instance runs on KVM and is initialized using Cloud-Init with a Debian 12 cloud image. Subsequently, the instances are managed by libvirt and its command-line utilities. The Kubernetes services within each VM are controlled by Systemd.

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

# Cluster.sh command reference
```
Usage: 
       ./cluster.sh <command> [arguments]
Commands:
          help
          new
          add
          destroy
          addons
          start
          shutdown
          suspend
          resume
          info
          state
          list
          local
          kvm
          cfg
          debug

Additional help: ./cluster.sh help <command>
```
```
Usage: ./cluster.sh new [arguments]
Create the VMs and deploys Kubernetes cluster into them.
The arguments that define how the cluster will be created:
     --nodes n
            Specify the number of worker nodes to be created. The default value is 2. 
     --cpl n
            Specify the number of control planed nodes to be created. The default value is 1. 
     --lb n
            Specify the number of load balancers to be created in case --cpl is greater than 1. The default value is 2. 
     --addons dir_name
            Specify a different directory name for the addons. Default: ./addons
     --no-addons
            Skip the instalation of addons
     --post
            Waits for the cluster to be created and then runs the scripts on the post directory.
     --schedulable-server
            The control plane nodes will be available to schedule pods. The default is false(tainted).
     --dry-run
            Create the dabases, kubeconfigs, and certificates but does not create the actual cluster. This option is useful for debugging.
     --debug [ s | d ]
            Enable the debug mode.
       s: displays basic information.
       d: display advanced information.
```
```
Usage: ./cluster.sh add [arguments]
Add new nodes to the current Kubernetes cluster.
The arguments that define how the cluster will be updated:
     --nodes n
            Specify the number of worker nodes to be added. The default value is 1. 
     --dry-run
            Update the dabases, kubeconfigs, and certificates but does not create the actual cluster. This option is useful for debugging.
     --force
            If new nodes were added previously, this parameter force the execution of this command.
     --debug [ s | d ]
            Enable the debug mode.
       s: displays basic information.
       d: display advanced information.
```
```
Usage: ./cluster.sh destroy
Destroy the Kubernetes cluster and the VMs
```
```
Usage: ./cluster.sh addons [arguments]
Install the addons from the folder ./addons or the one specified by --dir.
```
```
Usage: ./cluster.sh cfg
Create the cloud init cfg files.
```
```
Usage: ./cluster.sh debug
Prints the content of the internal databases using the dao scripts.
```
```
Usage: ./cluster.sh <info|state|list>
Display information about the cluster's VM(s).
```
```
Usage: ./cluster.sh kvm
Install kvm and its dependencies locally.
```
```
Usage: ./cluster.sh <info|state|list>
Display information about the cluster's VM(s).
```
```
Usage: ./cluster.sh local
Prepares the local enviroment. It creates the kubeconfig and installs kubectl.
```
```
Usage: ./cluster.sh start
Starts the cluster's VMs
```
```
Usage: ./cluster.sh <info|state|list>
Display information about the cluster's VM(s).
```
# Possible future areas of work

## Current iteration 

- Improvements to the plugins mechanism
- Performance
- Cloud-Init
- Let's Encrypt

## Refactors 
- Control Plane Kubelet
- Kubeadm
- External Etcd 
