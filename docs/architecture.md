# Arquitetura e decisões — Maska OS

> Status: **decisão inicial (D-001 a D-006)**, baseada em inspeção de repositórios e metadados em 2026-10-22.
> Nada aqui foi validado por build. Evidências e fontes: [reference-analysis.md](reference-analysis.md).

## 1. Contexto verificado (2026-10-22)

| Fato | Fonte |
|---|---|
| Debian estável atual: 13 "trixie", ponto 13.7 (12/09/2026). Fim do suporte regular: 09/08/2028; LTS até 30/06/2030. Testing: forky (14), sem data. | debian.org/releases |
| `live-build` em trixie: `1:20250505+deb13u1`. Upstream já "prepara para forky". | sources.debian.org, `debian/changelog` |
| Cinnamon em trixie: **6.4.10**; upstream Mint: **6.7.9**. No tracker, o pacote tem pedido de ajuda (RFH) aberto desde 2025 e a versão de testing está marcada para autoremoção em 13/11/2026 por bugs RC em dependências. | tracker.debian.org/pkg/cinnamon |
| XFCE 4.20 em trixie (`xfce4 4.20.1`, `xfce4-session 4.20.2`). | sources.debian.org, tracker.debian.org |
| `mint-themes` **não existe** no Debian. `zaproxy`, `ghidra`, `burpsuite`, `metasploit-framework`, `radare2` (versão atual) **não existem** em trixie. | sources.debian.org API |
| Existem em trixie: nmap 7.95, wireshark 4.4.18, sqlmap 1.9.6, john 1.9.0, hashcat 6.2.6, binwalk 2.4.3, sleuthkit 4.12.1, autopsy 2.24, hydra 9.5, gobuster 3.6.0, ffuf 2.1.0, aircrack-ng, nikto 2.1.5, lynis 3.1.4, ufw, timeshift 24.06, flatpak 1.16, calamares 3.3.14. | sources.debian.org API |
| Kali usa `live-build` + **metapacotes** (`kali-linux-core`, `kali-desktop-xfce`, `kali-linux-default`) do próprio repositório `kali-rolling`; hooks mínimos. | `kali-live/kali-config` |

Host de desenvolvimento: Windows 11, Intel Core i5-1235U (12 threads), ~30 GB livres no disco interno, sem WSL/QEMU/VirtualBox, Docker Desktop parado; HD externo de 1 TB com Ventoy (a preservar). **RAM: o usuário informa 8 GB; uma inspeção anterior do Windows reportou 15,7 GB. O planejamento usa o valor menor (8 GB).** A construção da ISO exige Linux, em VM isolada (ver [build-in-vm.md](build-in-vm.md) e [build-plan.md](build-plan.md)).

## 2. Comparação das três alternativas

