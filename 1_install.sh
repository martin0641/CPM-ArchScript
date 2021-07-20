#!/bin/bash

encryption_passphrase="bananas"
root_password="123!@#qweQWE"
user_password="123!@#qweQWE"
hostname="archscripts"
user_name="anon"
continent_city="America/New_York"
swap_size="1"

# Set different microcode, kernel params and initramfs modules according to CPU vendor
cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq)
cpu_microcode=""
kernel_options=""
initramfs_modules=""
if [[ $cpu_vendor =~ "AuthenticAMD" ]]
then
 cpu_microcode="amd-ucode"
# initramfs_modules="amdgpu"
elif [[ $cpu_vendor =~ "GenuineIntel" ]]
then
 cpu_microcode="intel-ucode"
# kernel_options=" i915.fastboot=1 i915.enable_fbc=1 i915.enable_guc=2"
# initramfs_modules="intel_agp i915"
fi

echo "Unmounting just in case..."
umount -l /dev/vg0/root /mnt
umount -l /dev/nvme0n1p1 /mnt/boot
rmdir /mnt/boot


echo "Updating system clock"
timedatectl set-ntp true

echo "Syncing packages database"
pacman -Sy --noconfirm --needed --asdeps --noprogressbar

echo "Creating Crypt Locking folder"
mkdir /run/cryptsetup
chmod 700 /run/cryptsetup

echo "Wiping Disks"
wipefs -af /dev/nvme0n1 > /dev/null 2>&1
wipefs -af /dev/nvme0n2 > /dev/null 2>&1
wipefs -af /dev/sda > /dev/null 2>&1
wipefs -af /dev/sdb > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n1 count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n1 count=2048 seek=$((`blockdev --getsz /dev/nvme0n1` - 2048)) # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n2 count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n2 count=2048 seek=$((`blockdev --getsz /dev/nvme0n2` - 2048)) # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/sda count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/sda count=2048 seek=$((`blockdev --getsz /dev/sda` - 2048)) # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/sdb count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/sdb count=2048 seek=$((`blockdev --getsz /dev/sdb` - 2048)) # > /dev/null 2>&1

echo "Creating partition tables"
printf "n\n1\n2048\n512M\nef00\nw\ny\n" | gdisk /dev/nvme0n1
printf "n\n2\n\n\n8e00\nw\ny\n" | gdisk /dev/nvme0n1
printf "n\n1\n\n\n8e00\nw\ny\n" | gdisk /dev/nvme0n2

echo "Wiping Filesystems"
dd bs=512 if=/dev/zero of=/dev/nvme0n1p1 count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n1p1 count=2048 seek=$((`blockdev --getsz /dev/nvme0n1p1` - 2048)) # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n1p2 count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n1p2 count=2048 seek=$((`blockdev --getsz /dev/nvme0n1p2` - 2048)) # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n2p1 count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n2p1 count=2048 seek=$((`blockdev --getsz /dev/nvme0n2p1` - 2048)) # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n2p2 count=2048 # > /dev/null 2>&1
dd bs=512 if=/dev/zero of=/dev/nvme0n2p2 count=2048 seek=$((`blockdev --getsz /dev/nvme0n2p2` - 2048)) # > /dev/null 2>&1

#cat /dev/zero > /dev/nvme0n1p1 > /dev/null 2>&1
#cat /dev/zero > /dev/nvme0n1p2 > /dev/null 2>&1
#cat /dev/zero > /dev/nvme0n2p1 > /dev/null 2>&1
#cat /dev/zero > /dev/nvme0n2p2 > /dev/null 2>&1

echo "Setting up cryptographic volume"
printf "%s" "$encryption_passphrase" | cryptsetup -h sha512 -s 512 --use-random --type luks2 luksFormat /dev/nvme0n1p2
printf "%s" "$encryption_passphrase" | cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm

echo "Creating physical volume"
pvcreate /dev/mapper/cryptlvm
#pvcreate /dev/nvme0n2

echo "Creating volume volume"
vgcreate vg0 /dev/mapper/cryptlvm
#vgcreate vg1 /dev/nvme0n2

