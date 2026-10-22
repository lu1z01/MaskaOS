#!/bin/sh
# Verificacoes estaticas do repositorio (sem root; rede nao e usada). Retorna 1 se algo falhar.
#  1 sintaxe de scripts   2 shellcheck (se houver)   3 validacao de assinatura/certificado
#  4 comandos destrutivos e caminhos de disco/Ventoy 5 consistencia de auto/config e listas
#  6 pacotes existem/conflitos (se o indice foi baixado por scripts/fetch-package-index.sh)
# Linhas com o marcador "static-allow" sao excecoes revisadas.

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1
fail=0

scripts="scripts/*.sh tests/*.sh auto/config config/includes.chroot/usr/local/bin/maska-profile config/includes.chroot/usr/local/bin/maska-ferramenta config/hooks/live/*.chroot"
# Alvos de varredura de conteudo: tudo menos docs, referencias, saida de build e este teste.
scan() {
	grep -rnE "$1" --exclude-dir=.git --exclude-dir=_vendor --exclude-dir=build --exclude-dir=docs \
		--exclude=static-checks.sh --exclude='*.md' --exclude=LICENSE --exclude-dir=.github . | grep -v 'static-allow'
}

echo "== 1. Sintaxe (sh -n / ast)"
for f in $scripts; do
	if sh -n "$f"; then echo "OK   $f"; else echo "ERRO $f"; fail=1; fi
done
py=""
for cand in python3 python; do
	if command -v "$cand" >/dev/null 2>&1 && "$cand" -I -c 'import sys' >/dev/null 2>&1; then py=$cand; break; fi
done
if [ -n "$py" ]; then
	if "$py" -I -c 'import ast,sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' scripts/check-packages.py; then
		echo "OK   scripts/check-packages.py"
	else
		echo "ERRO scripts/check-packages.py"; fail=1
	fi
else
	echo "AVISO python ausente: sintaxe de check-packages.py nao verificada"
fi

echo "== 2. shellcheck"
sc=$(command -v shellcheck 2>/dev/null || true)
if [ -z "$sc" ] && [ -x _vendor/tools/shellcheck/shellcheck.exe ]; then
	sc=_vendor/tools/shellcheck/shellcheck.exe  # binario oficial v0.11.0 baixado com SHA-256 conferido
fi
if [ -n "$sc" ]; then
	# shellcheck disable=SC2086
	"$sc" $scripts || fail=1
else
	echo "AVISO shellcheck ausente; pulando"
fi

echo "== 3. Validacao de assinatura/certificado nao pode ser desligada"
if scan '(--no-check-certificate|--allow-unauthenticated|--allow-insecure-repositories|\[trusted=yes\]|AllowInsecureRepositories|AllowUnauthenticated|curl +(-k|--insecure)|check-gpg=false|--no-check-gpg)'; then
	echo "ERRO: validacao de seguranca desabilitada acima"; fail=1
else
	echo "OK   nenhum padrao proibido"
fi
if scan '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh'; then
	echo "ERRO: execucao de script baixado sem verificacao"; fail=1
else
	echo "OK   nenhum curl|sh"
fi

echo "== 4. Comandos destrutivos e caminhos de disco/Ventoy (fora de comentarios)"
bad=0
for f in $scripts; do
	case "$f" in tests/static-checks.sh) continue ;; esac
	hits=$(grep -nv '^[[:space:]]*#' "$f" | grep -v 'static-allow' | grep -E \
		'(^|[^[:alnum:]_.-])(mkfs(\.[a-z0-9]+)?|fdisk|sfdisk|cfdisk|sgdisk|gdisk|parted|wipefs|blkdiscard|shred|badblocks|cryptsetup|losetup|mount|umount|grub-install|update-grub|efibootmgr|ventoy[a-z0-9_.-]*)([[:space:]]|$)|(^|[:;&|[:space:]])dd[[:space:]]+(if|of)=|/dev/(sd|hd|vd|nvme|mmcblk|disk|sr|loop)|/(media|mnt|run/media)/|[Vv]entoy2[Dd]isk|/[Vv]entoy/' || true)
	if [ -n "$hits" ]; then echo "$f:"; echo "$hits"; bad=1; fi
	rm_hits=$(grep -nv '^[[:space:]]*#' "$f" | grep -v 'static-allow' | grep -E '(^|[:;&|[:space:]])rm[[:space:]]+-[a-zA-Z]*[rRf]' | grep -vE '\$\{?build\}?' || true)
	if [ -n "$rm_hits" ]; then echo "$f (rm fora de \$build):"; echo "$rm_hits"; bad=1; fi
done
if [ "$bad" -ne 0 ]; then echo "ERRO: comando destrutivo ou acesso a disco/Ventoy acima"; fail=1; else echo "OK   nenhum"; fi

