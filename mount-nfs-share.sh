#!/bin/bash
# =============================================================================
# mount-nfs-share.sh
#
# NFS File Share Mount Script with Encryption in Transit (EiT) support.
# Auto-detects the Linux distribution and uses the correct package manager
# and AZNFS repository URL.
#
# Supported OS families (per AZNFS documentation):
#   - Ubuntu (18.04, 20.04, 22.04, 24.04)
#   - RHEL (8, 9)
#   - SUSE SLES (15)
#   - Alma Linux (8, 9)
#   - Oracle Linux (8, 9)
#   - Azure Linux (2, 3)
#
# Usage:
#   bash mount-nfs-share.sh <enableEiT> <fileShareHost> <shareMountName> <mountPath>
#
# Parameters:
#   enableEiT      - "true" to mount with TLS via aznfs, "false" for plain NFS
#   fileShareHost  - FQDN of the file share (e.g., acct.file.core.windows.net)
#   shareMountName - Mount name of the file share (e.g., prefix-fs)
#   mountPath      - Local mount point (e.g., /mnt/prefix-fs)
# =============================================================================

set -eo pipefail

# ---------------------------------------------------------------------------
# Parse and validate parameters
# ---------------------------------------------------------------------------
EIT="${1:?'Usage: mount-nfs-share.sh <true|false> <fileShareHost> <shareMountName> <mountPath>'}"
FILE_SHARE_HOST="${2:?'Missing parameter: fileShareHost'}"
SHARE_MOUNT_NAME="${3:?'Missing parameter: shareMountName'}"
MOUNT_PATH="${4:?'Missing parameter: mountPath'}"

echo "[INFO] ==================================================================="
echo "[INFO]  NFS File Share Mount Script"
echo "[INFO] ==================================================================="
echo "[INFO] Encryption in Transit : $EIT"
echo "[INFO] File Share Host       : $FILE_SHARE_HOST"
echo "[INFO] Share Mount Name      : $SHARE_MOUNT_NAME"
echo "[INFO] Mount Path            : $MOUNT_PATH"
echo "[INFO] ==================================================================="

# ---------------------------------------------------------------------------
# Detect OS family and version from /etc/os-release
# ---------------------------------------------------------------------------
if [ ! -f /etc/os-release ]; then
    echo "[ERROR] /etc/os-release not found. Cannot detect OS."
    exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release
OS_ID="${ID}"
OS_VERSION="${VERSION_ID}"
OS_VERSION_MAJOR="${VERSION_ID%%.*}"

echo "[INFO] Detected OS: ${PRETTY_NAME:-$OS_ID $OS_VERSION}"

# ---------------------------------------------------------------------------
# Determine package manager, repo URL, and NFS client package
# ---------------------------------------------------------------------------
case "$OS_ID" in
    ubuntu|debian)
        PKG_MGR="apt"
        # Ubuntu repo URL uses full version (e.g., 24.04)
        if command -v lsb_release &>/dev/null; then
            UBUNTU_VER=$(lsb_release -rs)
        else
            UBUNTU_VER="$OS_VERSION"
        fi
        REPO_URL="https://packages.microsoft.com/config/ubuntu/${UBUNTU_VER}/packages-microsoft-prod.deb"
        REPO_FORMAT="deb"
        NFS_CLIENT_PKG="nfs-common"
        ;;

    rhel|centos)
        PKG_MGR="yum"
        REPO_URL="https://packages.microsoft.com/config/rhel/${OS_VERSION_MAJOR}/packages-microsoft-prod.rpm"
        REPO_FORMAT="rpm"
        NFS_CLIENT_PKG="nfs-utils"
        ;;

    sles|opensuse-leap)
        PKG_MGR="zypper"
        REPO_URL="https://packages.microsoft.com/config/sles/${OS_VERSION_MAJOR}/packages-microsoft-prod.rpm"
        REPO_FORMAT="rpm"
        NFS_CLIENT_PKG="nfs-client"
        ;;

    almalinux)
        PKG_MGR="yum"
        # Alma Linux uses "alma" in the repo path
        REPO_URL="https://packages.microsoft.com/config/alma/${OS_VERSION_MAJOR}/packages-microsoft-prod.rpm"
        REPO_FORMAT="rpm"
        NFS_CLIENT_PKG="nfs-utils"
        ;;

    ol)
        PKG_MGR="yum"
        # Oracle Linux uses "rhel" repo path per Microsoft docs
        REPO_URL="https://packages.microsoft.com/config/rhel/${OS_VERSION_MAJOR}/packages-microsoft-prod.rpm"
        REPO_FORMAT="rpm"
        NFS_CLIENT_PKG="nfs-utils"
        ;;

    mariner|azurelinux)
        PKG_MGR="tdnf"
        # Azure Linux uses rhel/9 repo per Microsoft docs
        REPO_URL="https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm"
        REPO_FORMAT="rpm"
        NFS_CLIENT_PKG="nfs-utils"
        ;;

    *)
        echo "[ERROR] Unsupported OS: $OS_ID"
        echo "[ERROR] Supported distributions:"
        echo "[ERROR]   ubuntu, rhel, centos, sles, almalinux, ol (Oracle), mariner, azurelinux"
        exit 1
        ;;
