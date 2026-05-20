# AzureVM-Creation-Powershell

A PowerShell-based automation project for provisioning Azure Windows Server VMs in the ** US (a-prod-002)** environment — including networking, storage, tagging, boot diagnostics, and domain join.

---

## 📁 Project Structure

```
AzureVM-Creation-Powershell/
├── Create-AzureVM.ps1       # Main VM provisioning script
├── DomainJoin-Config.ps1    # Post-deployment domain join & system configuration
└── README.md
```

---

## 🔧 Prerequisites

- [Azure PowerShell Module](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps) (`Az` module)
- Sufficient Azure RBAC permissions on the `Prd-Subscription` subscription
- Access to the target VNet, Subnet, and ASGs
- Domain credentials for `Domain.cloud.local`

```powershell
# Install the Az module if not already present
Install-Module -Name Az -Scope CurrentUser -Force
```

---

## 🚀 Usage

### Step 1 — VM Provisioning

Run the main script and provide inputs when prompted:

```powershell
.\Create-AzureVM.ps1
```

| Prompt | Description | Example |
|--------|-------------|---------|
| Region | Azure region for deployment | `eastus2` |
| Computer Name | VM hostname | `VM-US-PROD-01` |
| APT-Customer Tag | Customer tag value | `CustomerName` |
| VM Local Admin Password | Local admin password | *(secure input)* |
| Subnet Name | Suffix of the target subnet | `app` → `snet-eastus2-prd-app` |
| Client Number | Used in storage account name | `001` |
| Storage Account Needed | Create new or use existing | `Yes` / `No` |

### Step 2 — Domain Join & System Configuration

After the VM is provisioned and reachable, run the domain join script **locally on the VM** or via Azure Run Command:

```powershell
.\DomainJoin-Config.ps1
```

This script will:
- Join the VM to `domain.cloud.local`
- Disable IE Enhanced Security Configuration (Admin & User)
- Disable automatic time zone updates
- Disable Windows Defender Firewall (Domain, Private, Public)
- Enable SMB remote management
- Restart the VM to complete domain join

---

## 🏗️ What Gets Deployed

| Resource | Naming Convention |
|----------|------------------|
| Resource Group | `rg-<region>-prd-pgn` |
| Virtual Network | `vnet-<region>-prd-pgn` |
| Subnet | `snet-<region>-prd-pgn-<input>` |
| Public IP | `<ComputerName>-PIP` (Static, Standard SKU) |
| Network Interface | `<ComputerName>-NIC` |
| Storage Account | `strg<region>prd<clientnumber>` |
| OS Disk | `<ComputerName>_osdisk` (128 GB) |
| VM Size | `Standard_B4ms` |
| OS Image | Windows Server 2019 Datacenter |

### Application Security Groups (ASGs) Assigned

- `asg-<region>-prd-rds-session-host-servers`
- `asg-<region>-prd-ips`
- `asg-<region>-prd-dc`

---

## 🏷️ Tags Applied

| Tag Key | Tag Value |
|---------|-----------|
| `APT-Product` | `Customer name` |
| `APT-Customer` | *(user input)* |
| `Patching Mode` | `Date` |

---

## 🔐 Domain Join Details

| Setting | Value |
|---------|-------|
| Domain | `domain.cloud.local` |
| Domain User | `avds` |
| Firewall | Disabled (Domain / Private / Public) |
| Auto Restart | Yes (on domain join) |

> ⚠️ **Before running the domain join script**, ensure `$domainname` and `$domainPassword` are populated. These are left blank in the script intentionally — fill them in securely before execution or pass them via a secrets manager.

---

## ⚠️ Important Notes

- The `Location` is currently **hardcoded to `eastus2`** in several cmdlets. If deploying to another region, update those values or refactor to use `$region` throughout.
- Boot diagnostics are initially **disabled** during VM creation, then **re-enabled** post-provisioning once the storage account is confirmed reachable.
- A data disk configuration is present in the script but **commented out** — uncomment and adjust if a data disk is needed.
- Auto Windows Updates are explicitly **disabled** on the VM (`EnableAutomaticUpdates = $false`).

---

## 🧹 Cleanup

To remove all resources created by this script:

```powershell
Remove-AzResourceGroup -Name "rg-<region>-prd" -Force
```

> ⚠️ This deletes **all** resources in the resource group. Use with caution in shared environments.
