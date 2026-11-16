# install/30-apps.sh — bundled ARM64 applications and OxideTerm launcher
# Sourced in order by boards/z96a-v2/userscripts/uscripts.
# Phase 2 module split: content and execution order unchanged.



	# Locally verified ARM64 applications and custom mpv 0.41
	for pkg in \
		/opt/z96a/packages/OxideTerm_2.2.6_linux_arm64.deb \
		/opt/z96a/packages/thorium-browser_156.0.8078.28_arm64.deb \
		/opt/z96a/packages/deckcraft-0.11.1-linux-aarch64.deb \
		/opt/z96a/packages/gridcraft-0.12.1-linux-aarch64.deb \
		/opt/z96a/packages/wordcraft-0.11.0-linux-aarch64.deb \
		/opt/z96a/packages/WeChatLinux_arm64.deb \
		/opt/z96a/packages/QQ_3.2.34_260924_arm64_01.deb; do
		[ "$ENABLE_APPS" = "1" ] || continue
		install_required_deb "$pkg"
	done
	if [ "$ENABLE_MULTIMEDIA" = "1" ]; then
		install_required_deb /opt/z96a/packages/mpv_0.41.0-2_arm64_bookworm.deb
	fi
	# The two board-specific debs were built on Devuan and declare Devuan-only
	# package names.  On Ubuntu noble the shared objects are present under
	# renamed packages (libjpeg.so.62 -> libjpeg62, libpng16.so.16 -> the t64
	# package, logind -> systemd-logind) and there is no elogind at all, so apt
	# refuses to install them.  Force-installing them instead would leave a
	# broken dependency graph that `apt-get check` later rejects.  Publish a
	# small package that provides the expected virtual names, then let apt
	# resolve everything normally.
	if [ "${DISTRO:-}" = "ubuntu" ]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			libglib2.0-0t64 libx11-6 libxext6 libxss1 brightnessctl \
			libnotify-bin polkitd python3-gi gir1.2-gtk-3.0 \
			libjpeg62 libpng16-16t64 libpam0g libxft2 libxmu6 libxrandr2
		compat_src=$(mktemp -d)
		mkdir -p "$compat_src/DEBIAN"
		cat > "$compat_src/DEBIAN/control" <<'COMPATEOF'
Package: z96a-distro-compat
Version: 1.0
Architecture: all
Maintainer: z96a <z96a@localhost>
Section: metapackages
Priority: optional
Provides: elogind (= 255), libjpeg62-turbo (= 2.1.5), libpng16-16 (= 1.6.43), default-logind, logind, consolekit
Description: Virtual package names the z96a Devuan-built debs expect
 The board-specific slim and power-policy packages were compiled on Devuan and
 declare elogind, libjpeg62-turbo and libpng16-16.  On Ubuntu those shared
 objects ship under different package names; this package only publishes the
 names so dependency resolution succeeds.  It installs no files.
COMPATEOF
		dpkg-deb --build "$compat_src" /tmp/z96a-distro-compat_1.0_all.deb >/dev/null
		dpkg -i /tmp/z96a-distro-compat_1.0_all.deb >/dev/null
		rm -rf "$compat_src" /tmp/z96a-distro-compat_1.0_all.deb
	fi

	install_required_deb /opt/z96a/packages/slim_1.4.1-1devuan1+excalibur2+z96a2_arm64.deb
	install_required_deb /opt/z96a/packages/z96a-power-policy_1.0.2_arm64.deb
	if [ ! -x /opt/oxideterm/oxideterm-native ] || [ ! -f /usr/share/applications/com.oxideterm.app.desktop ]; then
		echo "OxideTerm package did not install its native binary or desktop entry" >&2
		exit 1
	fi
