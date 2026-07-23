#!/usr/bin/env bash

# ==============================================================================
# Sparow OS Installation
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# --- COLOR DEFINITIONS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- LOGGING FUNCTIONS ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_header() {
    clear
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}                        SPAROW OS INSTALLER                           ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo
}

show_header

# --- PARTITION LISTING ---
log_info "Menampilkan daftar partisi yang tersedia di sistem Anda:"
echo -e "${YELLOW}"
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS
echo -e "${NC}"

# --- INTERACTIVE USER INPUTS ---
log_info "Silakan masukkan detail partisi dengan teliti (contoh: /dev/sda1 atau /dev/nvme0n1p1):"
echo

read -p "  1. Partisi Boot : " boot
while [[ -z "$boot" || ! -b "$boot" ]]; do
    log_error "Partisi '$boot' tidak valid."
    read -p "  1. Partisi Boot/EFI Sparow OS: " boot
done

read -p "  2. Partisi Root : " root
while [[ -z "$root" || ! -b "$root" ]]; do
    log_error "Partisi '$root' tidak valid."
    read -p "  2. Partisi Root Sparow OS: " root
done

read -p "  3. Partisi Home : " home
while [[ -z "$home" || ! -b "$home" ]]; do
    log_error "Partisi '$home' tidak valid."
    read -p "  3. Partisi Home Amanda OS: " home
done

read -p "  4. Partisi Swap : " swap
while [[ -z "$swap" || ! -b "$swap" ]]; do
    log_error "Partisi '$swap' tidak valid."
    read -p "  4. Partisi Swap Amanda OS: " swap
done


echo
log_info "Konfigurasi Identitas & Kredensial Pengguna:"
read -p "  Masukkan Username baru: " username
while [[ -z "$username" ]]; do
    log_error "Username tidak boleh kosong!"
    read -p "  Masukkan Username baru: " username
done

read -p "  Masukkan Hostname komputer: " hostname
while [[ -z "$hostname" ]]; do
    log_error "Hostname tidak boleh kosong!"
    read -p "  Masukkan Hostname komputer: " hostname
done

read -sp "  Masukkan Password akun $username : " pw
echo
while [[ -z "$pw" ]]; do
    log_error "Password tidak boleh kosong!"
    read -sp "  Masukkan Password akun $username : " pw
    echo
done

# --- CONFIRMATION SUMMARY ---
show_header
log_warning "PERHATIAN! Tindakan berikut akan menghapus data pada partisi terpilih:"
echo -e "  - ${RED}Boot Partition:${NC} $boot"
echo -e "  - ${RED}Root Partition:${NC} $root"
echo -e "  - ${RED}Home Partition:${NC} $home "
echo -e "  - ${RED}Swap Partition:${NC} $swap "
echo
echo -e "  - ${CYAN}Username:${NC} $username"
echo -e "  - ${CYAN}Hostname:${NC} $hostname"
echo

read -p "Apakah Anda yakin ingin melanjutkan instalasi? (ketik 'yes' untuk konfirmasi): " confirm
if [[ "$confirm" != "yes" ]]; then
    log_info "Instalasi dibatalkan oleh pengguna."
    exit 0
fi

# --- HARDWARE AUTO-DETECTION ---
show_header
log_info "Mendeteksi perangkat keras (Hardware Auto-Detection)..."

ucodes=""
gpu_module=""
firms="linux-firmware"

# CPU Detection
cpu_vendor=$(lscpu | grep -i "Vendor ID:" | awk '{print $3}')
if [[ "$cpu_vendor" == *"Intel"* ]]; then
    ucodes="intel-ucode"
    gpu_module="i915"
    log_success "Prosesor Intel dideteksi. Menggunakan microcode: $ucodes"
elif [[ "$cpu_vendor" == *"AMD"* ]]; then
    ucodes="amd-ucode"
    gpu_module="amdgpu"
    log_success "Prosesor AMD dideteksi. Menggunakan microcode: $ucodes"
else
    log_warning "Prosesor tidak dikenal. Tidak memasang microcode tambahan."
fi

firms="$firms sof-firmware alsa-firmware"