| Critério | A. Debian 13 + XFCE (ou Cinnamon) + ferramentas selecionadas | B. Kali como base + UX própria | C. Linux Mint como base + ferramentas |
|---|---|---|---|
| Estabilidade / atualizações | Alta; ciclo de ~2 anos, suporte de segurança previsível (até 2028, LTS 2030) | Baixa/média: `kali-rolling` é contínuo, sem janela de congelamento; kernel e libs mudam sempre | Alta (base Ubuntu LTS), mas ciclo e política definidos pelo Mint |
| Compatibilidade de pacotes/drivers | Boa; firmware não-livre em `non-free-firmware` oficial | Muito boa para hardware recente (kernel novo), mas ISO enorme | Boa (HWE do Ubuntu) |
| Facilidade de manutenção do projeto | Média: `live-build` é a ferramenta oficial; UX própria é trabalho nosso | Baixa: seguimos um rolling controlado por terceiro; qualquer metapacote Kali pode mudar | Alta no uso, **baixa como "distro"**: derivar do Mint significa re-spin, não distro própria |
| RAM/CPU/armazenamento (qualitativo; **nada medido**) | Menor pegada esperada (XFCE); só o que escolhermos | `kali-linux-default` instala um conjunto grande de ferramentas; existem variantes `light`/`minimal` no `kali-live` | Cinnamon tende a ser mais pesado que XFCE |
| Instalação/atualização | Calamares ou Debian-Installer; `apt` + `unattended-upgrades` | Instalador próprio do Kali (d-i); atualização via `apt full-upgrade` | Instalador do Mint (excelente para iniciantes); atualização via Update Manager |
| Ferramentas de pentest | Boa parte do núcleo (nmap, wireshark, sqlmap, john, hashcat, binwalk, sleuthkit, hydra…). Faltam ZAP, Ghidra, Burp, Metasploit, radare2 atual | **Máxima** (~centenas, empacotadas e testadas em conjunto) | Só via repos Ubuntu/PPAs/upstream; cobertura menor e menos auditável |
| Segurança da cadeia de suprimentos | Um único archive assinado (Debian) + `debian-security`; fácil de fixar com snapshot.debian.org | Um archive assinado (Kali), mas rolling; o `Dockerfile` do Kali confere o SHA-256 do `kali-archive-keyring` baixado, o que mostra que a confiança inicial no keyring é um ponto a tratar | Mint + Ubuntu + (para ferramentas) PPAs/downloads de terceiros: **mais origens, mais risco** |
| Dificuldade para construir/manter a ISO | Média: o fluxo é documentado (Debian Live Manual) e usado pelo Kali | Baixa para clonar; **alta para diferenciar** (rebranding/UX sobre rolling) | Alta/indefinida: o repositório de ISO do Mint não foi estudado (apenas o `live-installer`); seria um re-spin dependente de Mint + Ubuntu |
| Adequação a notebooks/PCs modestos | Excelente com XFCE | Boa só em variantes leves; padrão é pesado | Boa com Cinnamon moderno, pior em PCs muito antigos |
| Alinhamento com o objetivo (distro própria, portfólio) | **Alto**: decisões técnicas originais, arquitetura entendida de ponta a ponta | Médio: risco de parecer "Kali com outro papel de parede" | Baixo: é uma derivação; contradiz "ferramentas de segurança isoladas" (C pede VM com Kali) |

### Riscos principais por alternativa

- **A**: ZAP/Ghidra/Burp não têm pacote Debian → precisam de módulo sob demanda com verificação de integridade. Cinnamon em trixie tem manutenção frágil → ver D-002.
- **B**: Rolling + metapacotes de terceiros = a manutenção do nosso projeto fica refém do ritmo do Kali; difícil afirmar estabilidade.
- **C**: A premissa "manter o Kali isolado em VM" desloca o valor do projeto para fora da ISO; e não herdamos a infraestrutura de build.

## 3. Decisões

**D-001 — Arquitetura principal: alternativa A (Debian 13 "trixie", `live-build`).**
Motivos: única opção que combina estabilidade com controle total da ISO e cadeia de suprimentos curta (um archive assinado). O núcleo de ferramentas de segurança necessárias para um conjunto inicial enxuto já está em trixie.

**D-002 — Desktop inicial: XFCE 4.20.** Cinnamon fica como perfil experimental futuro.
Motivos: XFCE tem melhor pegada e manutenção estável em trixie. Cinnamon em trixie (6.4.10) está atrás do upstream (6.7.9), com RFH aberto e risco de autoremoção na linha testing. A experiência "tipo Mint" será obtida com painel inferior, menu em categorias, tema claro/escuro e configuração padrão do XFCE — sem depender de `mint-themes` (ausente no Debian, GPL-3+, empacotamento próprio necessário) nem de repositórios do Mint.
Revisitar quando: Cinnamon sair de RFH/autoremoção **e** o perfil passar nos testes de [build-plan.md](build-plan.md).

**D-003 — Instalador: Calamares com `calamares-settings-debian` (decisão revisada em D-013).** O `live-installer` do Mint (GPL-2+, Python/GTK) fica descartado: depende de pacotes e convenções do Mint, não está no Debian e teríamos que empacotá-lo e mantê-lo. Calamares existe no trixie (3.3.14).