echo "Creating logical volumes"
lvcreate -L +"$swap_size"GB vg0 -n swap
lvcreate -l +100%FREE vg0 -n root
#lvcreate -l +100%FREE vg1 -n data

echo "Setting up / partition"
yes | mkfs.f2fs /dev/vg0/root
mount /dev/vg0/root /mnt

echo "Setting up /boot partition"
yes | mkfs.fat -F32 /dev/nvme0n1p1
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

#echo "Setting up /data partition"
#yes | mkfs.f2fs /dev/vg1/data
#mkdir /mnt/data
#mount /dev/nvme0n2p1 /mnt/data

echo "Setting up swap"
yes | mkswap /dev/vg0/swap
swapon /dev/vg0/swap

echo "Installing Arch Linux"
yes '' | pacstrap /mnt base cryptsetup base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware lvm2 device-mapper e2fsprogs $cpu_microcode freetype2 networkmanager wget man-db man-pages nano diffutils flatpak lm_sensors neofetch nmon lshw dhclient f2fs-tools git grub fish mesa man-db nano openssh screen vim which bonnie++ python atop sysstat nfs-utils open-iscsi multipath-tools open-vm-tools iperf time hdparm fio bc pv gnuplot msmtp mailx gptfdisk aurpublish lynx libzip oniguruma php tcl openmp kmod libglvnd fish perf

echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Configuring new system"
arch-chroot /mnt /bin/bash <<EOF
echo "Setting system clock"
ln -sf /usr/share/zoneinfo/$continent_city /etc/localtime
hwclock --systohc --localtime

echo "Setting locales"
echo "LANG=en_US.UTF-8" >> /etc/environment
echo "LC_ALL=en_US.UTF-8" >> /etc/environment
echo "LC_MESSAGES=en_US.UTF-8" >> /etc/environment
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANGUAGE=en_US.UTF-8" >> /etc/locale.conf
echo "LC_MESSAGES=en_US.UTF-8" >> /etc/locale.conf

locale-gen

echo "Adding persistent keymap"
echo "KEYMAP=us" > /etc/vconsole.conf

echo "Setting hostname"
echo $hostname > /etc/hostname

echo "Setting root password"
echo -en "$root_password\n$root_password" | passwd

echo "Setting shells"
echo -en "chsh -s /bin/fish root"
echo -en "chsh -s /bin/fish $user_name"

echo "Creating new user"
useradd -m -G wheel -s /bin/bash $user_name
usermod -a -G video $user_name
echo -en "$user_password\n$user_password" | passwd $user_name

echo "Generating initramfs"
#sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block filesystems sd-encrypt lvm2 filesystems f2fs fsck)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block filesystems sd-encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf

sed -i 's/^MODULES.*/MODULES=(ext4 $initramfs_modules)/' /etc/mkinitcpio.conf
sed -i 's/#COMPRESSION="lz4"/COMPRESSION="lz4"/g' /etc/mkinitcpio.conf
mkinitcpio -p linux
mkinitcpio -p linux-lts

echo "Setting up systemd-boot"
bootctl --path=/boot install

mkdir -p /boot/loader/
echo ' ' > /boot/loader/loader.conf
tee -a /boot/loader/loader.conf << END
default arch.conf
timeout 0
editor 0
END

mkdir -p /boot/loader/entries/
touch /boot/loader/entries/arch.conf
tee -a /boot/loader/entries/arch.conf << END
title Arch Linux
linux /vmlinuz-linux
initrd /$cpu_microcode.img
initrd /initramfs-linux.img
#options rd.luks.name=$(blkid -s UUID -o value /dev/nvme0n1p2)=cryptlvm root=/dev/vg0/root resume=/dev/vg0/swap rd.luks.options=discard$kernel_options nmi_watchdog=0 quiet rw
options rd.luks.name=$(blkid -s UUID -o value /dev/nvme0n1p2)=cryptlvm root=/dev/vg0/root resume=/dev/vg0/swap rd.luks.options=nmi_watchdog=0 quiet rw

