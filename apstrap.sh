#!/bin/bash

# Expects an Arch with all partitions mounted and with a base system.

# TODO: vagrant

if [[ $EUID -ne 0 ]]; then
	echo "apstrap must be run as root."
	exit 1
fi

die() {
	echo " ERROR: $1"
	exit 1
}

ensure_installed() {
	pacman -Q "$1" 2>&1 > /dev/null
	if (( $? )); then
		echo " ==> Package not installed: $package!"

		yaourt --noconfirm -S $package 2>&1 > /dev/null
		if (( $? )); then
			echo " ==> Failed to install package!"
			exit 1
		fi
	fi
}

check_yaourt() {
	yaourt --help 2>&1 > /dev/null
	if [ $? != 127 ]; then
		echo " ==> Yaourt already installed."
		return 0
	fi
		
	echo "Installing yaourt."

	cd /tmp
	ensure_installed "wget" || exit 1
	wget http://aur.archlinux.org/packages/package-query/package-query.tar.gz
	tar zxvf package-query.tar.gz
	cd package-query
	makepkg -si --asroot
	cd ..
	wget http://aur.archlinux.org/packages/yaourt/yaourt.tar.gz
	tar zxvf yaourt.tar.gz
	cd yaourt
	makepkg -si --asroot
	cd ..
	rm -r package-query
	rm -r yaourt

	yaourt --help 2>&1 > /dev/null
	[ $? == 127 ] && die "yaourt installation failed!"

	echo " ==> Yaourt installed."
}

check_font() {
	config="/etc/vconsole.conf"
	[ ! -f $config ] && die "$config doesn't exist!"
	. $config
	[ $FONT != "ter-u12n" ] && die "Font not set to ter-u12n in $config!"

	echo " ==> Console font is OK."
}

check_hostname() {
	if [ ! -f "/etc/hostname" ]; then
		if [ -n "$HOSTNAME" ]; then
			echo "Setting hostname to $HOSTNAME."
			echo "$HOSTNAME" > /etc/hostname	
		else
			die "Hostname not set in /etc/hostname and hostname not specified!"
		fi
	fi

	if [ -n "$HOSTNAME" ]; then
		if [ "$HOSTNAME" != "`cat /etc/hostname`" ]; then
			die "Hostname should be $HOSTNAME, is `cat /etc/hostname`!"
		fi
	fi
	
	# TODO: check /etc/hosts
	echo " ==> Hostname OK."
}

check_timezone() {
	[ ! -f "/etc/localtime" ] && ln -s /usr/share/zoneinfo/Europe/Prague /etc/localtime
}

check_locale() {
	NEW_LANG="en_US.UTF-8"
	if [ ! -f /etc/locale.conf ]; then
		echo "Setting LANG to $NEW_LANG."
		echo "LANG=\"$NEW_LANG\"" > /etc/locale.conf
	else
		. /etc/locale.conf
		if [ "$LANG" != "$NEW_LANG" ]; then
			die "LANG is $LANG, but should be $NEW_LANG! Fix /etc/locale.conf."
		fi
	fi

	echo " ==> Locale OK. ($NEW_LANG)"
}

check_locale_gen() {
	# TODO: check double-apply
	if [ ! -f /etc/locale.gen ]; then
		die "/etc/locale.gen doesn't exist!"
	fi

	patch -p1 /etc/locale.gen uncomment-my-locale.patch -N -r-
	if (( $? )); then
		die "Error patching /etc/locale.gen!"
	fi
	locale-gen
}