**D-004 — Ferramentas de segurança: somente do archive Debian no conjunto inicial; o resto como módulos opt-in.**
Sem misturar repositórios do Kali (bloqueado por política do projeto). Ferramentas fora do Debian (ZAP, Ghidra) viram *módulos* instalados pelo usuário, com versão e SHA-256/assinatura fixados no repositório; candidatas a estudar: Flatpak/Flathub (ZAP) e releases oficiais assinadas. **Não implementado.**

**D-005 — Metapacotes próprios (`maska-*`) em fase posterior.** Seguindo o padrão Kali de agrupar via metapacotes, mas só depois que as listas por perfil estabilizarem; no início, listas de pacotes do `live-build` (`config/package-lists/`).

**D-006 — Licença provisória do projeto: GPL-3.0-or-later** para scripts/configuração originais, compatível com `live-build` (GPL-3+) e com componentes GPL-2+. **Não copiar código do `kali-live`** (licença GPL-2 sem confirmação de "ou posterior" arquivo a arquivo): usamos como estudo, e escrevemos nossa configuração. Ativos de marca com licença própria (a definir) em `branding/`. Revisão jurídica das licenças continua pendente.

## 3.1 Decisões da revisão de 2026-10-22 (D-007 a D-012)

Fonte dos números: índice `Packages` do Debian trixie 13.7 (`dists/trixie`, 12/09/2026), SHA-256 conferido contra o `Release`, processado por `scripts/check-packages.py`. Os tamanhos são **estimativas de espaço instalado** (soma de `Installed-Size` do fechamento de `Depends`), **não** RAM e **não** o tamanho da ISO.

**D-007 — XFCE por componentes, sem metapacotes amplos.** `xfce4`, `xfce4-goodies`, `task-xfce-desktop` e `xorg` ficam proibidos nas listas da ISO (verificado por `tests/static-checks.sh`): puxam plugins e *Recommends* que não são necessários e ocultam o que entra na imagem. A lista `10-desktop-xfce` nomeia ~43 pacotes (sessão, painel, gerenciador de janelas, `thunar`, terminal, bandeja de rede/áudio/Bluetooth, `lightdm`). Fechamento estimado: ~531 pacotes, ~884 MB instalado (inclui bibliotecas compartilhadas com as demais listas). Servidor gráfico: `xserver-xorg-core` + `libinput`; sem drivers DDX por fabricante (usa o *modesetting*: `modesetting_drv.so` está na lista de arquivos do `xserver-xorg-core` do trixie) — **a ser validado em VM e hardware real**.
- Armadilha encontrada na análise: `network-manager-gnome` → `network-manager-applet` depende de `policykit-1-gnome | polkit-1-auth-agent`; `polkit-1-auth-agent` é virtual e o `cinnamon` é um dos provedores. Sem um agente já selecionado, o resolvedor pode escolher Cinnamon. Por isso um agente é listado explicitamente: **`mate-polkit`**. O `lxpolkit`, escolhido antes, foi descartado na verificação cruzada: o autostart dele no trixie (`lxsession 0.5.6`) tem `NotShowIn=...;XFCE;...`, então não iniciaria no XFCE; o do `mate-polkit` tem `NotShowIn=GNOME;KDE;`. Critério de build: o manifesto da ISO **não pode** conter `cinnamon`.
- `apt-recommends false` reduz tamanho, mas pode omitir funções que o desktop esperaria; o único modo de saber é o teste de boot. Registrar o que faltar e adicionar o pacote com justificativa.

**D-008 — Listas em camadas + perfis opcionais.**