END

touch /boot/loader/entries/arch-lts.conf
tee -a /boot/loader/entries/arch-lts.conf << END
title Arch Linux LTS
linux /vmlinuz-linux-lts
initrd /$cpu_microcode.img
initrd /initramfs-linux-lts.img
#options rd.luks.name=$(blkid -s UUID -o value /dev/nvme0n1p2)=cryptlvm root=/dev/vg0/root resume=/dev/vg0/swap rd.luks.options=discard$kernel_options nmi_watchdog=0 quiet rw
options rd.luks.name=$(blkid -s UUID -o value /dev/nvme0n1p2)=cryptlvm root=/dev/vg0/root resume=/dev/vg0/swap rd.luks.options=nmi_watchdog=0 quiet rw

END

echo "Updating systemd-boot"
bootctl --path=/boot update

echo "Setting up Pacman hook for automatic systemd-boot updates"
mkdir -p /etc/pacman.d/hooks/
touch /etc/pacman.d/hooks/systemd-boot.hook
tee -a /etc/pacman.d/hooks/systemd-boot.hook << END
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
END

echo "Enabling SSHD"
echo "permitrootlogin yes" >> /etc/ssh/sshd_config
systemctl enable sshd

echo "Enabling periodic TRIM"
systemctl enable fstrim.timer

echo "Enabling NetworkManager"
systemctl enable NetworkManager

echo "Modifying SUDO"
echo 'anon ALL=(ALL:ALL) NOPASSWD: ALL' | EDITOR='tee -a' visudo
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' | EDITOR='tee -a' visudo
echo '%admin ALL=(ALL:ALL) NOPASSWD: ALL' | EDITOR='tee -a' visudo

#echo "Installing YAY"
#cd /opt
#git clone https://aur.archlinux.org/yay-git.git
#chown -R anon:anon /opt/yay-git
#su anon
#cd /opt/yay-git
#makepkg -sicr --noconfirm

#echo "Installing S"
#cd /opt
#sudo git clone https://github.com/Algodev-github/S.git
#sudo chown -R anon:anon /opt/Sls


#echo "Installing iperf3"
#cd /opt
#sudo su
#git clone https://github.com/esnet/iperf.git
#mv iperf iperf3
#chown -R anon:anon ./iperf3
#cd /opt/iperf3
#./configure
#make
#make install

#echo "Installing iperf"
#cd /opt
#git clone https://github.com/esnet/iperf.git
#mv iperf/ iperf2-code
#chown -R anon:anon ./iperf2-code
#cd /opt/iperf2-code
#./configure
#make
#make install

su anon

#yay -S unixbench --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --removemake
#yay -S pscheduler --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --removemake
#yay -S interbench --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --removemake
#yay -S nuttcp --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --removemake
#yay -S dcfldd --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --removemake
#yay -S phoronix-test-suite-git --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --removemake
#yay -S dcfldd --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --rebuildtree --removemake
#yay -S jobber --noprovides --answerclean all --answerdiff none --answeredit none --answerupgrade 1 --rebuildtree --removemake --clean

#sudo su
#echo "Installing Powershell"
#curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.1.0-rc.2/powershell-7.1.0-rc.2-linux-x64.tar.gz
#sudo mkdir -p /opt/microsoft/powershell/7
#sudo chown -R anon:anon /opt/microsoft
#su anon
#sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
#sudo chmod +x /opt/microsoft/powershell/7/pwsh
#sudo ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
sudo su

#echo "Installing PowerCLI"
#pwsh
#Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#install-module -name VMware.PowerCLI -force
#'Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip \$false -Confirm:\$false -InvalidCertificateAction Ignore'
#install-module -name Posh-SSH
#Find-Module -Name *vmware* | install-module
#Find-Module -Name *AdminToolbox* | install-module
#Find-Module -Name *PureStorage* | install-module
#Find-Module -Name *AdminToolbox* | install-module
EOF

#umount -R /mnt
#swapoff -a

#echo "Arch Linux is ready. You can reboot now!"
#reboot
