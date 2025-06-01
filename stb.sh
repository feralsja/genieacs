#!/bin/bash

set -e

GREEN='\033[0;32m'
NC='\033[0m'
local_ip=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}================== Menginstall GenieACS CWMP, FS, NBI, UI ==================${NC}"

# Cek apakah GenieACS sudah jalan
if ! systemctl is-active --quiet genieacs-cwmp; then
    # Install GenieACS via NPM
    npm install -g genieacs@1.2.13

    # Buat user dan direktori
    sudo useradd --system --no-create-home --user-group genieacs || true
    sudo mkdir -p /opt/genieacs/ext /var/log/genieacs
    sudo chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

    # Buat file environment
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

    # Buat unit service untuk systemd
    for component in cwmp nbi fs ui; do
        cat << EOF | sudo tee /etc/systemd/system/genieacs-${component}.service
[Unit]
Description=GenieACS ${component^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/local/bin/genieacs-${component}

[Install]
WantedBy=multi-user.target
EOF
    done

    # Setup logrotate
    cat << EOF | sudo tee /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

    echo -e "${GREEN}========== Install APP GenieACS selesai... ==============${NC}"

    sudo systemctl daemon-reload
    sudo systemctl enable --now genieacs-{cwmp,nbi,fs,ui}
    sudo systemctl start genieacs-{cwmp,nbi,fs,ui}

    echo -e "${GREEN}================== Sukses start GenieACS services ==================${NC}"
else
    echo -e "${GREEN}================ GenieACS sudah terinstall dan aktif. ===============${NC}"
fi

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========== GenieACS UI dapat diakses di: http://$local_ip:3000 ============${NC}"
echo -e "${GREEN}============================================================================${NC}"

# Salin file branding jika tersedia
cp -r app-LU66VFYW.css /usr/lib/node_modules/genieacs/public/ 2>/dev/null || true
cp -r logo-3976e73d.svg /usr/lib/node_modules/genieacs/public/ 2>/dev/null || true

echo -e "${GREEN}Sekarang install parameter virtual. Apakah anda ingin melanjutkan? (y/n)${NC}"
read confirmation

if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install parameter dibatalkan..${NC}"
    exit 1
fi

for ((i = 5; i >= 1; i--)); do
    sleep 1
    echo "Lanjut install parameter dalam $i detik. Tekan Ctrl+C untuk batalkan"
done

cd ~
sudo mongodump --db=genieacs --out genieacs-backup
sudo mongorestore --db=genieacs --drop genieacs

echo -e "${GREEN}=================== VIRTUAL PARAMETER BERHASIL DIINSTALL ===================${NC}"
echo -e "${GREEN}===Jika ACS URL berbeda, ubah di UI: Admin >> Provisions >> inform =========${NC}"
echo -e "${GREEN}================== UI: http://$local_ip:3000 ===============================${NC}"