esac

echo "[INFO] Package manager : $PKG_MGR"
echo "[INFO] Repo format     : $REPO_FORMAT"
echo "[INFO] Repo URL        : $REPO_URL"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

wait_for_apt_lock() {
    # Stop background package manager services that hold the lock on first boot
    sudo systemctl stop unattended-upgrades.service 2>/dev/null || true
    sudo systemctl stop apt-daily.service 2>/dev/null || true
    sudo systemctl stop apt-daily-upgrade.service 2>/dev/null || true

    local max_wait=300
    local waited=0
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            echo "[ERROR] Timed out waiting for apt lock after ${max_wait}s."
            return 1
        fi
        echo "[INFO] Waiting for apt lock to be released... (${waited}s)"
        sleep 5
        waited=$((waited + 5))
    done
}

wait_for_rpm_lock() {
    # Stop background package manager services that hold the lock on first boot
    sudo systemctl stop dnf-makecache.service 2>/dev/null || true
    sudo systemctl stop dnf-makecache.timer 2>/dev/null || true
    sudo systemctl stop packagekit.service 2>/dev/null || true
    sudo systemctl stop yum-cron.service 2>/dev/null || true

    local max_wait=300
    local waited=0
    while sudo fuser /var/lib/rpm/.rpm.lock >/dev/null 2>&1 || \
          sudo fuser /var/lib/dnf/lock >/dev/null 2>&1 || \
          sudo fuser /var/run/yum.pid >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            echo "[ERROR] Timed out waiting for rpm lock after ${max_wait}s."
            return 1
        fi
        echo "[INFO] Waiting for rpm/yum/dnf lock to be released... (${waited}s)"
        sleep 5
        waited=$((waited + 5))
    done
}

# Retry a package install command up to 5 times with lock waits between retries.
# This handles the race condition where the lock is released between our check
# and the actual install, or where GPG key import fails due to lock contention.
retry_install() {
    local max_attempts=5
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "[INFO] Install attempt $attempt/$max_attempts: $*"
        if "$@"; then
            return 0
        fi
        echo "[WARNING] Install failed (attempt $attempt/$max_attempts)."
        if [ $attempt -lt $max_attempts ]; then
            echo "[INFO] Waiting 30s before retry..."
            sleep 30
            # Re-check lock before retrying
            wait_for_rpm_lock 2>/dev/null || true
            wait_for_apt_lock 2>/dev/null || true
        fi
        attempt=$((attempt + 1))
    done
    echo "[ERROR] Install failed after $max_attempts attempts."
    return 1
}

wait_for_pkg_lock() {
    case "$PKG_MGR" in
        apt) wait_for_apt_lock ;;
        yum|dnf|tdnf) wait_for_rpm_lock ;;
        # zypper doesn't typically have boot-time lock contention
    esac
}

install_microsoft_repo() {
    echo "[INFO] Downloading Microsoft repository configuration..."
    local filename
    filename=$(basename "$REPO_URL")
    curl -sSL -O "$REPO_URL" || {
        echo "[ERROR] Failed to download repository config from: $REPO_URL"
        return 1
    }

    case "$REPO_FORMAT" in
        deb)
            wait_for_apt_lock
            sudo dpkg -i "$filename"
            rm -f "$filename"
            ;;
        rpm)
            wait_for_rpm_lock
            sudo rpm -i "$filename" 2>/dev/null || true
            rm -f "$filename"
            ;;
    esac
    echo "[INFO] Microsoft repository configured."
}