get_package_selection() {
	PACKAGES=()

	# Console utils, font
	PACKAGES+=(mc wget elinks lynx tmux terminus-font gvim calc openssh alsa-utils colordiff sudo sux autojump powertop iftop iotop ack lftp)
	PACKAGES+=(acpi acpid pm-utils unrar zip macchanger smartmontools)
	PACKAGES+=(gcc patch grub-bios make mlocate bash-completion)
	PACKAGES+=(exfat-utils fuse-exfat nmap iptables dnsutils sshfs gnu-netcat)

	PACKAGES+=(fortune-mod)

	# TODO: drivery
	PACKAGES+=(wicd git)

	if (( $INSTALL_X )); then
		# X
		PACKAGES+=(xorg-server xorg-xdm xmonad xmonad-contrib xorg-xrandr xorg-xmodmap)

		# X applications
		PACKAGES+=(rxvt-unicode firefox gimp inkscape evince mplayer flashplugin vlc xscreensaver feh orage zim pidgin xclip geeqie lxappearance xvidcap)
		PACKAGES+=(scrot xloadimage graphviz eog konversation)

		# xosdutil dependencies
		PACKAGES+=(libconfig xosd font-bh-ttf)

		PACKAGES+=(lyx)

		# File sharing
		PACKAGES+=(amule transmission-gtk)

		PACKAGES+=(virtualbox)
		gpasswd -a prvak vboxusers 2>&1 > /dev/null

		# Libreoffice
		PACKAGES+=(libreoffice-base libreoffice-calc libreoffice-draw libreoffice-en-US libreoffice-gnome libreoffice-impress libreoffice-math libreoffice-writer)

		PACKAGES+=(xorg-xkill)
	
		PACKAGES+=(tuxguitar)

		(( $INSTALL_DEVEL )) && PACKAGES+=(monodevelop bless gcolor2 wireshark-gtk)
		(( $INSTALL_MUSIC )) && PACKAGES+=(fmit audacity)
		(( $INSTALL_GAMES )) && PACKAGES+=(freeciv ltris)
		(( $INSTALL_STUFF )) && PACKAGES+=(homebank sage urbanterror blender krusader chromium freemind mypaint)
		(( $INSTALL_ANDROID )) && PACKAGES+=(eclipse android-sdk eclipse-android)
		(( $INSTALL_TABLET )) && PACKAGES+=(mypaint xournal)
	fi

	PACKAGES+=(gnuplot)

	# texlive-most
	PACKAGES+=(texlive-core texlive-fontsextra texlive-formatsextra texlive-games texlive-genericextra)
	PACKAGES+=(texlive-htmlxml texlive-humanities texlive-latexextra texlive-music texlive-pictures)
	PACKAGES+=(texlive-plainextra texlive-pstricks texlive-publishers texlive-science)

	# Chce multilib
	#$INSTALL wine
	#$INSTALL skype

	# Fine tuning
	PACKAGES+=(cpupower e4rat)

	# For webcam-record
	PACKAGES+=(gstreamer0.10-good-plugins)

	PACKAGES+=(testdisk)

	(( $INSTALL_DEVEL )) && PACKAGES+=(subversion gdb valgrind ruby php ghc doxygen cmake swi-prolog markdown)
	(( $INSTALL_SERVERS )) && PACKAGES+=(lighttpd mysql apache)
	(( $INSTALL_MUSIC )) && PACKAGES+=(mpd ncmpcpp mpc vorbis-tools pulseaudio pulseaudio-alsa)
	(( $INSTALL_MAIL )) && PACKAGES+=(postfix mutt fetchmail procmail)
	(( $INSTALL_GAMES )) && PACKAGES+=(nethack adom slashem)
	(( $INSTALL_STUFF )) && PACKAGES+=(octave asymptote selenium-server-standalone)

	echo "${PACKAGES[@]}"
}

check_packages() {
	echo "Checking packages..."
	for package in `get_package_selection`; do
		# echo "    $package"
		ensure_installed "$package"
	done
	echo " ==> Packages OK."
}

check_user() {
	# TODO: vytvor tohodle uzivatele a jeho domaci adresar
	user="$1"
	echo "user check not implemented. please create user $1."
	#useradd -k prvak
}

check_user_environment() {
	user="$1"
	# TODO: v prvakovi to nechci mit read-only!
	# TODO: downloadni si dotfiles, scripts
	echo "user environment check not implemented. please check environment of user $1."

	#cd ~prvak
	#git clone git://github.com/MichalPokorny/dotfiles.git .
	#mkdir bin
	#git clone git://github.com/MichalPokorny/scripts.git bin
	#chown -R prvak:prvak ~prvak

	su "$user" -c "xmonad --recompile"

	if (( $? )); then
		die "Failed to recompile XMonad for $user!"
	else
		echo " ==> Recompiled XMonad of $user"
	fi
}

