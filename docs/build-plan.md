# Plano de construção e critérios de aceitação

Estado: **plano + verificações estáticas**. Nenhuma ISO foi construída. O que foi e o que não foi executado está em §6.
Procedimento passo a passo do build em VM e da cópia para o Ventoy: [build-in-vm.md](build-in-vm.md).

## 1. Restrições e pré-requisitos

| Item | Valor |
|---|---|
| Host | Windows 11, i5-1235U, **8 GB de RAM (informado)**, ~30 GB livres no disco interno |
| Armazenamento de trabalho | HD externo de 1 TB com Ventoy (a **preservar**; sem reparticionar, formatar ou usar as ferramentas do Ventoy) |
| Ambiente de build | VM Debian 13 em VirtualBox (ver §1.1), disco virtual no HD externo |
| Artefato | ISO Live híbrida (BIOS + UEFI) com instalador, copiada **manualmente** para o Ventoy; sistema instalado só em UEFI ([instalacao-no-notebook.md](instalacao-no-notebook.md)) |

Dentro da VM (Debian 13): `live-build debootstrap squashfs-tools xorriso isolinux syslinux-common syslinux-utils grub-pc-bin grub-efi-amd64-bin mtools dosfstools git curl xz-utils gpgv debian-archive-keyring python3 shellcheck ca-certificates`.

Estimativas (**não medidas**): VM de build com 4 GB de RAM, 4 vCPUs e disco dinâmico de ~60 GB; VM de teste da ISO com 4 GB. O HD externo (provavelmente rotacional) tornará `debootstrap` e `mksquashfs` lentos; o tempo será medido e registrado, não estimado aqui.

### 1.1 Hipervisor
VirtualBox e Hyper-V não estão instalados/ativos de forma verificada (o Windows reporta hipervisor presente). Se o Hyper-V estiver ativo, o VirtualBox pode funcionar sobre ele, possivelmente com desempenho menor (não medido); o disco da VM não deve ficar em partição FAT32 (limite de 4 GB por arquivo). Verifique o sistema de arquivos da partição de dados do Ventoy (exFAT ou NTFS) antes de criar o disco virtual.

## 2. Verificações seguras (somente leitura)

```sh
sh scripts/check-env.sh              # SO, RAM, disco e ferramentas do host de build (na VM)
sh scripts/fetch-package-index.sh    # baixa e confere o índice Packages do trixie em build/pkg-index/
sh tests/static-checks.sh            # sintaxe, segurança, comandos destrutivos, listas, pacotes
```

## 3. Fases e critérios de conclusão

| Fase | Entrega | Critério verificável |
|---|---|---|
| 1 | Ambiente validado | `check-env.sh` sem `FALTA` na VM Debian 13 |
| 2 | `docs/architecture.md` | Decisões D-001…D-013 revisadas pelo usuário |
| 3 | Estrutura + README | `tests/static-checks.sh` passa; CI verde |
| 4 | **ISO Live mínima inicializável** | §4 |
| 5 | XFCE + usabilidade | §4 completo + sessão gráfica, rede, áudio e mídia removível verificados em VM |
| 6 | Produtividade/dev | Listas instalam sem conflito; tamanho da ISO registrado |
| 7 | Perfis de segurança | Cada ferramenta: origem (Debian ou módulo verificado), versão, `--version` executa |
| 8 | Identidade visual | Ativos com licença registrada; sem marcas de terceiros |
| 9 | Testes automatizados | Boot em VM (BIOS e UEFI) automatizado; portas/serviços verificados |
| 9b | Instalação em VM + sistema de notebook | Critérios 12–13 |
| 10 | Documentação de release | `SHA256SUMS` + assinatura, instruções de verificação, política de suporte |

Regra: não iniciar a fase N+1 com a fase N quebrada. As fases 4–6 são combinadas no primeiro build porque o desktop é parte do objetivo; se o build combinado falhar, volte a uma ISO só com `00-base` para isolar a causa.

## 4. Critérios de aceitação do primeiro build

Executar na VM de build: `./scripts/build.sh` (**não executado ainda**). Aceito somente se **todos** forem verdadeiros e registrados em `docs/test-reports/` (criar com o primeiro resultado real):

1. `lb build` termina com código 0; `build/build.log` guardado.
2. Existe `build/out/*.iso` e `SHA256SUMS`; `sha256sum -c` confere; o hash também confere **no Windows** (`Get-FileHash`) após a cópia da VM.
3. `scripts/verify-iso.sh` reporta entrada de boot BIOS e UEFI e `/live/{filesystem.squashfs,vmlinuz,initrd}`.
4. Manifesto da imagem (`filesystem.packages`/`.manifest`) **não contém**: `cinnamon`, `xfce4-goodies`, `task-*`, `kali-*`, `wireshark`, `libreoffice-core`, `hashcat`.
5. A ISO inicializa em VM **BIOS** e **UEFI** até a sessão XFCE em português do Brasil e teclado `br`.
6. Dentro da sessão: rede NetworkManager conecta; áudio reproduz (VM); `lsblk`/Thunar mostram mídia removível; `maska-profile list` funciona.
7. `systemctl --failed` vazio; `ss -tuln` sem escuta em interfaces externas (esperado: nenhuma). Resultado salvo.
8. Os repositórios configurados no sistema são apenas Debian (`deb.debian.org` e `security.debian.org`), com chaves do `debian-archive-keyring`; `apt update` funciona sem `trusted=yes`.
9. **Medição de RAM (§5) registrada**, passe ou falhe em relação à meta de teste.
10. Tamanho da ISO e tempo de build **medidos e registrados**.
11. A ISO inicializa pelo **Ventoy** (cópia manual) em ao menos uma máquina; modo de boot do Ventoy usado e se foi preciso ajustar, registrado. Nenhuma partição do HD externo foi alterada além da cópia do arquivo.

