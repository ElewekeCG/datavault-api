Below is a **production-grade Runbook** you can paste directly into a GitHub README or export to PDF. It is structured like something used in real DevOps teams (clear, operational, and incident-focused).

---

# 📘 DataVault Platform Runbook (GitOps + Kubernetes + Terraform)

## Version: 1.0

## Environment: AWS (EC2 + k3s)

## Deployment Model: GitOps (ArgoCD)

## Owner: Platform Engineering Team

---

# 🧭 1. Overview

DataVault is a containerised FastAPI-based compliance audit platform deployed on a Kubernetes cluster (k3s) provisioned using Terraform on AWS EC2.

The system follows a **GitOps deployment model**, where:

* Terraform provisions infrastructure
* Docker builds application images
* AWS ECR stores container images
* Kubernetes runs workloads
* ArgoCD ensures continuous reconciliation from Git

---

# 🏗️ 2. Architecture

```
GitHub Repo
   │
   │ (CI/CD)
   ▼
Docker Image → AWS ECR
   │
   ▼
Kubernetes (k3s on EC2)
   │
   ├── Deployment (datavault-api)
   ├── Service
   ├── HPA
   ├── ConfigMap
   └── Secret
   │
   ▼
ArgoCD (GitOps Sync)
```

---

# 🚀 3. Prerequisites

Ensure the following tools are installed locally:

* Terraform ≥ 1.3
* AWS CLI configured
* Docker installed
* kubectl installed
* SSH access to EC2 instance

---

# 🏗️ 4. Infrastructure Deployment (Terraform)

## 4.1 Initialise Terraform

```bash
cd terraform-aws
terraform init
```

---

## 4.2 Validate configuration

```bash
terraform validate
terraform plan
```

---

## 4.3 Deploy infrastructure

```bash
terraform apply -auto-approve
```

### This provisions:

* EC2 instance (k3s cluster node)
* Security group (SSH + outbound traffic)
* IAM role (ECR access)
* ECR repository
* Kubernetes bootstrap via user-data

---

# 🐳 5. Application Build & Push

## 5.1 Build Docker image

```bash
docker build -t datavault-api .
```

---

## 5.2 Authenticate to AWS ECR

```bash
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin \
891377349839.dkr.ecr.us-east-1.amazonaws.com
```

---

## 5.3 Tag image

```bash
docker tag datavault-api:latest \
891377349839.dkr.ecr.us-east-1.amazonaws.com/datavault-repo:v1.0
```

---

## 5.4 Push image

```bash
docker push 891377349839.dkr.ecr.us-east-1.amazonaws.com/datavault-repo:v1.0
```

---

# ☸️ 6. Kubernetes Deployment

## 6.1 Apply manifests

```bash
sudo /usr/local/bin/k3s kubectl apply -f K8s/
```

---

## 6.2 Verify deployment

```bash
kubectl get pods
kubectl get svc
kubectl get hpa
```

---

## 6.3 Check logs

```bash
kubectl logs <pod-name>
```

---

# 🔁 7. GitOps with ArgoCD

## 7.1 Port-forward ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access UI:

```
https://localhost:8080
```

---

## 7.2 Retrieve admin password

```bash
kubectl get secret -n argocd argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 -d
```

---

## 7.3 Create Application

* Repository: GitHub repo
* Path: `/K8s`
* Cluster: in-cluster
* Sync policy: Automated

---

## 7.4 Expected Behaviour

ArgoCD will:

* Detect Git changes
* Sync Kubernetes manifests
* Automatically redeploy pods

---

# 📊 8. Monitoring & Scaling

## 8.1 View cluster state

```bash
kubectl get pods -w
kubectl get hpa -w
```

---

## 8.2 Check resource usage

```bash
kubectl top pods
```

---

## 8.3 HPA behaviour

* Scales based on CPU > 60%
* Min replicas: 2
* Max replicas: 5

---

# 🚨 9. Troubleshooting Guide

## 9.1 ImagePullBackOff

### Cause:

* Missing ECR authentication
* IAM role misconfigured
* Image does not exist

### Fix:

```bash
aws ecr get-login-password | docker login ...
kubectl rollout restart deployment datavault-api
```

---

## 9.2 CrashLoopBackOff

### Cause:

* Application crash
* Missing env vars
* Faulty config

### Fix:

```bash
kubectl logs <pod>
kubectl describe pod <pod>
```

---

## 9.3 ArgoCD Out of Sync

### Fix:

```bash
git pull
kubectl apply -f K8s/
```

---

## 9.4 HPA not scaling

### Cause:

* CPU requests missing or too low
* Insufficient load

### Fix:

* Increase CPU stress
* Verify `resources.requests.cpu`

---

# 🧨 10. Known Operational Risks

| Risk                    | Impact             | Mitigation               |
| ----------------------- | ------------------ | ------------------------ |
| Immutable ECR tags      | Deployment failure | Use versioned tags       |
| Missing IAM permissions | Image pull failure | Attach ECR read policy   |
| No CPU requests         | HPA failure        | Define resource requests |
| Manual kubectl changes  | Drift              | Use ArgoCD GitOps        |

---

# 🔥 11. Deployment Rollback Procedure

## Option 1: Git rollback (recommended)

```bash
git revert <commit>
git push origin main
```

ArgoCD will automatically sync rollback.

---

## Option 2: Manual rollback

```bash
kubectl set image deployment/datavault-api \
datavault-api=repo:previous-version
```

---

# 🧨 12. Full System Teardown

## 12.1 Destroy infrastructure

```bash
cd terraform-aws
terraform destroy -auto-approve
```

---

## 12.2 Clean ECR (if required)

```bash
aws ecr delete-repository \
--repository-name datavault-repo \
--force
```

---

## 12.3 Verify teardown

* EC2 terminated
* No running pods
* No ECR repository
* No ArgoCD cluster access

---

# 🧠 13. Operational Reflection

This system demonstrates a full production-grade DevOps lifecycle:

* Infrastructure as Code (Terraform)
* Containerisation (Docker)
* Kubernetes orchestration (k3s)
* GitOps continuous delivery (ArgoCD)
* Automated scaling (HPA)

### Key lessons learned:

* Kubernetes requires explicit resource requests for autoscaling
* IAM roles are critical for secure ECR access
* GitOps ensures reproducibility and auditability
* Observability is essential for debugging distributed systems

---

# 📌 End of Runbook