# --- 1. FORMAT & ENCRYPT DISK ---
log_info "Memulai proses format"

log_info "Memformat Partisi Root ($root)"
mkfs.ext4 -F -b 4096 "$root" &&

log_info "Format Boot ($boot)"
mkfs.vfat -F32 -n BOOT "$boot" &&

log_info "Format Home ($home)"
mkfs.ext4 -F -b 4096 "$home" &&

log_info "Format Swap ($swap)"
mkswap -f "$swap" &&

log_success "Pemformatan Partisi selesai!"
sleep 2

# --- 2. MOUNTING ---
log_info "Mounting Partisi..."

mount "$root" /mnt &&

mkdir -p /mnt/boot &&
mount -o uid=0,gid=0,fmask=0077,dmask=0077 "$boot" /mnt/boot &&

mkdir -p /mnt/home &&
mount "$home" /mnt/home &&

swapon "$swap" &&

log_success "Mounting Telah Berhasil!"
sleep 2

# --- 3. PACKAGES  ---
log_info "Instalasi Packages Sparow OS"

pacstrap /mnt base base-devel wireless-regdb linux $firms $ucodes \
    networkmanager plasma-nm firewalld git wget neovim \
    efibootmgr grub os-prober iptables-nft dolphin xorg-server \
    pipewire pipewire-alsa pipewire-jack pipewire-pulse mkinitcpio \
    discover firefox plasma-login-manager plasma-pa xdg-desktop-portal-kde \
    systemsettings spectacle plasma-desktop breeze-gtk breeze-cursors breeze \
    plasma-workspace bluedevil bluez-utils konsole digikam --noconfirm &&


# Configuration
rm -fr /mnt/usr/share/wallpapers/Next/contents/images/* &&
rm -fr /mnt/usr/share/plasma/look-and-feel/* &&
git clone https://github.com/linux-sparow/installer-new.git installer &&
cp -fr installer/config/* /mnt/ &&
rm -fr installer &&

# Generate FSTAB
log_info "Membuat file fstab..."
genfstab -U /mnt > /mnt/etc/fstab

log_success "Pemasangan paket dasar dan konfigurasi fstab selesai!"
sleep 2


# --- 4. SYSTEM CONFIGURATION (CHROOT) ---
log_info "Memasuki chroot untuk konfigurasi sistem..."

root_uuid=$(blkid -s UUID -o value "$root")

arch-chroot /mnt /bin/bash <<EOF
set -e

# --- 4.1. Timezone & Locale ---
echo "Mengatur Timezone (Asia/Jakarta)..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

echo "Mengatur Locale..."
locale-gen

# --- 4.2. Hostname ---
echo "Mengatur Hostname..."
echo "$hostname" > /etc/hostname

# --- 4.3. Users & Groups ---
echo "Membuat pengguna baru ($username)..."
useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$pw" | chpasswd
echo "root:$pw" | chpasswd

# ---- 4.4 App Mongodb ---


# --- 4.5. Sudoers Configuration ---
echo "Mengonfigurasi Sudoers..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-installer-wheel
chmod 440 /etc/sudoers.d/10-installer-wheel

# --- 4.6. Services Activation ---
echo "Mengaktifkan layanan sistem dasar..."
systemctl enable NetworkManager
systemctl enable firewalld
systemctl enable bluetooth.service
systemctl enable plasmalogin.service
systemctl enable --global pipewire-pulse

# --- 4.7 App payload cms ---

# --- 4.8. GRUB Setup  ---
echo "Memasang GRUB Bootloader ke Partisi Boot Sparow OS..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Sparow

echo "Mengonfigurasi parameter Kernel"
sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Sparow"/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="root=UUID='"$root_uuid"' quiet"/' /etc/default/grub
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

# Buat konfigurasi GRUB
grub-mkconfig -o /boot/grub/grub.cfg


EOF

log_success "Konfigurasi di dalam chroot berhasil diselesaikan!"
sleep 2

# --- CLEAN UP & FINISH ---
show_header
log_success "Instalasi Sparow OS telah selesai!"
log_info "Anda dapat me-reboot komputer Anda sekarang."
echo
