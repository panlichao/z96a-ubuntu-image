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
	install_required_deb /opt/z96a/packages/slim_1.4.1-1devuan1+excalibur2+z96a2_arm64.deb

	# z96a-power-policy's control declares Depends: elogind (Devuan-only) and
	# slim (>= 1.4.0-0devuan2+z96a2), neither of which exists verbatim on
	# Ubuntu noble.  The binary itself only links glib/gio/X11/Xext/Xss/libc,
	# all available on noble (glib is now libglib2.0-0t64).  Install its real
	# runtime libraries first, then force-install the deb with dependency
	# checking disabled; it uses systemd-logind over D-Bus at runtime.
	if [ "${DISTRO:-}" = "ubuntu" ]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			libglib2.0-0t64 libx11-6 libxext6 libxss1 brightnessctl \
			libnotify-bin polkitd python3-gi gir1.2-gtk-3.0 2>/dev/null || true
		pp=/opt/z96a/packages/z96a-power-policy_1.0.2_arm64.deb
		[ -f "$pp" ] || { echo "Missing required package: $pp" >&2; exit 1; }
		dpkg -i --force-depends "$pp" || { echo "power-policy install failed" >&2; exit 1; }
	else
		install_required_deb /opt/z96a/packages/z96a-power-policy_1.0.2_arm64.deb
	fi
	if [ ! -x /opt/oxideterm/oxideterm-native ] || [ ! -f /usr/share/applications/com.oxideterm.app.desktop ]; then
		echo "OxideTerm package did not install its native binary or desktop entry" >&2
		exit 1
	fi