| Arquivo | Conteúdo | Local |
|---|---|---|
| `00-base.list.chroot` | rede, locale, sudo, firmware, microcódigo | ISO |
| `10-desktop-xfce.list.chroot` | XFCE por componentes, áudio, Bluetooth, tema | ISO |
| `20-productivity-dev.list.chroot` | Firefox ESR pt-BR, git, python3, compiladores, utilitários | ISO |
| `30-security-essential.list.chroot` | nmap, tcpdump, tshark, sqlmap, john, binwalk, sleuthkit e utilitários de rede | ISO |
| `40-installer.list.chroot` | Calamares, GRUB/shim UEFI assinados, `os-prober`, LUKS, ferramentas de partição | ISO |
| `50-system-laptop.list.chroot` | atualizações automáticas, `ufw`, `timeshift`, `tlp`, `thermald`, `fwupd` | ISO |
| `profiles/*.list` | `seguranca-gui`, `seguranca-pesada`, `escritorio`, `java-runtime`, `multimidia`, `impressao`, `utilitarios-disco` | ISO só como lista; pacotes instalados sob demanda com `maska-profile` |

Disponibilidade validada no trixie (binários presentes no índice): nmap 7.95, tcpdump 4.99.5, wireshark 4.4.18 (`tshark` na ISO; GUI no perfil `seguranca-gui`, +~104 MB sobre a ISO com instalador), sqlmap 1.9.6, john 1.9.0, binwalk 2.4.3, sleuthkit 4.12.1. Wireshark GUI saiu da ISO por peso (Qt); `tshark` cobre captura/análise em linha de comando. O `dumpcap` não fica setuid: captura exige `sudo`.
Perfis opcionais instalam via `apt` com as chaves do Debian; no Live a instalação ocupa RAM e se perde ao reiniciar; no sistema instalado é permanente.

**D-009 — Firmware completo de hardware comum, como compromisso consciente.** `firmware-linux-nonfree` arrasta `firmware-amd-graphics` (~90 MB); `firmware-iwlwifi`, `-atheros`, `-realtek` e `firmware-sof-signed` (áudio Intel recente) cobrem Wi-Fi e som de notebooks comuns. Aumenta a ISO, não a RAM em repouso (firmware só é carregado se o hardware existir). Revisar após medir o tamanho real da ISO.

**D-010 — Construção e entrega (revisada).** A ISO é construída em VM Debian 13 armazenada no HD externo e levada ao Windows; a cópia para o Ventoy é **manual**. Nenhum script do projeto formata, particiona, monta ou grava em discos, nem chama ferramentas do Ventoy. O build recusa rodar em `/media`, `/mnt`, `/run/media`. `tests/static-checks.sh` falha se um script contiver comandos de disco ou referência a dispositivos/Ventoy (exceção só com marcador `static-allow` revisado). O instalador (D-013) só altera discos quando o usuário o abre e confirma.

**D-011 — Meta de teste: ≤ 1,2 GB de RAM em repouso (não é resultado).** Métrica: `MemTotal − MemAvailable` após 3 minutos de repouso na sessão XFCE, VM com 4 GB, sem aplicativos abertos, medida por `maska-measure-idle` (também em `scripts/measure-idle.sh`). No Live o overlay em tmpfs conta como RAM usada. Nenhum número de RAM, boot ou tamanho de ISO consta como fato até existir relatório em `docs/test-reports/`.

**D-012 — Ferramentas fora do Debian: instalação manual documentada, nada automático.** ZAP, Ghidra e Metasploit não têm pacote compatível no trixie. Ver [ferramentas-sob-demanda.md](ferramentas-sob-demanda.md). A ISO não contém repositórios de terceiros nem scripts que baixem e executem código (verificado por teste estático).

