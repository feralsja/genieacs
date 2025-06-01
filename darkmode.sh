GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
local_ip=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}=========== AAA   LL      IIIII     JJJ   AAA   YY   YY   AAA ==============${NC}"   
echo -e "${GREEN}========== AAAAA  LL       III      JJJ  AAAAA  YY   YY  AAAAA =============${NC}" 
echo -e "${GREEN}========= AA   AA LL       III      JJJ AA   AA  YYYYY  AA   AA ============${NC}"
echo -e "${GREEN}========= AAAAAAA LL       III  JJ  JJJ AAAAAAA   YYY   AAAAAAA ============${NC}"
echo -e "${GREEN}========= AA   AA LLLLLLL IIIII  JJJJJ  AA   AA   YYY   AA   AA ============${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========================= . Info 081-947-215-703 ===========================${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}Autoinstall GenieACS.${NC}"
echo -e "${GREEN}${NC}"
echo -e "${GREEN}======================================================================================${NC}"
echo -e "${RED}${NC}"
echo -e "${GREEN}Sebelum melanjutkan, silahkan baca terlebih dahulu. Apakah anda ingin melanjutkan? (y/n)${NC}"
read confirmation

if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install dibatalkan. Tidak ada perubahan dalam ubuntu server anda.${NC}"
    /tmp/install.sh
    exit 1
fi
for ((i = 5; i >= 1; i--)); do
	sleep 1
    echo "Melanjutkan dalam $i. Tekan ctrl+c untuk membatalkan"
done

#============================== WARNA ==============================#
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

#===================== CEK & INSTALL NODE.JS =======================#
check_node_version() {
    if command -v node > /dev/null 2>&1; then
        NODE_VERSION=$(node -v | cut -d 'v' -f 2)
        NODE_MAJOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 1)
        NODE_MINOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 2)

        if [ "$NODE_MAJOR_VERSION" -lt 12 ] || { [ "$NODE_MAJOR_VERSION" -eq 12 ] && [ "$NODE_MINOR_VERSION" -lt 13 ]; } || [ "$NODE_MAJOR_VERSION" -gt 22 ]; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

if ! check_node_version; then
    echo -e "${GREEN}================== Menginstall Node.js 20 ==================${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
    sudo apt-get install -y nodejs
    echo -e "${GREEN}================== Sukses Node.js ==================${NC}"
else
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}============== Node.js sudah terinstall versi ${NODE_VERSION}. ==============${NC}"
    echo -e "${GREEN}========================= Lanjut install GenieACS ==========================${NC}"
fi

#==================== CEK & INSTALL MONGODB ========================#
#==================== CEK & INSTALL MONGODB ========================#
ARCH=$(uname -m)

if ! systemctl is-active --quiet mongod; then
    echo -e "${GREEN}================== Deteksi Arsitektur: $ARCH ==================${NC}"
    echo -e "${GREEN}================== Menginstall MongoDB ==================${NC}"

    sudo apt-get update
    sudo apt-get install -y curl gnupg ca-certificates lsb-release

    if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "armv7l" ]]; then
        echo -e "${GREEN}Menginstall MongoDB untuk arsitektur ARM...${NC}"

        # Tambahkan GPG key modern
        curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-org-archive-keyring.gpg

        # Tambahkan repository sesuai arsitektur
        if [[ "$ARCH" == "aarch64" ]]; then
            echo "deb [ arch=arm64 signed-by=/usr/share/keyrings/mongodb-org-archive-keyring.gpg ] \
https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | \
            sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
        else
            echo "deb [ arch=armhf signed-by=/usr/share/keyrings/mongodb-org-archive-keyring.gpg ] \
https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | \
            sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
        fi

        sudo apt-get update

        # Install MongoDB dengan versi spesifik
        sudo apt-get install -y mongodb-org=4.4.8 \
            mongodb-org-server=4.4.8 \
            mongodb-org-shell=4.4.8 \
            mongodb-org-mongos=4.4.8 \
            mongodb-org-tools=4.4.8

        # Lock versi
        echo "mongodb-org hold" | sudo dpkg --set-selections
        echo "mongodb-org-server hold" | sudo dpkg --set-selections
        echo "mongodb-org-shell hold" | sudo dpkg --set-selections
        echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
        echo "mongodb-org-tools hold" | sudo dpkg --set-selections

    else
        # Untuk x86_64 atau lainnya, pakai script URL eksternal
        echo -e "${GREEN}Menginstall MongoDB untuk x86_64...${NC}"
        curl -s ${url_install}mongod.sh | sudo bash
    fi

    # Aktifkan dan jalankan MongoDB
    sudo systemctl enable mongod
    sudo systemctl start mongod

    # Verifikasi
    if ! systemctl is-active --quiet mongod; then
        echo -e "${RED}MongoDB gagal dijalankan. Kemungkinan arsitektur tidak kompatibel.${NC}"
        exit 1
    fi

    echo -e "${GREEN}================== Sukses instalasi MongoDB ==================${NC}"
