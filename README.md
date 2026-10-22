# Maska OS

> Nome provisório; sem checagem de marca. Distribuição Linux **independente** para produtividade e estudo/prática de cibersegurança.

**Status: pré-alpha / planejamento.** Não existe ISO. Nenhuma ISO foi construída, testada ou publicada, e o instalador nunca foi executado. Este repositório contém a arquitetura decidida, a configuração planejada e as verificações estáticas.

> **Aviso:** projeto independente. **Não é oficial** do Debian, do Kali Linux nem do Linux Mint e não tem afiliação com eles. Destina-se a auditorias autorizadas, laboratórios próprios e pesquisa. Você é responsável por usar as ferramentas apenas onde tem autorização.

## Objetivo

Um sistema completo e instalável, baseado em Debian estável, leve e fácil para iniciantes, com um conjunto enxuto de ferramentas de segurança organizado por tarefa — sem misturar repositórios de outras distribuições. O alvo atual é o notebook do próprio autor (instalação em UEFI), depois de ensaio em VM. Ver [docs/instalacao-no-notebook.md](docs/instalacao-no-notebook.md): a instalação em disco é feita por você, nunca pelos scripts do projeto.

## Arquitetura (resumo)

Decidida em [docs/architecture.md](docs/architecture.md), com base na análise de [docs/reference-analysis.md](docs/reference-analysis.md):

- **Base:** Debian 13 "trixie" (estável) construído com `live-build`.
- **Desktop inicial:** XFCE (Cinnamon fica como perfil experimental futuro; motivos no documento).
- **Ferramentas de segurança:** somente do archive Debian no início; ferramentas ausentes (ZAP, Ghidra…) viram módulos opt-in verificados, **ainda não implementados**.
- **Instalador:** Calamares (D-013); alvo instalado somente UEFI, com dual boot (Windows) ou disco criptografado a critério do usuário. Não testado.

## O que existe hoje

| Item | Estado |
|---|---|
| Decisões de arquitetura (D-001…D-013) e plano de build | Escrito, aguardando revisão |
| `auto/config` e listas de pacotes em camadas | Escrito; **`lb config`/`lb build` nunca executados** |
| Existência de pacotes no Debian 13, componentes e conflitos | **Verificado** contra o índice do trixie 13.7 (`scripts/check-packages.py`); assinatura GPG do índice não verificada neste host |
| Testes estáticos (`tests/static-checks.sh`): sintaxe, comandos destrutivos, caminhos de disco/Ventoy, padrões inseguros, consistência | Executados no Windows (Git Bash); passam; casos negativos também testados. `shellcheck` **não** executado |
| `scripts/build.sh`, `check-env.sh` (ramo Linux), `verify-iso.sh`, `measure-idle.sh`, `maska-profile` | **Não executados** (exigem Debian 13) |
| ISO, boot em VM/Ventoy, consumo de RAM, tamanho da ISO | **Não existem / não medidos** |

## Composição planejada da ISO (listas em `config/package-lists/`)

| Lista | Conteúdo |
|---|---|
| `00-base` | NetworkManager, locale pt_BR, sudo, firmware e microcódigo |
| `10-desktop-xfce` | XFCE por componentes (sem `xfce4`/`xfce4-goodies`/`xorg`), `lightdm`, PipeWire, Bluetooth, tema Greybird |
| `20-productivity-dev` | Firefox ESR (pt-BR), git, python3, compiladores, utilitários |
| `30-security-essential` | nmap, tcpdump, tshark, sqlmap, john, binwalk, sleuthkit e utilitários de rede (todos do Debian) |
| `40-installer` | Calamares, GRUB/shim UEFI assinados, `os-prober`, LUKS, ferramentas de partição |
| `50-system-laptop` | atualizações automáticas de segurança, `ufw`, `timeshift`, `tlp`, `thermald`, `fwupd` |

Perfis opcionais (`profiles/`, instalados sob demanda com `sudo maska-profile install <perfil>`): `seguranca-gui` (Wireshark), `seguranca-pesada` (hashcat, hydra, gdb, strace, ltrace), `escritorio` (LibreOffice), `java-runtime`, `multimidia` (VLC), `impressao` (CUPS), `utilitarios-disco`. ZAP, Ghidra e Metasploit não existem no Debian 13 e **não** são instalados automaticamente: [docs/ferramentas-sob-demanda.md](docs/ferramentas-sob-demanda.md).

