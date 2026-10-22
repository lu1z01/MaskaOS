#!/bin/sh
# Baixa os indices Packages do Debian trixie para build/pkg-index/ e verifica a integridade.
# Somente leitura fora de build/pkg-index. Usado por tests/static-checks.sh (check-packages.py).
# Verificacao: se `gpgv` e o chaveiro debian-archive-keyring existirem, valida a ASSINATURA do
# InRelease; senao, avisa e valida apenas o SHA-256 contra o Release obtido por HTTPS.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/build"
cache="$build/pkg-index"
base=https://deb.debian.org/debian/dists/trixie
mkdir -p "$cache"
cd "$cache"

curl -fsSL --max-time 120 -o InRelease "$base/InRelease"

keyring=""
for k in /usr/share/keyrings/debian-archive-keyring.pgp /usr/share/keyrings/debian-archive-keyring.gpg; do
	[ -r "$k" ] && keyring=$k && break
done
if command -v gpgv >/dev/null 2>&1 && [ -n "$keyring" ]; then
	gpgv --keyring "$keyring" --output Release InRelease
	echo "OK     assinatura do InRelease verificada com $keyring"
else
	echo "AVISO  gpgv ou debian-archive-keyring ausente: sem verificacao de assinatura (apenas SHA-256 via HTTPS)" >&2
	# Extrai o corpo do clearsigned (sem cabecalho/assinatura PGP).
	awk '/^-----BEGIN PGP SIGNED MESSAGE-----/ {h=1; next} h && /^$/ {h=0; b=1; next} /^-----BEGIN PGP SIGNATURE-----/ {b=0} b' InRelease > Release
fi

for comp in main non-free-firmware; do
	rel="$comp/binary-amd64/Packages.xz"
	out="Packages-$comp.xz"
	curl -fsSL --max-time 600 -o "$out" "$base/$rel"
	want=$(awk -v f="$rel" '/^SHA256:/ {s=1; next} /^[A-Za-z]/ {s=0} s && $3==f {print $1; exit}' Release)
	got=$(sha256sum "$out" | awk '{print $1}')
	if [ -z "$want" ] || [ "$want" != "$got" ]; then
		echo "ERRO: SHA-256 de $rel nao confere com o Release" >&2
		rm -f "$build/pkg-index/$out"
		exit 1
	fi
	echo "OK     $rel sha256=$got"
done
