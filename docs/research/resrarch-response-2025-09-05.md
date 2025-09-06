# Product Requirements Document (PRD): Low-Latency Performance Workshop on AWS

**Date:** 2025-09-05

**Version:** 1.0

## 1. Introduction

This document outlines the product requirements for the Low-Latency Performance Workshop on Amazon Web Services (AWS). The workshop is designed to provide Solutions Architects with a hands-on experience in deploying and managing high-performance, low-latency solutions on OpenShift Container Platform running on AWS. The primary goal is to demonstrate how to achieve predictable, microsecond-level response times for both containerized applications and virtualized workloads using OpenShift Virtualization.

This PRD focuses specifically on the AWS deployment of the workshop, leveraging AWS-native features and services to provide a seamless and efficient learning experience. A separate PRD will cover the deployment on Bare-Metal/KVM environments.

## 2. Target Audience

The primary audience for this workshop is Solutions Architects (SAs) and Senior Solutions Architects (SSAs) who are responsible for designing and implementing high-performance computing solutions for their customers. The workshop is also suitable for developers, DevOps engineers, and infrastructure administrators who want to learn about low-latency performance tuning on OpenShift.

## 3. Workshop Goals and Objectives

The main goals of the workshop are to:

*   **Educate**: Teach participants the fundamental concepts of low-latency performance and how they apply to OpenShift and AWS.
*   **Demonstrate**: Showcase the capabilities of OpenShift and AWS for achieving high-performance, low-latency workloads.
*   **Enable**: Provide participants with the hands-on skills and knowledge to design, deploy, and manage their own low-latency solutions.

Upon completion of the workshop, participants will be able to:

*   Understand the key factors that affect latency in a containerized environment.
*   Configure OpenShift for low-latency performance using the Node Tuning Operator and Performance Profiles.
*   Deploy and manage low-latency virtual machines using OpenShift Virtualization.
*   Leverage AWS-specific features, such as EC2 metal instances and Enhanced Networking, to optimize performance.
*   Use `kube-burner` to measure and validate the performance of their applications.




## 4. Workshop Modules

The workshop will be divided into the following modules, each focusing on a specific aspect of low-latency performance tuning on OpenShift and AWS:

### Module 1: Introduction to Low-Latency on OpenShift and AWS

*   **1.1: What is Low-Latency and Why it Matters**: An overview of low-latency concepts, use cases, and the importance of predictable performance.
*   **1.2: OpenShift and AWS for High-Performance Computing**: A discussion of how OpenShift and AWS can be used together to build high-performance, low-latency solutions.
*   **1.3: Introduction to Kubernetes Operators**: An introduction to the concept of Kubernetes Operators and their role in automating the management of complex applications.

### Module 2: Core Performance Tuning on OpenShift

*   **2.1: Node Tuning Operator and Performance Profiles**: A deep dive into the Node Tuning Operator and how to use Performance Profiles to configure low-latency settings.
*   **2.2: CPU Isolation and Management**: Techniques for isolating CPUs and managing CPU resources to reduce jitter and improve performance.
*   **2.3: HugePages and Memory Tuning**: How to use HugePages and other memory tuning techniques to optimize memory performance.
*   **2.4: SMT and NUMA Considerations**: A discussion of the impact of Simultaneous Multi-Threading (SMT) and Non-Uniform Memory Access (NUMA) on latency.

### Module 3: OpenShift Virtualization for Low-Latency VMs

*   **3.1: Introduction to OpenShift Virtualization**: An overview of OpenShift Virtualization and its capabilities for running virtual machines on OpenShift.
*   **3.2: Deploying Low-Latency Virtual Machines**: A hands-on lab on how to deploy and configure virtual machines for low-latency performance.
*   **3.3: SR-IOV for High-Performance Networking**: How to use SR-IOV to provide high-performance networking for virtual machines.

### Module 4: AWS-Specific Performance Tuning