echo "== 5. Consistencia de auto/config e listas"
need() { # padrao, descricao
	if grep -qE -- "$1" auto/config; then echo "OK   $2"; else echo "ERRO auto/config: $2 ausente"; fail=1; fi
}
need '--distribution trixie' 'distribuicao trixie'
need '--archive-areas "main non-free-firmware"' 'areas main + non-free-firmware'
need '--apt-recommends false' 'apt-recommends desligado'
need '--debian-installer none' 'sem debian-installer (o instalador e o Calamares, via lista 40)'
need 'locales=pt_BR.UTF-8' 'locale pt_BR'
need 'keyboard-layouts=br' 'teclado br'
if grep -qE -- '--archive-areas .*(contrib|[" ]non-free[" ])' auto/config; then echo "ERRO: contrib/non-free fora do escopo"; fail=1; fi
if scan '(kali\.download|http\.kali\.org|kali-rolling|kali-archive-keyring|apt\.metasploit\.com)' ; then
	echo "ERRO: repositorio de terceiros/Kali referenciado (proibido pela politica D-004)"; fail=1
else
	echo "OK   nenhum repositorio do Kali/terceiros"
fi
if ls config/archives/* >/dev/null 2>&1; then echo "ERRO: config/archives presente; repositorios extras exigem decisao em docs/architecture.md"; fail=1; fi

lists=$(ls config/package-lists/*.list.chroot 2>/dev/null)
heavy='^(xfce4|xfce4-goodies|task-[a-z0-9-]+|xorg|kali-[a-z0-9-]+|cinnamon-desktop-environment|libreoffice[a-z0-9-]*|ghidra|metasploit[a-z0-9-]*|zaproxy|burpsuite|wireshark|wireshark-qt|hashcat|hydra|gdb)$'
pk=$(for l in $lists; do sed -e 's/#.*//' "$l" | tr -s ' \t' '\n'; done | sed -e '/^$/d')
if echo "$pk" | grep -E "$heavy"; then echo "ERRO: pacote amplo/pesado em config/package-lists (mover para profiles/)"; fail=1; else echo "OK   sem metapacotes amplos nem ferramentas pesadas na ISO"; fi
# user-setup: sem ele o live-config nao cria o usuario Live; cinnamon-core: nucleo do desktop;
# grub-efi: o helper do Calamares o instala no alvo (verificado nas fontes, docs/reference-analysis.md secao 6).
for must in user-setup cinnamon-core grub-efi calamares calamares-settings-debian grub-efi-amd64 grub-efi-amd64-signed shim-signed os-prober ufw timeshift unattended-upgrades; do
	if echo "$pk" | grep -qx "$must"; then echo "OK   lista inclui $must"; else echo "ERRO: $must ausente das listas (sistema instalavel/completo)"; fail=1; fi
done
if echo "$pk" | grep -qxE 'grub-pc|grub-efi-ia32|power-profiles-daemon'; then echo "ERRO: grub-pc/grub-efi-ia32 conflitam com grub-efi-amd64; power-profiles-daemon conflita com tlp"; fail=1; fi
dups=$(echo "$pk" | sort | uniq -d)
if [ -n "$dups" ]; then echo "ERRO: pacotes duplicados nas listas: $dups"; fail=1; else echo "OK   sem duplicatas"; fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "$pk" | sort -u > "$tmp/iso"
for p in profiles/*.list; do
	sed -e 's/#.*//' "$p" | tr -s ' 	' '
' | sed -e '/^$/d' | sort -u > "$tmp/prof"
	both=$(comm -12 "$tmp/iso" "$tmp/prof")
	if [ -n "$both" ]; then echo "ERRO: $p repete pacote ja presente na ISO: $both"; fail=1; fi
done

echo "== 5b. Quebras de linha LF (CRLF quebra scripts no Linux)"
crlf=$(grep -rlIU "$(printf '\r')" --exclude-dir=.git --exclude-dir=_vendor --exclude-dir=build . || true)
if [ -n "$crlf" ]; then echo "$crlf"; echo "ERRO: arquivos com CRLF (ver .gitattributes)"; fail=1; else echo "OK   todos os arquivos em LF"; fi
if [ ! -f .gitattributes ] || ! grep -q 'eol=lf' .gitattributes; then echo "ERRO: .gitattributes sem eol=lf"; fail=1; fi

echo "== 6. Pacotes: existencia, componente, conflitos e tamanho (indice trixie)"
idx=build/pkg-index
if [ -r "$idx/Packages-main.xz" ] && [ -r "$idx/Packages-non-free-firmware.xz" ] && [ -n "$py" ]; then
	set --
	for l in $lists; do set -- "$@" --iso "$l"; done
	for p in profiles/*.list; do set -- "$@" --optional "$p"; done
	"$py" -I scripts/check-packages.py --index "$idx/Packages-main.xz" --area main \
		--index "$idx/Packages-non-free-firmware.xz" --area non-free-firmware "$@" || fail=1
else
	echo "AVISO indice ausente: execute scripts/fetch-package-index.sh (pulando validacao de pacotes)"
fi

exit "$fail"