else
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}=================== MongoDB sudah terinstal sebelumnya. ===================${NC}"
fi

#GenieACS
if !  systemctl is-active --quiet genieacs-{cwmp,fs,ui,nbi}; then
    echo -e "${GREEN}================== Menginstall genieACS CWMP, FS, NBI, UI ==================${NC}"
    npm install -g genieacs@1.2.13
    useradd --system --no-create-home --user-group genieacs || true
    mkdir -p /opt/genieacs
    mkdir -p /opt/genieacs/ext
    chown genieacs:genieacs /opt/genieacs/ext
    cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF
    chown genieacs:genieacs /opt/genieacs/genieacs.env
    chown genieacs. /opt/genieacs -R
    chmod 600 /opt/genieacs/genieacs.env
    mkdir -p /var/log/genieacs
    chown genieacs. /var/log/genieacs
    # create systemd unit files
## CWMP
    cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp

[Install]
WantedBy=default.target
EOF

## NBI
    cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi
 
[Install]
WantedBy=default.target
EOF

## FS
    cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs
 
[Install]
WantedBy=default.target
EOF

## UI
    cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui
 
[Install]
WantedBy=default.target
EOF

# config logrotate
 cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
    echo -e "${GREEN}========== Install APP GenieACS selesai... ==============${NC}"
    systemctl daemon-reload
    systemctl enable --now genieacs-{cwmp,fs,ui,nbi}
    systemctl start genieacs-{cwmp,fs,ui,nbi}    
    echo -e "${GREEN}================== Sukses genieACS CWMP, FS, NBI, UI ==================${NC}"
else
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}=================== GenieACS sudah terinstall sebelumnya. ==================${NC}"
fi

#Sukses
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========== GenieACS UI akses port 3000. : http://$local_ip:3000 ============${NC}"
echo -e "${GREEN}=================== Informasi: Whatsapp 081947215703 =======================${NC}"
echo -e "${GREEN}============================================================================${NC}"
cp -r app-LU66VFYW.css /usr/lib/node_modules/genieacs/public/
cp -r logo-3976e73d.svg /usr/lib/node_modules/genieacs/public/
echo -e "${GREEN}Sekarang install parameter. Apakah anda ingin melanjutkan? (y/n)${NC}"
read confirmation

if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install dibatalkan..${NC}"
    
    exit 1
fi
for ((i = 5; i >= 1; i--)); do
    sleep 1
    echo "Lanjut Install Parameter $i. Tekan ctrl+c untuk membatalkan"
done

# Folder sumber data backup
SOURCE_DIR="$(pwd)/db-restore"
BACKUP_DIR="/root/db"

# Pastikan direktori sumber ada
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Folder $SOURCE_DIR tidak ditemukan. Letakkan file .bson dan .json di folder itu.${NC}"
    exit 1
fi

# Buat direktori tujuan
mkdir -p "$BACKUP_DIR"

# Salin file jika ada, tampilkan pesan jika tidak
copy_file() {
    local filename=$1
    if [ -f "$SOURCE_DIR/$filename" ]; then
        cp "$SOURCE_DIR/$filename" "$BACKUP_DIR/"
    else
        echo -e "${RED}File tidak ditemukan: $filename${NC}"
    fi
}

# Daftar file yang akan disalin
FILES=(
    cache.bson cache.metadata.json
    config.bson config.metadata.json
    permissions.bson permissions.metadata.json
    presets.bson presets.metadata.json
    provisions.bson provisions.metadata.json
    users.bson users.metadata.json
    tasks.bson tasks.metadata.json
    virtualParameters.bson virtualParameters.metadata.json
)

for file in "${FILES[@]}"; do
    copy_file "$file"
done

# Backup database lama
cd
sudo mongodump --db=genieacs --out genieacs-backup

# Restore database baru
mongorestore --db genieacs --drop "$BACKUP_DIR"

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}=================== VIRTUAL PARAMETER BERHASIL DI INSTALL. =================${NC}"
echo -e "${GREEN}===Jika ACS URL berbeda, silahkan edit di Admin >> Provisions >> inform ====${NC}"
echo -e "${GREEN}========== GenieACS UI akses port 3000. : http://$local_ip:3000 ============${NC}"
echo -e "${GREEN}=================== Informasi: Whatsapp 081947215703 =======================${NC}"
echo -e "${GREEN}============================================================================${NC}"

# Hapus folder jika perlu
sudo rm -rf genieacs