*   **4.1: Leveraging EC2 Metal Instances**: How to use EC2 metal instances to get bare-metal performance in the cloud.
*   **4.2: Enhanced Networking with ENA and EFA**: An overview of AWS Enhanced Networking and how to use the Elastic Network Adapter (ENA) and Elastic Fabric Adapter (EFA) to improve network performance.
*   **4.3: Automating Deployments with AWS-Native Tools**: How to use tools like CloudFormation and Terraform to automate the deployment of the workshop environment on AWS.

### Module 5: Performance Validation with `kube-burner`

*   **5.1: Introduction to `kube-burner`**: An overview of `kube-burner` and its capabilities for performance and scale testing.
*   **5.2: The "Test -> Change -> Re-test" Workflow**: A hands-on lab on how to use `kube-burner` to measure and validate the performance of the workshop applications.
*   **5.3: Analyzing Performance Metrics**: How to analyze the metrics collected by `kube-burner` to identify performance bottlenecks and opportunities for improvement.




## 5. Technical Requirements

This section outlines the technical requirements for the AWS deployment of the Low-Latency Performance Workshop.

### 5.1. AWS Account and Prerequisites

*   An AWS account with sufficient permissions to create and manage EC2 instances, VPCs, IAM roles, and other required resources.
*   The AWS CLI installed and configured with the necessary credentials.
*   A domain name registered in Amazon Route 53 to be used for the OpenShift cluster.

### 5.2. OpenShift Cluster Requirements

*   An OpenShift Container Platform cluster, version 4.19 or later, deployed on AWS.
*   The cluster must be deployed on EC2 metal instances to take advantage of bare-metal performance and SR-IOV capabilities.
*   The cluster must have the following Operators installed:
    *   OpenShift GitOps (ArgoCD)
    *   Node Tuning Operator (NTO)
    *   SR-IOV Network Operator
    *   OpenShift Virtualization (KubeVirt)

### 5.3. Workshop Environment

*   A GitOps repository containing all the Kubernetes manifests (Kustomize bases and overlays) for the workshop.
*   A set of AsciiDoc-based lab guides that provide step-by-step instructions for the workshop modules.
*   Automation scripts for installing the prerequisite Operators and validating the environment.
*   A `kube-burner` configuration and workload for performance validation.




## 6. Kustomize Overlays for AWS

Kustomize will be used to manage the environment-specific configurations for the AWS deployment. The following Kustomize overlays will be created:

*   **`base`**: Contains the common Kubernetes manifests for the workshop, including the pod and VMI templates.
*   **`overlays/aws`**: Contains the AWS-specific configurations, including:
    *   `PerformanceProfile` manifests for different EC2 metal instance types (e.g., `c5.metal`, `i3.metal`).
    *   `SriovNetworkNodePolicy` and `NetworkAttachmentDefinition` manifests for configuring SR-IOV on AWS.
    *   Kustomization files to apply the AWS-specific patches to the base manifests.




## 7. Automated Interface Detection for SR-IOV

To simplify the configuration of SR-IOV on AWS, a script will be provided to automatically detect the appropriate network interfaces on the worker nodes. This script will:

*   Query the AWS API to get the network interface information for the EC2 instances.
*   Identify the interfaces that support SR-IOV.
*   Generate the necessary `SriovNetworkNodePolicy` and `NetworkAttachmentDefinition` manifests.




## 8. Documentation and Deliverables

The following documentation and deliverables will be provided for the AWS deployment of the workshop:

*   **PRD for AWS**: This document.
*   **GitOps Repository**: A Git repository containing all the code and configuration for the workshop.
*   **Lab Guides**: A set of AsciiDoc-based lab guides that provide step-by-step instructions for the workshop modules.
*   **Automation Scripts**: Scripts for automating the installation of the prerequisite Operators and the configuration of the workshop environment.
*   **`kube-burner` Configuration**: A `kube-burner` configuration and workload for performance validation.


