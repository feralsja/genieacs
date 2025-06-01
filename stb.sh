#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'
local_ip=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}================= INSTALL MongoDB + NodeJS + GenieACS ==================${NC}"

# ======================= MONGODB INSTALL ======================================
if ! sudo systemctl is-active --quiet mongod; then
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
        echo -e "${GREEN}Menginstall MongoDB untuk arsitektur ARM...${NC}"
        sudo apt-get update
        sudo apt-get install -y curl gnupg ca-certificates

        curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg

        echo "deb [arch=arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

        sudo apt-get update
        sudo apt-get install -y mongodb-org=4.4.8 \
            mongodb-org-server=4.4.8 \
            mongodb-org-shell=4.4.8 \
            mongodb-org-mongos=4.4.8 \
            mongodb-org-tools=4.4.8

        echo "mongodb-org hold" | sudo dpkg --set-selections
        echo "mongodb-org-server hold" | sudo dpkg --set-selections
        echo "mongodb-org-shell hold" | sudo dpkg --set-selections
        echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
        echo "mongodb-org-tools hold" | sudo dpkg --set-selections

        sudo systemctl enable mongod
        sudo systemctl start mongod
    else
        echo -e "${GREEN}Arsitektur bukan ARM. Silakan gunakan script eksternal.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}MongoDB sudah terinstal dan aktif.${NC}"
fi

# ======================= NODE.JS INSTALL (v20) ================================
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 20 ]; then
        echo -e "${GREEN}Node.js versi $NODE_VERSION sudah terinstall.${NC}"
    else
        echo -e "${GREEN}Versi Node.js terlalu rendah. Menginstall versi 20...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
else
    echo -e "${GREEN}Menginstall Node.js 20...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# ======================= INSTALL GENIEACS ====================================
if ! systemctl is-active --quiet genieacs-cwmp || ! systemctl is-active --quiet genieacs-nbi; then
    echo -e "${GREEN}Menginstall GenieACS v1.2.13...${NC}"
    npm install -g genieacs@1.2.13

    sudo useradd --system --no-create-home --user-group genieacs || true
    sudo mkdir -p /opt/genieacs/ext /var/log/genieacs
    sudo chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

    cat << EOF | sudo tee /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF

    sudo chmod 600 /opt/genieacs/genieacs.env
    sudo chown genieacs:genieacs /opt/genieacs/genieacs.env

    # 🧠 DETEKSI LOKASI BINARY GENIEACS
    GENIEACS_PATH=$(dirname "$(command -v genieacs-cwmp)")

    # Buat service unit file
    for component in cwmp nbi fs ui; do
        cat << EOF | sudo tee /etc/systemd/system/genieacs-${component}.service
[Unit]
Description=GenieACS ${component^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=${GENIEACS_PATH}/genieacs-${component}

[Install]
WantedBy=multi-user.target
EOF
    done

    # Logrotate
    cat << EOF | sudo tee /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now genieacs-{cwmp,nbi,fs,ui}
    echo -e "${GREEN}=========== GenieACS berhasil diinstal dan dijalankan ===========${NC}"
else
    echo -e "${GREEN}GenieACS sudah aktif, melewati instalasi...${NC}"
fi

# ======================= UI + PARAMETER INSTALL ==============================
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========== GenieACS UI: http://$local_ip:3000 ===============================${NC}"
echo -e "${GREEN}=================== Informasi: Whatsapp 081947215703 =======================${NC}"
echo -e "${GREEN}============================================================================${NC}"

# Branding file (optional)
cp -r app-LU66VFYW.css /usr/lib/node_modules/genieacs/public/ 2>/dev/null || true
cp -r logo-3976e73d.svg /usr/lib/node_modules/genieacs/public/ 2>/dev/null || true

echo -e "${GREEN}Apakah anda ingin menginstal parameter virtual? (y/n)${NC}"
read confirmation

if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install parameter dibatalkan.${NC}"
    exit 0
fi

for ((i = 5; i >= 1; i--)); do
    sleep 1
    echo "Lanjut install parameter dalam $i detik. Tekan Ctrl+C untuk batalkan"
done

cd ~
sudo mongodump --db=genieacs --out genieacs-backup
sudo mongorestore --db=genieacs --drop genieacs

echo -e "${GREEN}=================== VIRTUAL PARAMETER BERHASIL DIINSTALL ===================${NC}"
echo -e "${GREEN}=== Jika ACS URL berbeda, ubah di Admin >> Provisions >> inform ============${NC}"
echo -e "${GREEN}================== UI: http://$local_ip:3000 ================================${NC}"
