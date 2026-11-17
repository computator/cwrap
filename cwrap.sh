#!/bin/sh
set -eu

dbg=
if [ "${1-}" = '-d' ] || [ "${1-}" = '--debug' ]; then
	dbg=1
	shift
fi

bwrap=$(command -v bwrap || true)
if [ -z "$bwrap" ]; then
	echo "ERROR: the 'bwrap' command was not found. Bubblewrap is required!" >&2
	exit 1
elif [ $dbg ]; then
	echo "dbg: Bubblewrap command found: ${bwrap}" >&2
fi

cmd=
case "${1-}" in
	sh|bash|zsh|codex) cmd="$1"; shift ;;
	*) cmd="codex" ;;
esac

: \
	"${CWRAP_CODEX_ROOT:="$HOME/.local/cwrap-codex"}" \
	"${PROJECT_ROOT:="$(git rev-parse --show-toplevel --path-format=relative 2> /dev/null || true)"}"
git_root=
if [ -n "${PROJECT_ROOT}" ]; then
	git_root=$(git -C "${PROJECT_ROOT}" rev-parse --git-dir)
fi
: "${PROJECT_ROOT:=$PWD}"

mkdir -p "${CWRAP_CODEX_ROOT}"

[ $dbg ] && cat <<-EOF >&2
	dbg: Detected values:
	dbg: CWRAP_CODEX_ROOT=${CWRAP_CODEX_ROOT}
	dbg: PROJECT_ROOT=${PROJECT_ROOT}
	dbg: git_root=${git_root}
EOF

# start echoing to log the bwrap command
[ $dbg ] && set -x

exec $bwrap \
	--unshare-all \
	--share-net \
	--new-session \
	--die-with-parent \
	--clearenv \
	--setenv CODEX_INSTALL_DIR /codex \
	--setenv HOME /codex \
	--setenv CODEX_HOME /codex \
	--setenv PATH /usr/bin:/codex \
	--bind "${CWRAP_CODEX_ROOT}" /codex \
	--bind "${PROJECT_ROOT}" "${PROJECT_ROOT}" \
	--ro-bind-try "${PROJECT_ROOT}/${git_root:-.git}" "${PROJECT_ROOT}/${git_root:-.git}" \
	--ro-bind /usr/bin /usr/bin \
	--symlink /usr/bin /bin \
	--ro-bind-try /etc/alternatives /etc/alternatives \
	--ro-bind /usr/lib /usr/lib \
	--symlink /usr/lib /lib \
	--ro-bind /usr/lib64 /usr/lib64 \
	--symlink /usr/lib64 /lib64 \
	--ro-bind /etc/resolv.conf /etc/resolv.conf \
	--ro-bind /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt \
	--dev /dev \
	--proc /proc \
	--dir /tmp \
	"$cmd" "$@"
