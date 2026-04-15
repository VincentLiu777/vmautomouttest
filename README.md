# VM Auto-Mount NFS Azure File Share

Deploy a Linux VM with an NFS Azure file share automatically mounted, with optional **Encryption in Transit (EiT)** via the [AZNFS mount helper](https://github.com/Azure/AZNFS-mount).

## What Gets Deployed

| Resource | Description |
|---|---|
| Virtual Network | With service endpoint or private endpoint subnet |
| Network Security Group | SSH (port 22) inbound rule |
| Public IP + NIC | Static public IP attached to the VM |
| Linux VM | Your chosen OS and SKU with Trusted Launch |
| NFS File Share | SSD-tier managed file share (`Microsoft.FileShares/fileShares`) |
| Private Endpoint + DNS Zone | *(Only when `networkAccessMode=PrivateEndpoint`)* |
| CustomScript Extension | Downloads and runs `mount-nfs-share.sh` to mount the share |

## Supported Operating Systems

| OS Family | Versions | AZNFS EiT Support |
|---|---|---|
| Ubuntu | 24.04, 22.04, 20.04, 18.04 | ✅ |
| RHEL | 9, 8 | ✅ |
| SUSE SLES | 15 | ✅ |
| Alma Linux | 9, 8 | ✅ |
| Oracle Linux | 9, 8 | ✅ |
| Azure Linux | 3, 2 | ✅ |

## Quick Start

### Prerequisites

- Azure CLI installed (`az --version`)
- An Azure subscription and resource group
- Logged in: `az login`

### Deploy from GitHub (One Command)

```bash
az deployment group create \
  --resource-group <RESOURCE_GROUP> \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters \
      resourcePrefix=mytest \
      adminPassword='YourP@ssw0rd123!'
```

The template automatically downloads `mount-nfs-share.sh` from the same GitHub directory — no manual file handling needed.

### Deploy from a Local Clone

```bash
git clone https://github.com/VincentLiu777/vmautomouttest.git
cd vmautomouttest

az deployment group create \
  --resource-group <RESOURCE_GROUP> \
  --template-file vmmounttemplate-allos.json \
  --parameters \
      resourcePrefix=mytest \
      adminPassword='YourP@ssw0rd123!' \
      _artifactsLocation='https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/'
```

> **Note:** When deploying from a local file, you must provide `_artifactsLocation` so the CustomScript extension knows where to download `mount-nfs-share.sh`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourcePrefix` | *(required)* | Prefix for all resource names (2–20 chars, lowercase) |
| `location` | `eastasia` | Azure region |
| `authType` | `password` | `password` or `sshPublicKey` |
| `adminPassword` | | VM admin password (required if authType=password) |
| `sshPublicKey` | | SSH public key (required if authType=sshPublicKey) |
| `vmSize` | `Standard_D2s_v3` | VM SKU |
| `osImage` | `Ubuntu2404` | OS image (see [supported list](#supported-operating-systems)) |
| `provisionedStorageGiB` | `1024` | File share size in GiB (100–102400) |
| `provisionedIOPerSec` | `0` | IOPS (0 = service default) |
| `provisionedThroughputMiBPerSec` | `0` | Throughput in MiB/s (0 = service default) |
| `networkAccessMode` | `ServiceEndpoint` | `ServiceEndpoint` or `PrivateEndpoint` |
| `enableEncryptionInTransit` | `true` | Mount with TLS via aznfs |
| `mountPath` | *(auto)* | Custom mount point (e.g., `/mnt/myshare`). Empty = `/mnt/<shareName>` |
| `_artifactsLocation` | *(auto from URI)* | Base URL for script download |
| `_artifactsLocationSasToken` | | SAS token (only for private blob storage) |

### Allowed `osImage` Values

```
Ubuntu2404  Ubuntu2204  Ubuntu2004  Ubuntu1804
RHEL9       RHEL8
SLES15
AlmaLinux9  AlmaLinux8
OracleLinux9  OracleLinux8
AzureLinux3  AzureLinux2
```

## Examples

### Deploy RHEL 9 with Encryption in Transit (default)

```bash
az deployment group create \
  --resource-group myRG \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters \
      resourcePrefix=rheltest \
      osImage=RHEL9 \
      adminPassword='YourP@ssw0rd123!'
```

### Deploy Ubuntu with Private Endpoint and SSH Key

```bash
az deployment group create \
  --resource-group myRG \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters \
      resourcePrefix=ubuntutest \
      osImage=Ubuntu2404 \
      authType=sshPublicKey \
      sshPublicKey="$(cat ~/.ssh/id_rsa.pub)" \
      networkAccessMode=PrivateEndpoint
```

### Deploy Without Encryption in Transit

```bash
az deployment group create \
  --resource-group myRG \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters \
      resourcePrefix=noeit \
      enableEncryptionInTransit=false \
      adminPassword='YourP@ssw0rd123!'
```

## How It Works

```
┌──────────────────────────────────────────────────────────────┐
│  az deployment group create --template-uri <GITHUB_URL>      │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  ARM deploys: VNet, NSG, Public IP, NIC, VM, File Share      │
│  (+ Private Endpoint & DNS Zone if PrivateEndpoint mode)     │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  CustomScript Extension                                      │
│  1. Downloads mount-nfs-share.sh from _artifactsLocation     │
│  2. Runs it with parameters:                                 │
│     - enableEiT (true/false)                                 │
│     - fileShareHost (FQDN)                                   │
│     - shareMountName                                         │
│     - mountPath                                              │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  mount-nfs-share.sh                                          │
│  1. Detects OS from /etc/os-release                          │
│  2. Selects correct package manager (apt/yum/zypper/dnf)     │
│  3. If EiT=true:                                             │
│     - Installs Microsoft repo + aznfs                        │
│     - Mounts with: mount -t aznfs (TLS encrypted)            │
│     - Fails deployment if install fails                      │
│  4. If EiT=false:                                            │
│     - Installs nfs-common / nfs-utils / nfs-client           │
│     - Mounts with: mount -t nfs (plain)                      │
│  5. Adds /etc/fstab entry for persistence across reboots     │
└──────────────────────────────────────────────────────────────┘
```

## Outputs

After deployment, the following values are returned:

| Output | Description |
|---|---|
| `vmPublicIpAddress` | Public IP of the VM |
| `sshCommand` | Ready-to-use SSH command |
| `fileShareName` | Name of the created file share |
| `fileShareHostName` | FQDN of the file share |
| `mountPath` | Where the share is mounted on the VM |
| `networkAccessMode` | Service Endpoint or Private Endpoint |
| `encryptionInTransit` | Whether EiT is enabled |
| `osImage` | Selected OS image |

## Verify the Mount

SSH into the VM and check:

```bash
# Check mount
df -Th /mnt/<shareMountName>

# If EiT is enabled, verify aznfs is active
systemctl is-active aznfswatchdog

# Check fstab entry
cat /etc/fstab
```

## Troubleshooting

| Issue | What to Check |
|---|---|
| Mount fails | Check NSG rules (port 2049), DNS resolution, file share health |
| aznfs install fails | Check `/var/log/dpkg.log` (Ubuntu) or `/var/log/yum.log` (RHEL) |
| EiT mount hangs | Check stunnel logs at `/etc/stunnel/microsoft/aznfs/nfsv4_fileShare/logs` |
| Mount not persisted after reboot | Verify `/etc/fstab` entry exists |
| CustomScript extension fails | Check extension logs: `/var/lib/waagent/custom-script/download/0/` |

## Files

| File | Purpose |
|---|---|
| `vmmounttemplate-allos.json` | ARM template — multi-OS, external script |
| `mount-nfs-share.sh` | Bash mount script — auto-detects OS |
| `vmmounttemplate-ubuntu.json` | Legacy Ubuntu-only ARM template (inline script) |

## References

- [Encryption in Transit for NFS Azure File Shares](https://learn.microsoft.com/en-us/azure/storage/files/encryption-in-transit-for-nfs-shares)
- [AZNFS Mount Helper (GitHub)](https://github.com/Azure/AZNFS-mount)
