# Self-Healing Microservice on AWS

A cloud-deployed **containerized microservice** on AWS demonstrating layered self-healing, automated scaling, and CI/CD-driven delivery with integrated security validation.

This project focuses on **system resilience and recovery mechanisms across multiple layers**—application, container, instance, and traffic routing.

---

## 🧠 Overview

This system implements a fault-tolerant microservice architecture where failures are automatically detected and recovered without manual intervention.

Key design principles:

* Health-driven recovery
* Infrastructure-level redundancy
* Automated deployment pipelines
* Observability-backed decision making

---

## 🏗️ Architecture

**Flow:**

Developer Push → CI Pipeline → Container Registry → AWS Infrastructure → Running Microservice

**AWS Stack:**

* VPC (multi-AZ)
* Application Load Balancer (ALB)
* Target Group with health checks
* Auto Scaling Group (2–4 instances)
* EC2 instances running containerized service

**CI/CD Pipeline:**

* Build → Security Scan → Containerize → Push → Deploy-ready artifact

---

## ✨ Key Features

* Layered self-healing across multiple system levels
* Automatic instance replacement via Auto Scaling Group
* Health-based traffic routing using ALB
* CPU-based horizontal scaling under load
* Fully containerized deployment
* CI/CD pipeline with integrated vulnerability scanning
* Infrastructure provisioned using Terraform
* Multi-AZ deployment for high availability

---

## 🛠 Tech Stack

| Layer            | Technology                                        |
| ---------------- | ------------------------------------------------- |
| Application      | Containerized backend service                     |
| Build & CI/CD    | GitHub Actions                                    |
| Containerization | Docker                                            |
| Security         | Snyk (dependency + image scanning)                |
| Cloud            | AWS EC2, ALB, Auto Scaling Group, CloudWatch, VPC |
| Infrastructure   | Terraform                                         |

---

## 🔄 Self-Healing Strategy

This system is designed with **multi-layer fault recovery**:

### 1. Application-Level Health

* Health endpoint exposed (`/actuator/health`)
* Reports service readiness and liveness
* Used by downstream systems for failure detection

---

### 2. Container-Level Recovery

* Container health checks configured
* Failed health checks mark container as unhealthy
* Automatic restart via container runtime

---

### 3. Instance-Level Recovery

* Auto Scaling Group monitors instance health
* Unhealthy instances are terminated and replaced
* Desired capacity is continuously maintained

---

### 4. Traffic-Level Isolation

* ALB performs periodic health checks
* Unhealthy instances removed from rotation
* Requests routed only to healthy targets

---

### 5. Demand-Based Scaling

* CloudWatch monitors CPU utilization
* Scale-out triggered at sustained high load (~80%)
* Scale-in during low utilization

---

## 🔄 CI/CD Pipeline

Triggered on every push.

**Pipeline Stages:**

1. Build application
2. Run dependency vulnerability scan
3. Build Docker image
4. Push image to registry
5. Run container image security scan

Pipeline enforces **fail-fast on high-severity vulnerabilities**.

---

## ☁️ Deployment (Terraform)

Infrastructure is provisioned using Infrastructure-as-Code:

* VPC with multi-AZ configuration
* Load balancer + health checks
* Auto Scaling Group with dynamic capacity
* EC2 instances configured for container runtime

> Infrastructure is created and destroyed on demand to optimize cost usage.

---

## 📊 Monitoring & Scaling

**Health Checks**

* Endpoint: `/actuator/health`
* Interval: 30s
* Failure thresholds configured for automatic isolation

**Auto Scaling**

* Metric: CPU utilization
* Target: ~80%
* Min: 2 instances
* Max: 4 instances

---

## 📁 Project Structure

```
self-healing-microservice/
├── .github/workflows/ci.yml
├── src/
├── terraform/
├── Dockerfile
├── build configuration files
└── README.md
```

---

## 🔐 Security Considerations

* No hardcoded credentials
* IAM roles used for instance access
* Security groups restrict inbound traffic
* Automated vulnerability scanning in CI pipeline
* Sensitive files excluded via version control rules

---

## 🎯 Objectives

This project demonstrates:

* Designing resilient microservice systems
* Implementing layered self-healing strategies
* Automating deployment and validation pipelines
* Managing infrastructure using Terraform
* Running containerized workloads in a cloud environment
* Understanding load balancer health and failover behavior

---

## 🏁 Outcome

A fully functional self-healing microservice deployed on AWS, capable of:

* Detecting failures at multiple levels
* Recovering automatically without manual intervention
* Scaling dynamically based on system load

This project represents a practical implementation of **resilient, cloud-native microservice architecture**.

---

## 📌 Notes

The system was deployed and validated on AWS. Infrastructure resources were decommissioned after testing to optimize cost usage. Deployment artifacts and logs are included in the repository for verification.
