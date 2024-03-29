#!/bin/bash

# Intall different packages according to GPU vendor (Intel, AMDGPU) 
cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq)
gpu_drivers=""
libva_environment_variable=""
vdpau_environment_variable=""
if [[ $cpu_vendor =~ "AuthenticAMD" ]]
then
 gpu_drivers="xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau"
 libva_environment_variable="export LIBVA_DRIVER_NAME=radeonsi"
elif [[ $cpu_vendor =~ "GenuineIntel" ]]
then
 gpu_drivers="vulkan-intel lib32-vulkan-intel intel-media-driver libvdpau-va-gl"
 libva_environment_variable="export LIBVA_DRIVER_NAME=iHD"
 vdpau_environment_variable="export VDPAU_DRIVER=va_gl"
fi

echo "Adding multilib support"
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

echo "Syncing repos and updating packages"
sudo pacman -Syu --noconfirm

echo "Installing and configuring UFW"
sudo pacman -S --noconfirm ufw
sudo systemctl enable ufw
sudo systemctl start ufw
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Installing GPU drivers"
sudo pacman -S --noconfirm mesa lib32-mesa $gpu_drivers

echo "Improving hardware video accelaration"
sudo pacman -S --noconfirm ffmpeg libva-utils libva-vdpau-driver vdpauinfo

# Reference: https://github.com/lutris/docs/blob/master/WineDependencies.md
echo "Installing Lutris (with Wine support)"
sudo pacman -S --noconfirm lutris wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader

echo "Installing common applications"
sudo pacman -S --noconfirm vim keepassxc git openssh links upower htop powertop p7zip ripgrep unzip fwupd unrar

echo "Adding Flathub repository (Flatpak)"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "Installing Flatpak GTK breeze themes"
flatpak --assumeyes install org.gtk.Gtk3theme.Breeze
flatpak --assumeyes install org.gtk.Gtk3theme.Breeze-Dark

echo "Installing Firefox Flatpak"
flatpak --assumeyes install flathub org.mozilla.firefox

echo "Improving font rendering issues with Firefox Flatpak"	
mkdir -p ~/.var/app/org.mozilla.firefox/config/fontconfig	
touch ~/.var/app/org.mozilla.firefox/config/fontconfig/fonts.conf	
tee -a ~/.var/app/org.mozilla.firefox/config/fontconfig/fonts.conf << EOF	
<?xml version='1.0'?>	
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>	
<fontconfig>	
    <!-- Disable bitmap fonts. -->	
    <selectfont><rejectfont><pattern>	
        <patelt name="scalable"><bool>false</bool></patelt>	
    </pattern></rejectfont></selectfont>	
</fontconfig>	
EOF

echo "Installing chromium with GPU acceleration"
sudo pacman -S --noconfirm chromium
mkdir -p ~/.config/
touch ~/.config/chromium-flags.conf
tee -a ~/.config/chromium-flags.conf << EOF
--ignore-gpu-blacklist
--enable-gpu-rasterization
--enable-zero-copy
EOF

echo "Creating user's folders"
sudo pacman -S --noconfirm xdg-user-dirs

echo "Installing fonts"
sudo pacman -S --noconfirm ttf-roboto ttf-roboto-mono ttf-droid ttf-opensans ttf-dejavu ttf-liberation ttf-hack noto-fonts ttf-fira-code ttf-fira-mono ttf-font-awesome noto-fonts-emoji ttf-hanazono adobe-source-code-pro-fonts

echo "Downloading wallpapers and Arch Linux icon"
mkdir -p ~/Pictures/wallpapers
wget -P ~/Pictures/ https://raw.githubusercontent.com/exah-io/minimal-arch-linux/master/images/arch.png
wget -P ~/Pictures/wallpapers/ https://raw.githubusercontent.com/exah-io/minimal-arch-linux/master/images/wallpapers/tony-liao-8RQi94ZHovg-unsplash.jpg
wget -P ~/Pictures/wallpapers/ https://raw.githubusercontent.com/exah-io/minimal-arch-linux/master/images/wallpapers/dan-aragon-n20DUSVsUk8-unsplash.jpg

echo "Ricing bash"
touch ~/.bashrc
tee -a ~/.bashrc << EOF
$libva_environment_variable
$vdpau_environment_variable

export PS1="\w \\$  "
PROMPT_COMMAND='PROMPT_COMMAND='\''PS1="\n\w \\$  "'\'

alias upa="sudo rm -f /var/lib/pacman/db.lck && sudo pacman -Syu && yay -Syu --aur && flatpak update && fwupdmgr refresh && fwupdmgr update"
EOF

echo "Installing yay"
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ..
rm -rf yay-bin

echo "Installing and configuring Plymouth"
yay -S --noconfirm plymouth-git
sudo sed -i 's/base systemd autodetect/base systemd sd-plymouth autodetect/g' /etc/mkinitcpio.conf
sudo sed -i 's/quiet rw/quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 rw/g' /boot/loader/entries/arch.conf
sudo sed -i 's/quiet rw/quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 rw/g' /boot/loader/entries/arch-lts.conf
sudo mkinitcpio -p linux
sudo mkinitcpio -p linux-lts
sudo plymouth-set-default-theme -R bgrt

echo "Installing and starting thermald"
sudo pacman -S --noconfirm thermald
sudo systemctl start thermald.service
sudo systemctl enable thermald.service

echo "Enabling audio power saving features"
sudo touch /etc/modprobe.d/audio_powersave.conf
sudo tee -a /etc/modprobe.d/audio_powersave.conf << EOF
options snd_hda_intel power_save=1
EOF

echo "Enabling wifi (iwlwifi) power saving features"
sudo touch /etc/modprobe.d/iwlwifi.conf
sudo tee -a /etc/modprobe.d/iwlwifi.conf << EOF
options iwlwifi power_save=1
EOF

echo "Reducing VM writeback time"
sudo touch /etc/sysctl.d/dirty.conf
sudo tee -a /etc/sysctl.d/dirty.conf << EOF
vm.dirty_writeback_centisecs = 1500
EOF

echo "Improving Java applications font rendering"
sudo tee -a /etc/environment << EOF
_JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=gasp'
JAVA_FONTS=/usr/share/fonts/TTF
EOF

echo "Enabling bluetooth"
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

echo "Disabling root (still allows sudo)"
passwd --lock root

echo "Adding NTFS support"
sudo pacman -S --noconfirm ntfs-3g

# echo "Install syncthing with autostart on boot"
# sudo pacman -S --noconfirm syncthing
# sudo systemctl enable syncthing@USERNAME-CHANGE-ME.service
# sudo systemctl start syncthing@USERNAME-CHANGE-ME.service
# sudo ufw allow syncthing

# echo "Installing Node.js LTS"
# sudo pacman -S --noconfirm nodejs-lts-erbium

# echo "Increasing the amount of inotify watchers"
# echo fs.inotify.max_user_watches=524288 | sudo tee /etc/sysctl.d/40-max-user-watches.conf && sudo sysctl --system

# echo "Installing zsh"
# sudo pacman -S --noconfirm zsh zsh-completions
# chsh -s /usr/bin/zsh

# echo "Installing powerlevel10k theme"
# git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
# wget -P ~/ https://raw.githubusercontent.com/exah-io/minimal-arch-linux/master/dotfiles/zsh/.p10k.zsh
# wget -P ~/ https://raw.githubusercontent.com/exah-io/minimal-arch-linux/master/dotfiles/zsh/.zshrc