# Configure yum/dnf to skip repos that are unreachable (e.g., EOL distro repos)
fix_broken_repos() {
    if [ "$PKG_MGR" = "yum" ] && command -v yum-config-manager &>/dev/null; then
        echo "[INFO] Setting all yum repos to skip_if_unavailable..."
        sudo yum-config-manager --save --setopt=\*.skip_if_unavailable=true >/dev/null 2>&1 || true
    fi
}

install_aznfs() {
    echo "[INFO] Installing aznfs mount helper..."
    export AZNFS_NONINTERACTIVE_INSTALL=1

    case "$PKG_MGR" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            wait_for_apt_lock
            # Enable universe repo (required on minimal Ubuntu cloud images)
            sudo apt-get install -y software-properties-common 2>/dev/null || true
            sudo add-apt-repository universe -y 2>/dev/null || true
            install_microsoft_repo
            wait_for_apt_lock
            sudo apt-get update
            retry_install sudo apt-get install -y aznfs
            ;;
        yum)
            fix_broken_repos
            install_microsoft_repo
            wait_for_rpm_lock
            retry_install sudo yum install -y aznfs
            ;;
        zypper)
            install_microsoft_repo
            # Import Microsoft GPG key so zypper doesn't prompt
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
            # Add openSUSE OSS repo for stunnel and conntrack-tools
            # SLES Marketplace images often lack registration, so we use the public openSUSE repo
            sudo zypper --gpg-auto-import-keys addrepo -cfG \
                https://download.opensuse.org/distribution/leap/15.5/repo/oss/ opensuse-oss 2>/dev/null || true
            sudo zypper --gpg-auto-import-keys refresh
            # Install aznfs dependencies: stunnel, conntrack-tools, nfs-client
            sudo zypper --gpg-auto-import-keys --non-interactive install stunnel conntrack-tools 2>/dev/null || true
            # Install aznfs
            retry_install sudo zypper --gpg-auto-import-keys --non-interactive install aznfs
            ;;
        dnf|tdnf)
            install_microsoft_repo
            # Import Microsoft GPG key (required for tdnf repo signature verification)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
            # Disable repo GPG signature check for Microsoft Production repo on Azure Linux
            if [ -f /etc/yum.repos.d/packages-microsoft-com-prod.repo ]; then
                sudo sed -i 's/^repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/packages-microsoft-com-prod.repo 2>/dev/null || true
            fi
            wait_for_rpm_lock
            retry_install sudo $PKG_MGR install -y aznfs
            ;;
    esac
}

install_nfs_client() {
    echo "[INFO] Installing NFS client package ($NFS_CLIENT_PKG)..."

    case "$PKG_MGR" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            wait_for_apt_lock
            # Enable universe repo (required on minimal Ubuntu cloud images)
            sudo apt-get install -y software-properties-common 2>/dev/null || true
            sudo add-apt-repository universe -y 2>/dev/null || true
            wait_for_apt_lock
            sudo apt-get update
            retry_install sudo apt-get install -y "$NFS_CLIENT_PKG"
            ;;
        yum)
            fix_broken_repos
            wait_for_rpm_lock
            retry_install sudo yum install -y "$NFS_CLIENT_PKG"
            ;;
        zypper)
            retry_install sudo zypper --gpg-auto-import-keys --non-interactive install "$NFS_CLIENT_PKG"
            ;;
        dnf|tdnf)
            wait_for_rpm_lock
            retry_install sudo $PKG_MGR install -y "$NFS_CLIENT_PKG"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Install AZNFS (for EiT) or plain NFS client
# ---------------------------------------------------------------------------
if [ "$EIT" = "true" ]; then
    echo "[INFO] Encryption in transit enabled. Installing aznfs..."

    install_aznfs || {
        echo "[ERROR] aznfs installation failed."
        echo "[ERROR] Aborting — encryption in transit was requested but cannot be satisfied."
        exit 1
    }

    # Verify that mount.aznfs is available after installation
    if ! command -v mount.aznfs >/dev/null 2>&1; then
        echo "[ERROR] mount.aznfs not found after installation. Aborting."
        exit 1
    fi

    MOUNT_TYPE="aznfs"
    MOUNT_OPTS="vers=4,minorversion=1,sec=sys,nconnect=4"
    echo "[INFO] aznfs installed successfully. TLS encryption will be used."

