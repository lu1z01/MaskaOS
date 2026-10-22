# Changelog

Formato baseado em Keep a Changelog. Versionamento a definir.

## [Não lançado]

### Corrigido (2026-10-22, verificação cruzada com as fontes; ver docs/reference-analysis.md §6)
- `user-setup` adicionado: sem ele o `live-config` não cria o usuário Live (era só Recommends).
- `lxpolkit` trocado por `mate-polkit`: o autostart do `lxpolkit` exclui o XFCE.
- `grub-efi` adicionado: o instalador o instala no alvo e exigiria rede.
- Perfil `java-runtime`: `openjdk-25-jdk` (Ghidra 12.2 exige JDK 25).
- 12 arquivos com CRLF convertidos para LF; `.gitattributes` e checagem de CRLF nos testes.
- Documentação: `os-prober` é reativado pelo instalador; `sources.list` final inclui backports/deb-src; marca Debian no instalador.
- REA executado (`inspect-artifact`) no ELF do `nmap`; `.deb`/`tar.xz` não são suportados por ele.

### Alterado (2026-10-22, objetivo ampliado: sistema completo no notebook, D-013)
- Listas `40-installer` (Calamares, GRUB/shim UEFI, os-prober, LUKS) e `50-system-laptop` (unattended-upgrades, ufw, timeshift, tlp, thermald, fwupd); hook do `ufw`; sem atualização automática durante o Live.
- Perfis `multimidia`, `impressao`, `utilitarios-disco`; `docs/instalacao-no-notebook.md`.

### Alterado (2026-10-22, revisão para Live/Ventoy em VM)
- Pacotes reorganizados em `config/package-lists/00…30` + `profiles/` opcionais; XFCE por componentes (D-007…D-012).
- `auto/config`: pt_BR/teclado br/fuso, `--apt-recommends false`, sem instalador, checksums sha256.
- `scripts/build.sh`: sem argumentos, recusa mídia/pastas compartilhadas, saída em `build/out/`.
- `tests/static-checks.sh`: comandos destrutivos, disco/Ventoy, consistência e validação de pacotes.

### Adicionado
- `scripts/check-packages.py`, `scripts/fetch-package-index.sh`, `scripts/verify-iso.sh`, `scripts/measure-idle.sh`, helper `maska-profile`.
- `docs/build-in-vm.md` e `docs/ferramentas-sob-demanda.md`.
- Análise das referências (Kali `live-build-config`, Mint, Debian `live-build`, REA) em `docs/reference-analysis.md`.
- Decisões de arquitetura D-001…D-006 em `docs/architecture.md`.
- Plano de build e critérios de aceitação em `docs/build-plan.md`.
- `auto/config` e lista de pacotes base (não executados), `scripts/check-env.sh`, `scripts/build.sh`, `tests/static-checks.sh`, workflow de lint.
