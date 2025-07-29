{
    "apiVersion": "v1",
    "items": [
        {
            "apiVersion": "v1",
            "kind": "Node",
            "metadata": {
                "annotations": {
                    "csi.volume.kubernetes.io/nodeid": "{\"nfs.csi.k8s.io\":\"node-0\"}",
                    "node.alpha.kubernetes.io/ttl": "0",
                    "volumes.kubernetes.io/controller-managed-attach-detach": "true"
                },
                "creationTimestamp": "2025-07-28T21:14:23Z",
                "labels": {
                    "beta.kubernetes.io/arch": "amd64",
                    "beta.kubernetes.io/os": "linux",
                    "kubernetes.io/arch": "amd64",
                    "kubernetes.io/hostname": "node-0",
                    "kubernetes.io/os": "linux"
                },
                "name": "node-0",
                "resourceVersion": "5759",
                "uid": "afc82809-82ec-41b2-93d5-8afa4bbbe2b2"
            },
            "spec": {
                "taints": [
                    {
                        "effect": "NoSchedule",
                        "key": "judge0",
                        "value": "true"
                    }
                ]
            },
            "status": {
                "addresses": [
                    {
                        "address": "192.168.122.8",
                        "type": "InternalIP"
                    },
                    {
                        "address": "node-0",
                        "type": "Hostname"
                    }
                ],
                "allocatable": {
                    "cpu": "2",
                    "ephemeral-storage": "28341994245",
                    "hugepages-1Gi": "0",
                    "hugepages-2Mi": "0",
                    "memory": "1911756Ki",
                    "pods": "110"
                },
                "capacity": {
                    "cpu": "2",
                    "ephemeral-storage": "30753032Ki",
                    "hugepages-1Gi": "0",
                    "hugepages-2Mi": "0",
                    "memory": "2014156Ki",
                    "pods": "110"
                },
                "conditions": [
                    {
                        "lastHeartbeatTime": "2025-07-28T21:47:11Z",
                        "lastTransitionTime": "2025-07-28T21:14:23Z",
                        "message": "kubelet has sufficient memory available",
                        "reason": "KubeletHasSufficientMemory",
                        "status": "False",
                        "type": "MemoryPressure"
                    },
                    {
                        "lastHeartbeatTime": "2025-07-28T21:47:11Z",
                        "lastTransitionTime": "2025-07-28T21:14:23Z",
                        "message": "kubelet has no disk pressure",
                        "reason": "KubeletHasNoDiskPressure",
                        "status": "False",
                        "type": "DiskPressure"
                    },
                    {
                        "lastHeartbeatTime": "2025-07-28T21:47:11Z",
                        "lastTransitionTime": "2025-07-28T21:14:23Z",
                        "message": "kubelet has sufficient PID available",
                        "reason": "KubeletHasSufficientPID",
                        "status": "False",
                        "type": "PIDPressure"
                    },
                    {
                        "lastHeartbeatTime": "2025-07-28T21:47:11Z",
                        "lastTransitionTime": "2025-07-28T21:14:23Z",
                        "message": "kubelet is posting ready status",
                        "reason": "KubeletReady",
                        "status": "True",
                        "type": "Ready"
                    }
                ],
                "daemonEndpoints": {
                    "kubeletEndpoint": {
                        "Port": 10250
                    }
                },
                "images": [
                    {
                        "names": [
                            "docker.io/judge0/judge0@sha256:6b5d6a66aa19a8e878a52ea3c6a560afc1086734d96e2885b561fd5c6018f082",
                            "docker.io/judge0/judge0:1.13.1"
                        ],
                        "sizeBytes": 3297285083
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/nfsplugin@sha256:3cdf324ca24f0900b1f639b1177a939a3d99ba66cec3db1e2ccfb1d52f2ad7f4",
                            "registry.k8s.io/sig-storage/nfsplugin:v4.9.0"
                        ],
                        "sizeBytes": 67031523
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/csi-node-driver-registrar@sha256:e01facb9fb9cffaf52d0053bdb979fbd8c505c8e411939a6e026dd061a6b4fbe",
                            "registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.11.1"
                        ],
                        "sizeBytes": 13697025
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/livenessprobe@sha256:d2a9027a4876e039185e9bef7c61a0142c8ea14e7440860285c34ac73fee4ffb",
                            "registry.k8s.io/sig-storage/livenessprobe:v2.13.1"
                        ],
                        "sizeBytes": 13651774
                    },
                    {
                        "names": [
                            "docker.io/library/busybox@sha256:f85340bf132ae937d2c2a763b8335c9bab35d6e8293f70f606b9c6178d84f42b",
                            "docker.io/library/busybox:latest"
                        ],
                        "sizeBytes": 2156518
                    },
                    {
                        "names": [
                            "registry.k8s.io/pause@sha256:ee6521f290b2168b6e0935a181d4cff9be1ac3f505666ef0e3c98fae8199917a",
                            "registry.k8s.io/pause:3.10"
                        ],
                        "sizeBytes": 320368
                    }
                ],
                "nodeInfo": {
                    "architecture": "amd64",
                    "bootID": "0f0b931a-02da-46a1-9e9d-2dfa07b474f0",
                    "containerRuntimeVersion": "containerd://2.0.2",
                    "kernelVersion": "6.1.0-37-amd64",
                    "kubeProxyVersion": "v1.32.0",
                    "kubeletVersion": "v1.32.0",
                    "machineID": "505285f587ed4746a6a0879934311c4b",
                    "operatingSystem": "linux",
                    "osImage": "Debian GNU/Linux 12 (bookworm)",
                    "systemUUID": "505285f5-87ed-4746-a6a0-879934311c4b"
                },
                "runtimeHandlers": [
                    {
                        "features": {
                            "recursiveReadOnlyMounts": true,
                            "userNamespaces": true
                        },
                        "name": "runc"
                    },
                    {
                        "features": {
                            "recursiveReadOnlyMounts": true,
                            "userNamespaces": true
                        },
                        "name": ""
                    }
                ]
            }
        },
        {
            "apiVersion": "v1",
            "kind": "Node",
            "metadata": {
                "annotations": {
                    "csi.volume.kubernetes.io/nodeid": "{\"nfs.csi.k8s.io\":\"server\"}",
                    "node.alpha.kubernetes.io/ttl": "0",
                    "volumes.kubernetes.io/controller-managed-attach-detach": "true"
                },
                "creationTimestamp": "2025-07-28T21:14:25Z",
                "labels": {
                    "beta.kubernetes.io/arch": "amd64",
                    "beta.kubernetes.io/os": "linux",
                    "kubernetes.io/arch": "amd64",
                    "kubernetes.io/hostname": "server",
                    "kubernetes.io/os": "linux"
                },
                "name": "server",
                "resourceVersion": "6266",
                "uid": "5ed362a5-787a-4d85-975a-80c42e87177f"
            },
            "spec": {},
            "status": {
                "addresses": [
                    {
                        "address": "192.168.122.7",
                        "type": "InternalIP"
                    },
                    {
                        "address": "server",
                        "type": "Hostname"
                    }
                ],
                "allocatable": {
                    "cpu": "2",
                    "ephemeral-storage": "31194261453",
                    "hugepages-1Gi": "0",
                    "hugepages-2Mi": "0",
                    "memory": "3906752Ki",
                    "pods": "110"
                },
                "capacity": {
                    "cpu": "2",
                    "ephemeral-storage": "33847940Ki",
                    "hugepages-1Gi": "0",
                    "hugepages-2Mi": "0",
                    "memory": "4009152Ki",
                    "pods": "110"
                },
                "conditions": [
                    {
                        "lastHeartbeatTime": "2025-07-28T21:50:53Z",
                        "lastTransitionTime": "2025-07-28T21:14:25Z",
                        "message": "kubelet has sufficient memory available",
                        "reason": "KubeletHasSufficientMemory",
                        "status": "False",
                        "type": "MemoryPressure"
                    },
                    {
                        "lastHeartbeatTime": "2025-07-28T21:50:53Z",
                        "lastTransitionTime": "2025-07-28T21:14:25Z",
                        "message": "kubelet has no disk pressure",
                        "reason": "KubeletHasNoDiskPressure",
                        "status": "False",
                        "type": "DiskPressure"
                    },
                    {
                        "lastHeartbeatTime": "2025-07-28T21:50:53Z",
                        "lastTransitionTime": "2025-07-28T21:14:25Z",
                        "message": "kubelet has sufficient PID available",
                        "reason": "KubeletHasSufficientPID",
                        "status": "False",
                        "type": "PIDPressure"
                    },
                    {
                        "lastHeartbeatTime": "2025-07-28T21:50:53Z",
                        "lastTransitionTime": "2025-07-28T21:14:26Z",
                        "message": "kubelet is posting ready status",
                        "reason": "KubeletReady",
                        "status": "True",
                        "type": "Ready"
                    }
                ],
                "daemonEndpoints": {
                    "kubeletEndpoint": {
                        "Port": 10250
                    }
                },
                "images": [
                    {
                        "names": [
                            "ghcr.io/cloudnative-pg/postgresql@sha256:61d2b391e3e324d05edc6c65c555989a7c544ddb72ef271b3abd4a35b57942b1",
                            "ghcr.io/cloudnative-pg/postgresql:17.2"
                        ],
                        "sizeBytes": 224558349
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/nfsplugin@sha256:3cdf324ca24f0900b1f639b1177a939a3d99ba66cec3db1e2ccfb1d52f2ad7f4",
                            "registry.k8s.io/sig-storage/nfsplugin:v4.9.0"
                        ],
                        "sizeBytes": 67031523
                    },
                    {
                        "names": [
                            "quay.io/metallb/speaker@sha256:34e9cc2db6d83ca3ad4d92a6e2eadaf6b78be65621798e90827041749898acc0",
                            "quay.io/metallb/speaker:v0.14.5"
                        ],
                        "sizeBytes": 52754428
                    },
                    {
                        "names": [
                            "docker.io/library/traefik@sha256:a208c74fd80a566d4ea376053bff73d31616d7af3f1465a7747b8b89ee34d97e",
                            "docker.io/library/traefik:v3.0"
                        ],
                        "sizeBytes": 47477952
                    },
                    {
                        "names": [
                            "ghcr.io/zitadel/zitadel@sha256:90dc5231c14cd08781641f49b292356b4e16d2ba8435dd75019e57a861e982f9",
                            "ghcr.io/zitadel/zitadel:v2.67.2"
                        ],
                        "sizeBytes": 41571613
                    },
                    {
                        "names": [
                            "ghcr.io/cloudnative-pg/cloudnative-pg@sha256:a27779ed10853ed607659ff9c7c51ae30b6b6c3ce204f58a2bf54c5d25e0e188",
                            "ghcr.io/cloudnative-pg/cloudnative-pg:1.25.0"
                        ],
                        "sizeBytes": 35267703
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/csi-provisioner@sha256:7b9cdb5830d01bda96111b4f138dbddcc01eed2f95aa980a404c45a042d60a10",
                            "registry.k8s.io/sig-storage/csi-provisioner:v5.0.2"
                        ],
                        "sizeBytes": 30330584
                    },
                    {
                        "names": [
                            "quay.io/metallb/controller@sha256:3f776529447094c8d318baeb4f9efe024cf154859762ec3eefcd878b1fe8a01f",
                            "quay.io/metallb/controller:v0.14.5"
                        ],
                        "sizeBytes": 29213516
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/csi-snapshotter@sha256:2e04046334baf9be425bb0fa1d04c2d1720d770825eedbdbcdb10d430da4ad8c",
                            "registry.k8s.io/sig-storage/csi-snapshotter:v8.0.1"
                        ],
                        "sizeBytes": 28522689
                    },
                    {
                        "names": [
                            "registry.k8s.io/metrics-server/metrics-server@sha256:db3800085a0957083930c3932b17580eec652cfb6156a05c0f79c7543e80d17a",
                            "registry.k8s.io/metrics-server/metrics-server:v0.7.1"
                        ],
                        "sizeBytes": 19478031
                    },
                    {
                        "names": [
                            "docker.io/coredns/coredns@sha256:1eeb4c7316bacb1d4c8ead65571cd92dd21e27359f0d4917f1a5822a73b75db1",
                            "docker.io/coredns/coredns:1.11.1"
                        ],
                        "sizeBytes": 18182961
                    },
                    {
                        "names": [
                            "quay.io/oriedge/k8s_gateway@sha256:7bdbd447c0244b8f89de9cd6f4826ed0ac66c9406fac3a4ac80081020c251c6b",
                            "quay.io/oriedge/k8s_gateway:v0.4.0"
                        ],
                        "sizeBytes": 17450682
                    },
                    {
                        "names": [
                            "docker.io/library/redis@sha256:bb186d083732f669da90be8b0f975a37812b15e913465bb14d845db72a4e3e08",
                            "docker.io/library/redis:7-alpine"
                        ],
                        "sizeBytes": 17241542
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/csi-node-driver-registrar@sha256:e01facb9fb9cffaf52d0053bdb979fbd8c505c8e411939a6e026dd061a6b4fbe",
                            "registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.11.1"
                        ],
                        "sizeBytes": 13697025
                    },
                    {
                        "names": [
                            "registry.k8s.io/sig-storage/livenessprobe@sha256:d2a9027a4876e039185e9bef7c61a0142c8ea14e7440860285c34ac73fee4ffb",
                            "registry.k8s.io/sig-storage/livenessprobe:v2.13.1"
                        ],
                        "sizeBytes": 13651774
                    },
                    {
                        "names": [
                            "docker.io/library/registry@sha256:a3d8aaa63ed8681a604f1dea0aa03f100d5895b6a58ace528858a7b332415373",
                            "docker.io/library/registry:2.8.3"
                        ],
                        "sizeBytes": 10131312
                    },
                    {
                        "names": [
                            "docker.io/library/busybox@sha256:f85340bf132ae937d2c2a763b8335c9bab35d6e8293f70f606b9c6178d84f42b",
                            "docker.io/library/busybox:latest"
                        ],
                        "sizeBytes": 2156518
                    },
                    {
                        "names": [
                            "registry.k8s.io/pause@sha256:ee6521f290b2168b6e0935a181d4cff9be1ac3f505666ef0e3c98fae8199917a",
                            "registry.k8s.io/pause:3.10"
                        ],
                        "sizeBytes": 320368
                    }
                ],
                "nodeInfo": {
                    "architecture": "amd64",
                    "bootID": "4e6f62a6-74f7-493b-9836-c8e1582bb6f9",
                    "containerRuntimeVersion": "containerd://2.0.2",
                    "kernelVersion": "6.1.0-37-amd64",
                    "kubeProxyVersion": "v1.32.0",
                    "kubeletVersion": "v1.32.0",
                    "machineID": "92908a5b7e8f4db3a05f132ec575a642",
                    "operatingSystem": "linux",
                    "osImage": "Debian GNU/Linux 12 (bookworm)",
                    "systemUUID": "92908a5b-7e8f-4db3-a05f-132ec575a642"
                },
                "runtimeHandlers": [
                    {
                        "features": {
                            "recursiveReadOnlyMounts": true,
                            "userNamespaces": true
                        },
                        "name": "runc"
                    },
                    {
                        "features": {
                            "recursiveReadOnlyMounts": true,
                            "userNamespaces": true
                        },
                        "name": ""
                    }
                ]
            }
        }
    ],
    "kind": "List",
    "metadata": {
        "resourceVersion": ""
    }
}