**D-013 — Objetivo ampliado (2026-10-22): sistema completo instalável no notebook do próprio usuário.** Deixa de ser só Live. A ISO passa a incluir:
- **Instalador:** Calamares + `calamares-settings-debian` (lista `40-installer`). Marca/aparência do instalador é a padrão do Debian até a Fase 8.
- **Boot:** alvo instalado **somente UEFI** (`grub-efi-amd64`, `grub-efi-amd64-signed`, `shim-signed`, `efibootmgr`) com suporte a Secure Boot a **testar**; `grub-pc` (BIOS) conflita com `grub-efi-amd64` e fica fora. `os-prober` e `ntfs-3g` para dual boot; `cryptsetup` para disco criptografado (LUKS). A ISO Live continua inicializável em BIOS e UEFI.
- **Sistema de notebook (lista `50-system-laptop`):** `unattended-upgrades` (configurado em `includes.chroot`; desativado durante o Live por condição `!boot=live` nos serviços `apt-daily*`), `ufw` (habilitado por hook, entrada negada, saída liberada), `timeshift` (backup/restauração), `tlp` + `thermald` (energia e temperatura), `fwupd`, `smartmontools`, `intel-media-va-driver`, `xfce4-screensaver`.
- **Opcionais (instalam de forma permanente no sistema instalado):** `multimidia` (VLC), `impressao` (CUPS), `utilitarios-disco`, além dos já existentes.
- **Verificado nas fontes do `calamares-settings-debian` 13.0.13-1** (o que vai no trixie; detalhes em [reference-analysis.md §6](reference-analysis.md)): remove `live-boot`, `live-config*`, `live-tools` e o próprio `calamares-settings-debian` do sistema instalado (o pacote `calamares` e suas bibliotecas Qt permanecem); reativa o `os-prober` sozinho (`GRUB_DISABLE_OS_PROBER=false`) e roda `update-grub`; root sem senha (`setRootPassword: false`), usuário no grupo `sudo`; instala `grub-efi` no alvo via `apt-get` (por isso `grub-efi` está na lista: sem pool de pacotes na ISO, sem ele precisaria de rede).
- **Diferenças aceitas, documentadas:** o `sources.list` final escrito pelo Calamares habilita `trixie-backports` e linhas `deb-src` (o archive de backports tem prioridade baixa no apt: nada é atualizado a partir dele sem pedido explícito). A identidade visual do instalador é a do Debian (`branding: debian`): **antes de qualquer distribuição pública** isso precisa virar marca própria, para não apresentar o sistema como Debian oficial.
- **Ainda sem teste:** se o `ufw` habilita pelo hook; criação dos grupos padrão do Calamares (`lpadmin`, `scanner`, `netdev`, …) quando o pacote não existe; Secure Boot sob Ventoy; uso do caminho `/run/live/medium/live/filesystem.squashfs` quando a ISO é iniciada pelo Ventoy. Todos viram itens de teste em VM antes do notebook ([instalacao-no-notebook.md](instalacao-no-notebook.md)).
- O notebook-alvo tem Intel de 12ª geração; `intel-media-va-driver` e `thermald` são otimizações para ele, inofensivas em outras CPUs mas não necessárias.

## 4. Não-objetivos do incremento atual

Hardening além do descrito, reprodutibilidade bit-a-bit, identidade visual final (instalador com marca Debian), Cinnamon, módulos de pentest (ZAP, Ghidra, Metasploit; ver [ferramentas-sob-demanda.md](ferramentas-sob-demanda.md)), instalação em BIOS legado, persistência no Live. Cada um só entra após o critério da fase anterior ser atendido.

## 5. Pontos em aberto

1. Nome "Maska OS": nenhuma checagem de marca/colisão foi feita. É provisório.
2. Espaço para o Linux no notebook e escolha dual boot vs. substituir o Windows (decisão do usuário; ver [instalacao-no-notebook.md](instalacao-no-notebook.md)).
2b. Hipervisor da VM de build (VirtualBox vs. Hyper-V) e sistema de arquivos da partição do Ventoy (exFAT/NTFS) — ver [build-in-vm.md](build-in-vm.md).
3. Política de kernel: `linux-image-amd64` do trixie (atualizado com segurança) vs. *hold* como o Kali faz no ambiente live.
4. Secure Boot sob Ventoy e com o shim do Debian: não testado.
5. Firewall: nenhum serviço escuta na rede nas listas atuais; a necessidade de `ufw` será decidida após o teste de portas na ISO.
6. Credenciais do usuário Live (`maska`): comportamento do `live-config` (senha padrão) a confirmar no primeiro boot; sistema destinado somente ao uso Live.
