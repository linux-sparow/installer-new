#!/bin/bash
read -p "input partition root:" PROC
read -p "input partition boot:" BOOT
read -p "input username : " USERNAME
read -sp "input password : " PASSWORD

echo 'Installing Sparow OS' && 

mkfs.ext4 $PROC &&
mount $PROC /mnt &&
mkfs.vfat -F32 $BOOT &&
mkdir -p /mnt/boot &&
mount $BOOT /mnt/boot &&

if grep -q "GenuineIntel" /proc/cpuinfo; then
    pacstrap /mnt intel-ucode base base-devel linux linux-firmware grub efibootmgr os-prober wireless-regdb sof-firmware bluez-utils  networkmanager dolphin xorg-server pipewire pipewire-alsa pipewire-jack pipewire-pulse mkinitcpio discover firefox plasma-login-manager plasma-nm plasma-pa xdg-desktop-portal-kde systemsettings spectacle plasma-desktop breeze-gtk breeze-cursors breeze plasma-workspace bluedevil --noconfirm
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    pacstrap /mnt amd-ucode base base-devel linux linux-firmware grub efibootmgr os-prober wireless-regdb sof-firmware bluez-utils  networkmanager dolphin xorg-server pipewire pipewire-alsa pipewire-jack pipewire-pulse mkinitcpio discover firefox plasma-login-manager plasma-nm plasma-pa xdg-desktop-portal-kde systemsettings spectacle plasma-desktop breeze-gtk breeze-cursors breeze plasma-workspace bluedevil --noconfirm
else
    echo "Unknown CPU"
    exit 1
fi

## config
git clone https://github.com/linux-sparow/installer-new.git installer &&
cp -fr installer/config/* /mnt/ &&
rm -fr installer &&

## fstab
genfstab -U /mnt > /mnt/etc/fstab && 

## network
cp /etc/systemd/network/* /mnt/etc/systemd/network &&

## locale
arch-chroot /mnt locale-gen &&

##clock
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime &&
arch-chroot /mnt hwclock --systohc &&

## main user
arch-chroot /mnt useradd -m $USERNAME &&
arch-chroot /mnt passwd $PASSWORD &&
echo "$USERNAME ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/user &&


## kernel parameter
echo "root=/dev/$PROC" > /mnt/etc/cmdline.d/01-boot.conf &&


## initramfs
rm -fr /mnt/etc/mkinitcpio.conf.d && rm /mnt/etc/mkinitcpio.conf &&

## boot
mkdir -p /mnt/boot/{efi,kernel} &&
mkdir -p /mnt/boot/efi/{linux,boot,systemd} &&
mv /mnt/boot/vmlinuz-* /mnt/boot/kernel/ &&
mv /mnt/boot/*-ucode.img /mnt/boot/kernel/ &&

## grub
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub && 
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=sparow &&
arch-chroot /mnt grub-mkconfig -o /boot/grub/custom.cfg &&

## generate efi
arch-chroot /mnt mkinitcpio -P &&

## enable service
systemctl --root=/mnt enable NetworkManager &&


## desktop service
systemctl --root=/mnt enable bluetooth.service &&
systemctl --root=/mnt enable plasmalogin.service &&
systemctl --root=/mnt enable --global pipewire-pulse &&

echo 'finish'