Meta de teste (não resultado): ≤ 1,2 GB de RAM em repouso. Método de medição: [docs/build-plan.md §5](docs/build-plan.md#5-meta-de-ram-em-repouso-e-como-medir).

## Requisitos

Estimativas, **não medidas**:

- Computador de desenvolvimento: 8 GB de RAM, ~30 GB livres no disco interno (insuficiente para o build; por isso a VM fica no HD externo).
- Build: VM Debian 13 com 4 GB de RAM, 4 vCPUs e ~60 GB de disco virtual.
- Teste da ISO: VM ou máquina real com 4 GB de RAM para a medição; arquivos de boot via Ventoy.

## Como construir, validar e usar com o Ventoy

Guia completo: **[docs/build-in-vm.md](docs/build-in-vm.md)**. Resumo (na VM Debian 13):

```sh
./scripts/check-env.sh              # somente leitura
./scripts/fetch-package-index.sh    # baixa/confere o índice Packages do trixie
./tests/static-checks.sh            # testes estáticos e validação de pacotes
./scripts/build.sh                  # NAO EXECUTADO ainda: gera build/out/<arquivo>.iso e SHA256SUMS
./scripts/verify-iso.sh build/out/*.iso
```

A cópia da ISO para a partição de dados do Ventoy é **manual** (Explorer). Nenhum script do projeto formata, particiona, monta ou grava em discos, e nenhum chama ferramentas do Ventoy.

### Verificar o artefato

```sh
sha256sum -c SHA256SUMS                  # Linux
Get-FileHash -Algorithm SHA256 .\<arquivo>.iso   # Windows (PowerShell); compare com SHA256SUMS
```

Assinatura dos releases: planejada, **não implementada**.

## Adicionar ou remover pacotes

- Na ISO: edite `config/package-lists/*.list.chroot` (um pacote por linha, com motivo em comentário). Não use metapacotes amplos nem ferramentas pesadas ali.
- Opcionais: edite `profiles/*.list`.
- Sempre rode `./tests/static-checks.sh` (valida existência, conflitos e proíbe repositórios externos e comandos destrutivos).

## Personalização da interface e identidade visual

Planejado para as Fases 5 e 8. Ainda não há `branding/`.

## Problemas conhecidos e limitações

- Nenhuma ISO; nada foi testado em VM nem em hardware.
- Opções do `lb config` ainda não validadas contra o `live-build` do trixie.
- `--apt-recommends false` pode omitir funções esperadas pelo desktop; só o boot em VM mostrará.
- Instalador (Calamares), `ufw` via hook, remoção do usuário Live no sistema instalado e `os-prober` para dual boot: **tudo sem teste**; Secure Boot e Ventoy não testados.
- Destino de instalação somente UEFI (BIOS legado não suportado).
- O instalador ainda usa a marca do Debian (`calamares-settings-debian`); o sistema instalado recebe `trixie-backports` e `deb-src` no `sources.list` (comportamento do instalador do Debian). Detalhes e o que foi conferido nas fontes: [docs/reference-analysis.md §6](docs/reference-analysis.md).
- Wireshark GUI, hashcat, LibreOffice e outros itens pesados não estão na ISO (perfis opcionais).
- Reprodutibilidade bit-a-bit **não** é alegada; apenas planejamos fixar espelho (snapshot) e datas.
- Secure Boot, persistência e firewall: não avaliados.
- O projeto não declara ser "hardened" ou seguro; qualquer alegação futura exigirá testes registrados.

## Atualização e suporte

Sem política de release ainda. Meta: seguir `debian-security` do trixie (suporte regular Debian até 09/08/2028, LTS até 30/06/2030, conforme debian.org/releases em 2026-10-22).

## Licenças e créditos

- Código e configuração originais: **GPL-3.0-or-later** (provisório, ver D-006) — [LICENSE](LICENSE).
- Estudo de: Debian `live-build` (GPL-3+), Kali `live-build-config` (GPL-2; não copiado), Linux Mint `live-installer` (GPL-2+), `mint-themes` (GPL-3+), Cinnamon/Nemo (GPL-2), XFCE. Nenhum código desses projetos foi incorporado até agora. Revisão de licenças pendente antes de qualquer redistribuição.
- Marcas pertencem aos respectivos donos.

## Contribuir e reportar vulnerabilidades

[CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · [CHANGELOG.md](CHANGELOG.md)
