# Self-Healing Microservice on AWS

A containerized Spring Boot microservice deployed to AWS, demonstrating layered fault recovery (application, container, instance, and traffic level), CPU-based auto scaling, and a CI pipeline with integrated Snyk security scanning.

This project focuses on **system resilience and recovery mechanisms across multiple layers**—application, container, instance, and traffic routing.

---

## 🧠 Overview

This system implements a fault-tolerant microservice architecture where infrastructure-level failures (unhealthy instances, unhealthy targets) are automatically detected and recovered without manual intervention. Deployment of a new image to EC2 is currently a manual step (see [CI/CD Pipeline](#-cicd-pipeline)).

Key design principles:

* Health-driven recovery
* Infrastructure-level redundancy
* Continuous delivery with automated build, test, and security scanning
* Health-check-backed decision making (ALB + ASG)

---

## 🏗️ Architecture

**Flow:**

Developer Push → GitHub Actions (build, test, scan, push) → Docker Hub → Manual pull & run on EC2 → Running Microservice behind ALB

**AWS Stack:**

* VPC (multi-AZ, 2 public subnets)
* Application Load Balancer (ALB)
* Target Group with health checks
* Auto Scaling Group (min 2, max 4 instances)
* EC2 instances (t3.micro, Amazon Linux 2) running the containerized service

**CI/CD Pipeline:**

* Build → Test → Build Docker image → Push to Docker Hub → Snyk dependency scan → Snyk Docker image scan

---

## ✨ Key Features

* Layered self-healing across multiple system levels
* Automatic instance replacement via Auto Scaling Group (ELB health checks)
* Health-based traffic routing using ALB
* CPU-based horizontal scaling under load (target tracking, 80%)
* Fully containerized deployment (Docker)
* CI pipeline with integrated Snyk vulnerability scanning (dependency + image)
* Infrastructure provisioned using Terraform
* Multi-AZ deployment for high availability

---

## 🛠 Tech Stack

| Layer            | Technology                                         |
| ----------------- | -------------------------------------------------- |
| Application       | Java 17, Spring Boot (Web + Actuator)               |
| Build & CI        | GitHub Actions, Maven                               |
| Containerization  | Docker                                              |
| Security          | Snyk (dependency + Docker image scanning)           |
| Cloud             | AWS EC2, ALB, Auto Scaling Group, VPC               |
| Infrastructure    | Terraform                                           |

---

## 🔄 Self-Healing Strategy

This system is designed with **multi-layer fault recovery**:

### 1. Application-Level Health

* Health endpoint exposed (`/actuator/health`)
* Reports service readiness and liveness
* Used by the ALB and Docker health check for failure detection

---

### 2. Container-Level Health Reporting

* A Docker `HEALTHCHECK` polls `/actuator/health` every 30s and marks the container `healthy`/`unhealthy`
* `docker run` is configured with `--restart unless-stopped`, which restarts the container if the process exits or crashes — it does **not** restart the container purely because Docker marks it `unhealthy`
* Container health status is visible via `docker ps` and is what the underlying instance's health ultimately depends on

---

### 3. Instance-Level Recovery

* Auto Scaling Group uses `ELB` health checks (not just EC2 status checks)
* Instances that fail ALB target-group health checks are terminated and replaced
* Desired capacity (min 2) is continuously maintained

---

### 4. Traffic-Level Isolation

* ALB performs health checks against `/actuator/health` every 30s
* Unhealthy targets are removed from the target group rotation (3 consecutive failures)
* Requests routed only to targets marked healthy (2 consecutive successes)

---

### 5. Demand-Based Scaling

* Auto Scaling target-tracking policy monitors `ASGAverageCPUUtilization`
* Target value: 80% average CPU
* Scale-out/scale-in handled automatically by the target tracking policy; new instances get a 20s warm-up before being included in the metric

---

## 🔄 CI/CD Pipeline

Defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml), triggered on every push to `main`. This is a **continuous delivery** pipeline — it builds, tests, scans, and publishes a Docker image, but does **not** deploy to AWS. Deploying the new image to EC2 is done manually (`docker pull` + `docker run` on each instance, or via a fresh Auto Scaling Group instance refresh).

**Pipeline stages, in actual execution order:**

1. Checkout code
2. Set up JDK 17
3. Build with Maven (`mvn clean package -DskipTests`)
4. Run unit tests (`mvn test`)
5. Log in to Docker Hub
6. Build and push the Docker image (tagged `:latest`)
7. Install Snyk CLI and run a dependency scan (`snyk test --file=pom.xml --severity-threshold=high`)
8. Run a Snyk Docker image scan against the pushed image (`--severity-threshold=high`)

> Note: the image is built and pushed to Docker Hub **before** either Snyk scan runs. A high-severity finding fails the workflow, but only after the image is already public — this is not a fail-fast-before-publish pipeline.

---

## ☁️ Deployment (Terraform)

Infrastructure is provisioned using Infrastructure-as-Code under [`terraform/`](terraform/):

* VPC (`10.0.0.0/16`) with 2 public subnets across `us-east-1a`/`us-east-1b`, internet gateway, and route table
* Security groups: ALB SG (inbound 80 from anywhere), EC2 SG (inbound 8080 from ALB SG only, inbound 22 from a single restricted IP)
* Application Load Balancer + target group with health checks on `/actuator/health`
* Auto Scaling Group (min 2, max 4) with a launch template that bootstraps Docker via EC2 user data and runs the container
* Target-tracking scaling policy (80% average CPU)

EC2 user data installs Docker, then runs:
```
docker pull sannidhisriram/selfhealing-app:latest
docker run -d -p 8080:8080 --name selfhealing --restart unless-stopped sannidhisriram/selfhealing-app:latest
```

> Infrastructure was created and destroyed on demand during development/testing to control cost. There is no automated destroy step in this repo — teardown was done manually via `terraform destroy`.

---

## 📊 Monitoring & Scaling

**Health Checks**

* Endpoint: `/actuator/health`
* ALB check interval: 30s, timeout 5s
* Healthy threshold: 2 consecutive successes · Unhealthy threshold: 3 consecutive failures
* Docker `HEALTHCHECK`: interval 30s, timeout 3s, 3 retries

**Auto Scaling**

* Metric: Average CPU utilization across the ASG
* Target: 80%
* Min: 2 instances · Max: 4 instances
* Instance warm-up before inclusion in the metric: 20s

---

## 📁 Project Structure

```
self-healing-microservice/
├── .github/workflows/ci.yml       # CI pipeline (build, test, push, Snyk scans)
├── src/
│   ├── main/java/com/sriram/selfhealing/
│   │   ├── SelfhealingApplication.java
│   │   └── HelloController.java   # GET / -> plaintext status message
│   ├── main/resources/application.properties
│   └── test/java/.../SelfhealingApplicationTests.java
├── terraform/                     # VPC, ALB, ASG, security groups, provider
├── Screenshots/                   # AWS console, Docker Desktop, and GitHub Actions evidence from deployment
├── Dockerfile
├── pom.xml
├── mvnw / mvnw.cmd, .mvn/
└── README.md
```

---

## 🔐 Security Considerations

* No credentials are hardcoded in tracked files (secrets are pulled from GitHub Actions secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `SNYK_TOKEN`)
* EC2 instances have **no IAM role/instance profile attached** in the current Terraform — instance access is not IAM-based
* Security groups restrict inbound traffic: port 8080 only from the ALB security group, SSH (22) restricted to a single IP
* Automated Snyk vulnerability scanning (dependencies + Docker image) runs in CI, but after the image is already pushed (see CI/CD Pipeline note above)
* `.gitignore` excludes `*.pem`, `.env`, `.aws/`, and Terraform state files from version control

---

## 🎯 Objectives

This project demonstrates:

* Designing resilient microservice systems
* Implementing layered self-healing strategies at the container, instance, and traffic level
* Building a CI pipeline with automated build, test, and vulnerability scanning
* Managing infrastructure using Terraform
* Running containerized workloads in a cloud environment
* Understanding load balancer health checks and Auto Scaling Group failover behavior

---

## 🏁 Outcome

A working self-healing microservice deployed on AWS (evidence in [`Screenshots/`](Screenshots/)), demonstrating:

* Automatic instance replacement and target isolation on failure (via ASG + ALB health checks)
* CPU-based auto scaling
* A working CI pipeline: 9 GitHub Actions runs, dependency and image scans passing with no vulnerable paths found

This project represents a practical implementation of **resilient, cloud-native microservice architecture** — with manual deployment as the current gap toward full continuous deployment.

---

## 📌 Notes

The system was deployed and validated on AWS in February 2026 (see [`Screenshots/AWS_Github_Snyk_CI:CD.pdf`](Screenshots/AWS_Github_Snyk_CI:CD.pdf) and the accompanying screenshots). Infrastructure resources were decommissioned after testing to optimize cost usage.
