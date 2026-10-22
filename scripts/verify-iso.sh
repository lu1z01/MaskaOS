#!/bin/sh
# Verificacoes somente leitura de uma ISO gerada. Nao monta nem grava nada na ISO.
# Uso: scripts/verify-iso.sh build/out/<arquivo>.iso
# NAO EXECUTADO ainda (requer xorriso e uma ISO real).

set -eu

iso=${1:-}
if [ -z "$iso" ] || [ ! -r "$iso" ]; then
	echo "Uso: $0 caminho/da/imagem.iso" >&2
	exit 1
fi
fail=0

echo "== Tamanho e SHA-256"
echo "$(wc -c < "$iso") bytes"
sha256sum "$iso"
sum_file="$(dirname "$iso")/SHA256SUMS"
if [ -r "$sum_file" ]; then
	( cd "$(dirname "$iso")" && sha256sum -c SHA256SUMS ) || fail=1
else
	echo "AVISO  SHA256SUMS ausente ao lado da ISO"
fi

echo "== Entradas de boot (BIOS e UEFI)"
report=$(xorriso -indev "$iso" -report_el_torito plain 2>/dev/null || true)
echo "$report"
for kind in BIOS UEFI; do
	if echo "$report" | grep -qi "$kind"; then
		echo "OK     entrada $kind"
	else
		echo "ERRO   sem entrada $kind"; fail=1
	fi
done

echo "== Arquivos essenciais do Live"
listing=$(xorriso -indev "$iso" -find /live -name '*' -exec lsdl 2>/dev/null || true)
for f in filesystem.squashfs vmlinuz initrd; do
	if echo "$listing" | grep -q "$f"; then
		echo "OK     $f"
	else
		echo "ERRO   $f ausente em /live"; fail=1
	fi
done

exit "$fail"
