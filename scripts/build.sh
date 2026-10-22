#!/bin/sh
# Constroi a ISO Live dentro de ./build. Roda somente em Linux (Debian 13 virtualizado).
# Nao formata, particiona nem grava em discos; nao instala nada no host; nao toca no
# bootloader. A copia da ISO para o Ventoy e MANUAL (docs/build-in-vm.md).
# Uso: ./scripts/build.sh          (pede sudo apenas para `lb build`)
# NAO EXECUTADO ainda: ver docs/build-plan.md.

set -eu

if [ "$#" -ne 0 ]; then
	echo "ERRO: este script nao aceita argumentos (edite auto/config e revise no PR)." >&2
	exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
	echo "ERRO: o build exige Linux (ver docs/build-in-vm.md)." >&2
	exit 1
fi

root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/build"

# Recusa dirs montados/removiveis/compartilhados: o build precisa de permissoes e
# symlinks completos e nunca deve escrever em midia externa.
case "$root" in
	/media/*|/mnt/*|/run/media/*) # static-allow: guarda contra midia externa
		echo "ERRO: repositorio em $root (midia/pasta compartilhada). Copie-o para o disco da VM." >&2
		exit 1 ;;
esac
if [ ! -f "$root/auto/config" ] || [ ! -f "$root/.gitignore" ]; then
	echo "ERRO: $root nao parece a raiz do repositorio." >&2
	exit 1
fi

# Chamados via `sh` para nao depender do bit de execucao (perdido em copias feitas no Windows).
sh "$root/scripts/check-env.sh"
sh "$root/scripts/fetch-package-index.sh"
sh "$root/tests/static-checks.sh"

# Partes versionadas sao copiadas para build/; `lb` gera o resto la dentro.
mkdir -p "$build"
rm -rf "$build/auto" "$build/config"
cp -R "$root/auto" "$root/config" "$build/"
chmod 755 "$build/auto/config" "$build/config/includes.chroot/usr/local/bin/maska-profile" "$build/config/includes.chroot/usr/local/bin/maska-ferramenta"

# Perfis opcionais viajam na ISO para `maska-profile` (uma unica fonte: profiles/).
profiles_dst="$build/config/includes.chroot/usr/share/maska/profiles"
mkdir -p "$profiles_dst"
cp "$root"/profiles/*.list "$profiles_dst/"

# Script de medicao de RAM disponivel dentro da ISO (docs/build-plan.md, secao de medicao).
cp "$root/scripts/measure-idle.sh" "$build/config/includes.chroot/usr/local/bin/maska-measure-idle"
chmod 755 "$build/config/includes.chroot/usr/local/bin/maska-measure-idle"

# Data fixa de origem melhora a reprodutibilidade dos metadados (nao garante bit-a-bit).
if SOURCE_DATE_EPOCH=$(git -C "$root" log -1 --format=%ct 2>/dev/null); then
	export SOURCE_DATE_EPOCH
fi

cd "$build"

# O live-build PULA etapas que ja tem marcador em .build/ (Check_stagefile): sem limpar, uma
# mudanca nas listas geraria uma ISO com os pacotes antigos, sem erro. `lb clean` (= --all)
# remove .build, chroot, binary e ISOs antigas; preserva cache/ e a configuracao.
if [ -d "$build/.build" ] || [ -d "$build/chroot" ]; then
	sudo lb clean
fi
rm -f "$build"/*.iso "$build/out/"*.iso "$build/out/SHA256SUMS" "$build/lb-build.status"

lb config

# Sem pipefail em sh: o codigo de saida do `lb build` e gravado em arquivo para nao ser
# mascarado pelo `tee`.
{ sudo lb build; echo "$?" > "$build/lb-build.status"; } 2>&1 | tee "$build/build.log"
status=$(cat "$build/lb-build.status" 2>/dev/null || echo desconhecido)
if [ "$status" != "0" ]; then
	echo "ERRO: lb build terminou com codigo $status; veja $build/build.log" >&2
	exit 1
fi

iso=""
for f in "$build"/*.iso; do
	if [ -f "$f" ]; then iso=$f; break; fi
done
if [ -z "$iso" ]; then
	echo "ERRO: lb build terminou sem gerar ISO; veja $build/build.log" >&2
	exit 1
fi

# Pasta de saida com apenas o necessario para servir/copiar manualmente.
mkdir -p "$build/out"
cp "$iso" "$build/out/"
( cd "$build/out" && sha256sum "$(basename "$iso")" > SHA256SUMS && sha256sum -c SHA256SUMS )
echo "ISO: $build/out/$(basename "$iso")"
echo "Proximo passo: scripts/verify-iso.sh e copia MANUAL para o Ventoy (docs/build-in-vm.md)."
