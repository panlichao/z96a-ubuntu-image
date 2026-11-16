# install/20-multimedia.sh — mpv config, default video mime types, glib schemas
# Sourced in order by boards/z96a-v2/userscripts/uscripts.
# Phase 2 module split: content and execution order unchanged.



	install -d -m 0755 /home/user/.config/mpv
	# Ubuntu noble ships mpv 0.37, which predates the v4l2request decoder; asking
	# for it there makes playback fail instead of falling back, so use the
	# generic safe auto-detection on that distro.
	if [ "${DISTRO:-}" = "ubuntu" ]; then
		mpv_hwdec="hwdec=auto-safe"
	else
		mpv_hwdec="hwdec=v4l2request"
	fi
	cat > /home/user/.config/mpv/mpv.conf <<MPVEOF
${mpv_hwdec}
vo=gpu
gpu-context=x11egl
gpu-dumb-mode=yes
dither=no
MPVEOF
	chown -R user:user /home/user/.config/mpv
	# xdg-mime runs as the target user and writes ~/.config/mimeapps.list; earlier
	# package postinsts can leave parts of the home directory root-owned, which
	# silently dropped every default-application association.
	if [ -d /home/user/.config ]; then chown -R user:user /home/user/.config; fi
	# Use upstream mpv for zero-copy v4l2request; Celluloid's distro libmpv
	# does not expose the V4L2 Request hardware decoder, so keep it only as a fallback.
	for mime in \
		video/mp4 video/x-matroska video/webm video/x-msvideo \
		video/quicktime video/x-m4v video/mp2t video/x-flv \
		video/mpeg video/x-theora+ogg; do
		runuser -u user -- env HOME=/home/user xdg-mime default mpv.desktop "$mime" || true
	done