check_vgaswitcheroo() {
	tag="# Added by check.sh. Don't remove this line."
	grep "$tag" /etc/rc.local --quiet

	if (( $? )); then
		cat >> /etc/rc.local <<EOF

$tag
# Turn off vgaswitcheroo if present.
SWITCHER="/sys/kernel/debug/vgaswitcheroo/switch"
[ -f \$SWITCHER ] && echo OFF > \$SWITCHER
EOF
		echo " ==> Added vgaswitcheroo lines to /etc/rc.local"
	else
		echo " ==> /etc/rc.local already tagged, won't retag."
	fi
}

check_sudoers() {
	tag="# Added by check.sh. Don't remove this line."
	grep "$tag" /etc/sudoers --quiet

	if (( $? )); then
		cat >> /etc/sudoers <<EOF

$tag
# Allow mounting, unmounting and suspending.
prvak ALL=(ALL) NOPASSWD: /home/prvak/bin/cryptomount, /home/prvak/bin/cryptounmount, /usr/sbin/pm-suspend
EOF
		echo " ==> /etc/sudoers set"
	else
		echo " ==> /etc/sudoers already tagged, won't retag."
	fi
}

update() {
	yaourt -Syua --noconfirm 2>&1 > /dev/null
	if (( $? )); then
		die "Error updating system!"
	else
		echo " ==> System updated"
	fi
}

install_grub() {
	if [ -n "$DISK_DEVICE" ]; then
		grub-install "$DISK_DEVICE" # TODO: vybrat zarizeni!
		grub-mkconfig > /boot/grub/grub.cfg
		mkinitcpio -p linux
		echo " ==> GRUB installed"
	else
		echo " ==> Not installing GRUB: disk device unspecified"
	fi
}

patch_acpi_event_handler() {
	patch -p1 /etc/acpi/handler.sh handle-acpi-events.patch -N -r-
	if (( $? )); then
		die "Error patching /etc/acpi/handler.sh!"
	fi
}

check_gems() {
	GEMS=()

	# btcreport
	GEMS+=(eu_central_bank money mtgox)

	# incoming-mail
	GEMS+=(mail)

	gem install ${GEMS[@]}
	(( $? )) && die "Failed to install required gems for root!"
	su prvak sh -c "gem install ${GEMS[@]}"
	(( $? )) && die "Failed to install required gems for prvak!"
}

enable_daemons() {
	systemctl enable upower
	systemctl enable dbus
	(( $INSTALL_MUSIC )) && systemctl enable mpd
	(( $INSTALL_X )) && systemctl enable xdm
	(( $INSTALL_SERVERS )) && systemctl enable mysqld
}

check_system() {
	check_yaourt
	check_hostname
	check_timezone
	check_font
	check_locale
	check_packages
	check_gems
	check_locale_gen

	check_user "prvak"

	check_user_environment "root"
	check_user_environment "prvak"

	# TODO: check GRUB

	# TODO: xosdutil spravne nainstalovana

	# TODO: mount -a, a je primontovany debugfs
	# TODO: sudo-veci jdou

	#echo "none /sys/kernel/debug debugfs defaults 0 0" >> /etc/fstab
	#cat >> /etc/rc.local <<EOF
	#EOF

	check_vgaswitcheroo
	check_sudoers

	patch_acpi_event_handler

	update

	install_grub

	enable_daemons

	echo "Most drone work done. The remaining stuff:"
	echo "    Configure /etc/hosts: add l-alias, hostname alias"
	echo "    Configure the web server."

	# TODO:
	#/etc/lighttpd/lighttpd.conf; lighttpd do demonu
	#mkdir -p /srv/http/public
}

INSTALL_SERVERS=1
INSTALL_ANDROID=1
INSTALL_MAIL=1
INSTALL_STUFF=1
INSTALL_DEVEL=1
INSTALL_GAMES=1
INSTALL_MUSIC=1
INSTALL_TABLET=1
INSTALL_X=1
HOSTNAME=""
DISK_DEVICE=""

echo "apstrap by prvak"
check_system

# TODO: echo "vboxdrv" >> /etc/modules-load.d/virtualbox.conf
# TODO: blacklist pcspkr
