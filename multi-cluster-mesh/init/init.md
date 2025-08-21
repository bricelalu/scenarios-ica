# Multi-Cluster Service Mesh with Istio

In this scenario, you will learn how to set up and manage Istio service mesh across multiple Kubernetes clusters. This is a critical topic for the **Advanced Scenarios** domain (13% of ICA exam) and represents real-world enterprise deployments.

Multi-cluster service mesh enables:

- **Cross-cluster service discovery** - Services in one cluster can discover and communicate with services in other clusters
- **Unified traffic management** - Apply consistent traffic policies across all clusters
- **Enhanced resilience** - Distribute workloads for high availability and disaster recovery
- **Geographic distribution** - Deploy services closer to users for better performance

## What You'll Learn

By the end of this scenario, you will be able to:

1. Configure a **primary cluster** with Istio control plane
2. Set up a **remote cluster** and establish cross-cluster connectivity
3. Configure **cross-cluster service discovery** using WorkloadEntry
4. Implement **cross-cluster traffic policies** with VirtualService and DestinationRule
5. Set up **network gateways** for cross-cluster communication
6. Troubleshoot multi-cluster mesh connectivity issues

## Architecture Overview

In this scenario:
- **Cluster 1 (Primary)**: Hosts the Istio control plane and discovery services
- **Cluster 2 (Remote)**: Connects to the primary cluster's control plane
- **Cross-Network Gateway**: Enables secure communication between clusters
- **Workload Entries**: Register remote services for discovery

## Prerequisites

- Understanding of Kubernetes networking
- Familiarity with Istio VirtualService and DestinationRule
- Knowledge of service discovery concepts
- Basic understanding of network policies

Let's start by setting up our multi-cluster Istio service mesh!