else
    echo "[INFO] Encryption in transit disabled. Installing plain NFS client..."

    install_nfs_client || {
        echo "[ERROR] Failed to install NFS client package ($NFS_CLIENT_PKG)."
        exit 1
    }

    MOUNT_TYPE="nfs"
    MOUNT_OPTS="vers=4,minorversion=1,sec=sys,nconnect=4"
    echo "[INFO] NFS client installed. Mounting without TLS."
fi

# ---------------------------------------------------------------------------
# Mount the NFS file share
# ---------------------------------------------------------------------------
SERVER_NAME=$(echo "$FILE_SHARE_HOST" | cut -d. -f1)

echo "[INFO] -------------------------------------------------------------------"
echo "[INFO] Mount details:"
echo "[INFO]   Host       : $FILE_SHARE_HOST"
echo "[INFO]   Server     : $SERVER_NAME"
echo "[INFO]   Share      : $SHARE_MOUNT_NAME"
echo "[INFO]   Mount path : $MOUNT_PATH"
echo "[INFO]   Mount type : $MOUNT_TYPE"
echo "[INFO]   Options    : $MOUNT_OPTS"
echo "[INFO] -------------------------------------------------------------------"

# Create mount directory
sudo mkdir -p "$MOUNT_PATH" || {
    echo "[ERROR] Failed to create mount directory: $MOUNT_PATH"
    exit 1
}

# Mount the NFS share
echo "[INFO] Mounting NFS share..."
sudo mount -t "$MOUNT_TYPE" \
    -o "$MOUNT_OPTS" \
    "${FILE_SHARE_HOST}:/${SERVER_NAME}/${SHARE_MOUNT_NAME}" \
    "$MOUNT_PATH" || {
    echo "[ERROR] NFS mount failed."
    echo "[ERROR] Troubleshooting checklist:"
    echo "[ERROR]   1. Verify the file share is healthy"
    echo "[ERROR]   2. Check VM network connectivity"
    echo "[ERROR]   3. Ensure NFS port 2049 is not blocked"
    echo "[ERROR]   4. Verify DNS resolution of $FILE_SHARE_HOST"
    if [ "$EIT" = "true" ]; then
        echo "[ERROR]   5. Check aznfs logs at /opt/microsoft/aznfs/data/aznfs.log"
        echo "[ERROR]   6. Check stunnel logs at /etc/stunnel/microsoft/aznfs/nfsv4_fileShare/logs"
    fi
    exit 1
}

# Add persistent mount entry to /etc/fstab
FSTAB_ENTRY="${FILE_SHARE_HOST}:/${SERVER_NAME}/${SHARE_MOUNT_NAME}"
FSTAB_ENTRY="${FSTAB_ENTRY} ${MOUNT_PATH} ${MOUNT_TYPE}"
FSTAB_ENTRY="${FSTAB_ENTRY} ${MOUNT_OPTS},_netdev,nofail 0 0"

echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
echo "[INFO] Added fstab entry for persistent mount."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "[INFO] ==================================================================="
echo "[INFO]  Mount completed successfully"
echo "[INFO] ==================================================================="
echo "[INFO] Share mounted at: $MOUNT_PATH (type: $MOUNT_TYPE)"
df -h "$MOUNT_PATH"

# ---------------------------------------------------------------------------
# Ensure SSH password authentication is enabled
# Some marketplace images (RHEL, Oracle, Alma) disable password auth by default
# in sshd_config, overriding the Azure disablePasswordAuthentication setting.
# ---------------------------------------------------------------------------
SSHD_RESTART_NEEDED=false

# Fix main sshd_config
if grep -qE '^\s*PasswordAuthentication\s+no' /etc/ssh/sshd_config 2>/dev/null; then
    echo "[INFO] Enabling SSH password authentication in sshd_config..."
    sudo sed -i 's/^\s*PasswordAuthentication\s\+no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    SSHD_RESTART_NEEDED=true
fi

# Fix drop-in files if the directory exists
if [ -d /etc/ssh/sshd_config.d ]; then
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [ -f "$f" ] || continue
        if grep -qE '^\s*PasswordAuthentication\s+no' "$f" 2>/dev/null; then
            echo "[INFO] Enabling SSH password authentication in $f..."
            sudo sed -i 's/^\s*PasswordAuthentication\s\+no/PasswordAuthentication yes/' "$f"
            SSHD_RESTART_NEEDED=true
        fi
    done
fi

if [ "$SSHD_RESTART_NEEDED" = "true" ]; then
    sudo systemctl restart sshd
    echo "[INFO] SSH password authentication enabled."
fi
