# Azure Hub-Spoke Network with Terraform (AzureRM)

This repository provisions a **secure, scalable Hub-Spoke network topology** in Azure using Terraform.

## 📌 Features

- **Hub VNet** with:
  - Azure Firewall for secure ingress/egress control
  - Optional shared subnet for shared services
- **Multiple Spoke VNets** for workload isolation
- **Bidirectional Hub-Spoke peerings**
- **Centralized routing**: all spoke traffic flows through the hub firewall
- **Basic firewall rules** for:
  - HTTP/HTTPS web access
  - DNS resolution
  - East-West (spoke-to-spoke) traffic
- **Easily extendable**: add/remove spokes by updating a single variable

---

## 🚀 Getting Started

### 1️⃣ Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.4.0+
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) authenticated to your subscription
- An Azure subscription with permission to create networking resources

---

### 2️⃣ Clone this repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>

```

--- 

### 3️⃣ Update variables
Edit terraform.tfvars to match your requirements

---

### 4️⃣ Initialize and deploy
```bash
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```


## ⚙️ Customization
Add more spokes: Edit spokes in terraform.tfvars

Refine firewall rules: Replace broad outbound allow rules with granular application or network rule collections

Enable logging & analytics: Connect Azure Firewall and VNets to Log Analytics

Private DNS: Add Azure DNS Private Resolver for cross-spoke name resolution





