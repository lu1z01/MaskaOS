#!/bin/sh
# Valida o ambiente de build. Somente leitura: nao instala nem altera nada.
# Saida: OK / FALTA / AVISO por item. Codigo de saida 1 se faltar algo obrigatorio.

missing=0

ok()   { printf 'OK     %s\n' "$1"; }
warn() { printf 'AVISO  %s\n' "$1"; }
miss() { printf 'FALTA  %s\n' "$1"; missing=1; }

os=$(uname -s)
printf 'Sistema: %s | Arquitetura: %s\n' "$os" "$(uname -m)"

if [ "$os" != "Linux" ]; then
	miss "host $os: o live-build exige Linux. Use uma VM Debian 13, conteiner privilegiado ou WSL2 (docs/build-plan.md)"
	exit 1
fi

if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	printf 'Distro: %s %s\n' "${NAME:-?}" "${VERSION_ID:-?}"
	case "${ID:-}${ID_LIKE:-}" in
		*debian*|*ubuntu*) ok "base compativel com live-build (Debian/Ubuntu)" ;;
		*) warn "base ${ID:-desconhecida}: nao testada; prefira Debian 13" ;;
	esac
fi

ram_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
if [ -n "$ram_kb" ]; then
	ram_gb=$((ram_kb / 1024 / 1024))
	if [ "$ram_gb" -ge 4 ]; then ok "RAM ${ram_gb} GB"; else warn "RAM ${ram_gb} GB (recomendado >= 4 GB)"; fi
fi

free_kb=$(df -Pk . | awk 'NR==2 {print $4}')
free_gb=$((free_kb / 1024 / 1024))
if [ "$free_gb" -ge 15 ]; then ok "disco livre ${free_gb} GB em $(pwd)"; else miss "disco livre ${free_gb} GB (minimo 15 GB)"; fi

if [ "$(id -u)" -eq 0 ]; then
	warn "executando como root; o build usa sudo, mas esta verificacao nao precisa de root"
elif command -v sudo >/dev/null 2>&1; then
	ok "sudo disponivel"
else
	miss "sudo"
fi

for tool in lb debootstrap mksquashfs xorriso sha256sum git; do
	if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else miss "$tool"; fi
done

for tool in shellcheck qemu-system-x86_64; do
	if command -v "$tool" >/dev/null 2>&1; then ok "$tool (opcional)"; else warn "$tool ausente (opcional: lint / teste em VM)"; fi
done

if [ -e /dev/kvm ]; then ok "KVM disponivel (teste em VM mais rapido)"; else warn "/dev/kvm ausente (QEMU sem aceleracao)"; fi
if [ -e /usr/share/OVMF/OVMF_CODE.fd ] || [ -e /usr/share/OVMF/OVMF_CODE_4M.fd ]; then ok "OVMF (teste UEFI)"; else warn "OVMF ausente (teste UEFI)"; fi

exit "$missing"