12. **Instalação em VM UEFI** (disco virtual vazio): conclui, reinicia no sistema instalado, sem usuário Live; `ufw` ativo, `tlp-stat -s` ativo, timers `apt-daily*` presentes, `apt full-upgrade` só com repositórios Debian; repetir com LUKS. Resultado em `docs/test-reports/`. **Pré-condição obrigatória antes de qualquer instalação no notebook.**
13. Manifesto da imagem contém `calamares`, `grub-efi-amd64-signed`, `shim-signed`, `os-prober`; não contém `grub-pc`.

Fora do escopo: Secure Boot validado, hardening, persistência no Live, instalação em BIOS legado, reprodutibilidade bit-a-bit.

A instalação no notebook real **não é executada nem automatizada por este projeto**: segue [instalacao-no-notebook.md](instalacao-no-notebook.md), conduzida pelo usuário depois dos itens 1–13.

## 5. Meta de RAM em repouso e como medir

**Meta de teste: ≤ 1200 MB de RAM em uso em repouso.** É um objetivo a verificar, não um resultado. Se for excedida, o relatório diz quais processos e o plano é reduzir, não relaxar a meta em silêncio.

Procedimento:
1. Criar uma VM de teste com **4096 MB** de RAM (para a pressão de memória não distorcer a medida), 2+ vCPUs, ISO anexada, sem disco ou com disco vazio dedicado.
2. Iniciar a ISO; a sessão XFCE entra automaticamente; **não abrir aplicativos**.
3. Aguardar **3 minutos**.
4. Abrir o terminal e executar: `maska-measure-idle` (ou `sh scripts/measure-idle.sh`). Opcional: `maska-measure-idle 1200`.
5. Copiar a saída completa para `docs/test-reports/AAAA-MM-DD-ram.md`, com: versão/commit, hipervisor, RAM/vCPU da VM, BIOS ou UEFI.

Métrica: `usado = MemTotal − MemAvailable` (o *page cache* não conta). O script mostra também `free -m`, os 15 maiores consumidores por RSS, uso do overlay (no Live, arquivos gravados em tmpfs ocupam RAM), serviços habilitados, portas e tempo de boot. Medir na VM é indicativo; repetir em hardware real (via Ventoy) antes de afirmar qualquer coisa. Não inclua números de outras fontes.

## 6. Status das verificações (2026-10-22)

| Verificação | Resultado |
|---|---|
| Sintaxe `sh -n` de todos os scripts e AST de `check-packages.py` | **Executado, passou** (Git Bash/Windows) |
| Padrões proibidos (validação de assinatura/certificado, `curl\|sh`) | Executado, passou; caso negativo executado, falhou como esperado |
| Comandos destrutivos / caminhos de disco / Ventoy / `rm` fora de `$build` | Executado, passou; caso negativo executado (detectou `mkfs`, `dd`, `/dev/sd*`, `/media`, `rm`) |
| Consistência de `auto/config` e listas; sem metapacotes amplos; sem repos do Kali | Executado, passou |
| Existência dos pacotes, componentes e conflitos contra o índice trixie 13.7 | **Executado, passou** (SHA-256 do índice conferido contra o `Release` via HTTPS; **assinatura GPG não verificada** neste host) |
| `shellcheck` | **Não executado** (ausente neste host) |
| `scripts/check-env.sh` no Debian | **Não executado** (só o ramo "host não-Linux" foi testado) |
| `lb config` / `lb build`, ISO, boot BIOS/UEFI, RAM, Ventoy | **Não executado — exigem Debian 13 real e VM** |
| `scripts/verify-iso.sh`, `maska-profile`, `fetch-package-index.sh` (ramo com `gpgv`) | **Não executado** |

## 7. Riscos

- `auto/config` e as listas ainda não passaram por `lb config`/`lb build`; opções podem exigir ajuste na versão `1:20250505` do trixie.
- `--apt-recommends false` pode faltar algo que o XFCE espera (ex.: ícones, agente de autenticação, segredos); só o boot mostra.
- Estimativas de tamanho vêm de `Installed-Size` e aproximam o `apt`; o manifesto real do build prevalece.
- Espelho `deb.debian.org` é móvel dentro do trixie; reprodutibilidade real exigirá `snapshot.debian.org` com timestamp fixo (Fase 9/10).
- Disco rotacional externo: lento e sensível a desconexão. Não remover o HD durante o build.
- Arquivos editados no Windows podem ganhar CRLF e quebrar os scripts no Debian; `tests/static-checks.sh` reprova CRLF e `.gitattributes` força LF. Copie o repositório para a VM via `git clone`, não via cópia de pasta com conversão de texto.
