#!/bin/bash

die() {
	echo " ==> $1"
	exit 1
}

ensure_installed() {
	pacman -Q "$1" > /dev/null
	if (( $? )); then
		echo " ==> Package not installed: $package!"

		# TODO: co yaourtove baliky?
		pacman --noconfirm -S $package
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
	# patch -p1 /etc/locale.gen uncomment-my-locale.patch
	# locale-gen
	echo "check_locale_gen unimplemented."
}

get_package_selection() {
	PACKAGES=()

	# Console utils, font
	PACKAGES+=(mc wget elinks tmux terminus-font gvim calc openssh alsa-utils colordiff sudo sux autojump powertop iftop iotop ack lftp)
	PACKAGES+=(acpi acpid pm-utils unrar zip)
	PACKAGES+=(gcc patch grub-bios make)

	# TODO: drivery
	PACKAGES+=(wicd git)

	# X
	PACKAGES+=(xorg-server xorg-xdm xmonad xmonad-contrib)

	# X applications
	PACKAGES+=(rxvt-unicode firefox gimp inkscape evince mplayer flashplugin vlc xscreensaver feh orage zim pidgin xclip geeqie lxappearance xvidcap)

	# xosdutil dependencies
	PACKAGES+=(libconfig xosd font-bh-ttf)

	# (La)TeX
	PACKAGES+=(lyx gnuplot)

	# File sharing
	PACKAGES+=(amule transmission-gtk)

	PACKAGES+=(virtualbox)

	# Chce multilib
	#$INSTALL wine
	#$INSTALL skype

	# Libreoffice.
	PACKAGES+=(libreoffice-base libreoffice-calc libreoffice-draw libreoffice-en-US libreoffice-gnome libreoffice-impress libreoffice-math libreoffice-writer)

	# Fine tuning
	PACKAGES+=(cpupower e4rat)

	PACKAGES+=(testdisk)

	(( $INSTALL_DEVEL )) && PACKAGES+=(subversion gdb valgrind monodevelop ruby php ghc)
	(( $INSTALL_SERVERS )) && PACKAGES+=(lighttpd mysql apache)
	(( $INSTALL_MUSIC )) && PACKAGES+=(mpd ncmpcpp mpc)
	(( $INSTALL_MAIL )) && PACKAGES+=(postfix mutt fetchmail procmail)
	(( $INSTALL_GAMES )) && PACKAGES+=(nethack adom slashem freeciv)
	(( $INSTALL_STUFF )) && PACKAGES+=(homebank sage urbanterror blender krusader)
	(( $INSTALL_ANDROID )) && PACKAGES+=(eclipse android-sdk)
	echo "${PACKAGES[@]}"
}

check_packages() {
	echo "Checking packages..."
	for package in `get_package_selection`; do
	#	echo "    $package"
		ensure_installed "$package"
	done
	echo " ==> Packages OK."
}

check_user() {
	user="$1"
	echo "user check not implemented"
	#useradd -k prvak
}

# TODO: xmonad --recompile

check_user_environment() {
	directory="$1"
	# TODO: downloadni si dotfiles, scripts
	echo "user environment check not implemented"

	#cd ~prvak
	#git clone git://github.com/MichalPokorny/dotfiles.git .
	#mkdir bin
	#git clone git://github.com/MichalPokorny/scripts.git bin
	#chown -R prvak:prvak ~prvak
}

check_system() {
	check_yaourt
	check_hostname
	check_timezone
	check_font
	check_locale_gen
	check_locale
	check_packages

	check_user "prvak"

	check_user_environment "~root"
	check_user_environment "~prvak"

	# TODO: check GRUB

	# TODO: dotfiles a binfiles v prvakovi i rootovi
	# TODO: xosdutil spravne nainstalovana

	# TODO: mount -a, a je primontovany debugfs
	# TODO: sudo-veci jdou

	#echo "none /sys/kernel/debug debugfs defaults 0 0" >> /etc/fstab
	#cat >> /etc/rc.local <<EOF
	#SWITCHER="/sys/kernel/debug/vgaswitcheroo/switch"
	#[ -f \$SWITCHER ] && echo OFF > \$SWITCHER
	#EOF

	#echo 'prvak ALL=(ALL) NOPASSWD: /home/prvak/bin/cryptomount, /home/prvak/bin/cryptounmount, /usr/sbin/pm-suspend' >> /etc/sudoers

	#yaourt -Syua --noconfirm
}

install_grub() {
	grub-install /dev/sdb # TODO: vybrat zarizeni!
	grub-mkconfig > /boot/grub/grub.cfg
	mkinitcpio -p linux
}

INSTALL_SERVERS=1
INSTALL_ANDROID=1
INSTALL_MAIL=1
INSTALL_STUFF=1
INSTALL_DEVEL=1
INSTALL_GAMES=1
INSTALL_MUSIC=1
HOSTNAME=""

check_system
