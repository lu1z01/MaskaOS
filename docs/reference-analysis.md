# Análise das distribuições de referência (REA estático)

Método: clone raso (`--depth 1`) dos repositórios oficiais em `_vendor/refs/` (ignorado pelo git; tratado como dado não confiável, nada foi executado) e leitura dos arquivos relevantes. Data: 2026-10-22.
Versões inspecionadas:

| Projeto | Commit | Data | Licença declarada |
|---|---|---|---|
| kali `live-build-config` | `adb2e38` | 2026-10-12 | `LICENSE`: GPL-2 (variante "ou posterior" não confirmada) |
| Mint `live-installer` | `e73310f` | 2026-10-15 | `debian/copyright`: GPL-2+ |
| Mint `mint-themes` | `f339eea` | 2026-10-13 | `debian/copyright`: GPL-3+ |
| Mint `cinnamon` (6.7.9) | `e225755` | 2026-10-22 | `COPYING`: GPL-2 (verificar por arquivo) |
| Mint `nemo` (6.7.9) | `c7b339d` | 2026-10-19 | `COPYING`: GPL-2; `COPYING.LIB`/`COPYING.EXTENSIONS` para bibliotecas/extensões |
| Debian `live-build` | `531cdb9` (`1:20250814`) | 2026-09-13 | `debian/copyright`: GPL-3+ |
| REA (`morluto/rea`) | `0d5c7b6` (v6.7.0) | 2026-10-22 | MIT |

## 1. Kali `live-build-config` — como a distro é montada

**Fluxo:** `build.sh` (674 linhas, exige root) → copia `kali-config/common` + `kali-config/variant-<nome>` para `config/` → `auto/config` chama `lb config noauto …` → `lb build`. Há `build-in-container.sh` + `Dockerfile` para build em contêiner.

**Decisões que valem estudo:**

1. **Metapacotes em vez de listas gigantes.** A variante XFCE tem 4 pacotes efetivos: `kali-linux-core`, `kali-desktop-live`, `kali-desktop-xfce`, `kali-linux-default`. Toda a curadoria vive no repositório de pacotes. → Adotamos a ideia (D-005), mas com `maska-*` próprios e só após estabilizar.
2. **Variantes por diretório** (`variant-xfce`, `-light`, `-large`, `-everything`, `-minimal`, `-kde`, `-gnome`…) sobrepostas sobre `common/`. → Modelo para `profiles/`.
3. **Hooks mínimos.** `kali-hacks.chroot`: habilita `CRYPTSETUP=y` no initramfs (persistência cifrada), `update-initramfs -u`, `updatedb`, e **`apt-mark hold` nos pacotes de kernel no live**. No instalador (`includes.installer/.../live-installer.d`) o *hold* é removido. → Ideia adaptável: kernel congelado no live, atualizável no sistema instalado.
4. **Verificação de integridade do bootstrap.** O `Dockerfile` baixa `Packages.gz`, extrai `Filename`/`SHA256` do `kali-archive-keyring` e do `live-build`, confere com `sha256sum -c` e só então instala. Usa `--keyring=` explícito no `debootstrap`. → Padrão correto: nunca desabilitar validação. (Limite: o `Packages.gz` vem do mesmo servidor por HTTPS; a raiz de confiança é o TLS.)
5. **CI mínimo:** `bash -n` + `shellcheck` (JSON → GitLab Code Quality). Nosso CI começa igual.
6. **Hook de limpeza** `remove-bloat-from-recommended-packages.chroot` remove pacotes puxados via *Recommends* (xorg, texlive…) — sinal de que `apt-recommends` custa tamanho. → Considerar `--apt-recommends false` com lista explícita.

**O que NÃO copiar / riscos observados:**

- `auto/config` altera o sistema do host: cria symlink `…/data/debian-cd/<dist> -> sid` dentro de `/usr/share/live/build` para que o live-build aceite a distro Kali. Não precisamos disso com Debian puro.
- `--apt-indices=false`, `--security false`, `--updates false`, `--backports false`: coerente para rolling, **inadequado** para Debian estável (queremos `debian-security`).
- Usuário live `kali` e script `0031-kali-user-setup` altera shell para zsh. Credenciais padrão em sistema instalado são risco; o nosso live deve ser explicitamente "somente live".
- `Dockerfile` usa `debian:stable-slim` sem fixar digest → build não reprodutível. Nós devemos fixar digest ou usar `snapshot.debian.org`.
- Licença do repositório é GPL-2; não copiamos código.

## 2. Mint — o que reaproveitar e o que não

- **`live-installer`** (Python, ~3,6 mil linhas em `usr/lib/live-installer/`): GTK, usa `parted`/`gparted`, `gdisk`, `gir1.2-timezonemap`, `gir1.2-webkit2-4.1`, `circle-flags-svg`. O `installer.py` suporta dois layouts de mídia (Ubuntu/casper e Debian/`/run/live/medium/live`), copia o `filesystem.squashfs` e roda `rm -rf` dentro do chroot *do alvo* (`/etc/live`, `/lib/live`, `/etc/casper*` …). **Conclusão:** o código prevê layout Debian/live-boot, mas a viabilidade em Debian puro **não foi testada**; exige empacotar e manter o instalador e dependências, e mexe em partições. Fora do MVP; Calamares é a alternativa mais barata (existe em trixie).
- **`mint-themes`** (GPL-3+): **ausente do Debian**. Pode ser compilado do upstream (empacotamento próprio, fonte e versão fixadas) numa fase de identidade visual; marcas do Mint não podem ser usadas.
- **`cinnamon` / `nemo`** (6.7.9 upstream): Debian trixie tem 6.4.10 / 6.4.5. Nemo é opcional (dependências a verificar com `apt-cache depends` no build); não é necessário no MVP (Thunar basta). Não instalar `.deb` do Mint em Debian: ABIs e dependências divergem.

## 3. Debian `live-build`

- Versão em trixie: `1:20250505+deb13u1` (upstream `1:20250814` é "prepare for forky"). **Usar a versão do trixie** no build para não depender de snapshot de desenvolvimento.
- Árvore: `data/`, `examples/`, `functions/`, `scripts/` (build/, config/…), `manpages/`. Os exemplos em `examples/` e o *Live Manual* são a fonte da configuração para ISO híbrida com UEFI+BIOS.
- O Kali usa `--debian-installer live` (visto em `auto/config`): o d-i integrado é uma alternativa de instalador a verificar no Live Manual.

## 4. REA (`morluto/rea`) — o que é e o que foi feito

REA ("Reverse Engineer Anything", MIT) é um MCP/CLI em Node.js para análise de binários nativos, apps JS/Electron, .NET, APKs, firmware etc. Fonte clonada em `_vendor/rea/src` (commit `0d5c7b6`, v6.7.0); **não instalado** globalmente nem registrado no agente (`setup` não foi executado).

Execução em 2026-10-22, com aprovação do usuário, via `npx -y rea-agents@6.7.0` (pacote oficial do npm), Node 25.2.1 — fora da faixa suportada (`^22.19 || ^24.11 || >=26`); o npm emitiu `EBADENGINE`, mas os comandos usados funcionaram.

| Alvo | Comando | Resultado |
|---|---|---|
| `live-build_20250505+deb13u1_all.deb` (SHA-256 conferido com o índice do trixie) | `inspect-artifact` | **Recusado**: `unsupported binary format` (REA não lê `.deb`/`ar`) |
| `data.tar.xz` extraído desse `.deb` | `inspect-artifact` | **Recusado**: `unsupported binary format` |
| `/usr/bin/nmap` de `nmap_7.95+dfsg-3_amd64.deb` (SHA-256 do `.deb` conferido) | `inspect-artifact` | **OK**: formato ELF, SHA-256 `c7e3cd8c…0b8ac`, hash `verified`; próxima sondagem sugerida: `open_binary`, que exige um provedor nativo (Ghidra/Hopper/IDA) — não disponível |

Conclusão: o REA não analisa repositórios de configuração nem pacotes Debian; serve para inspecionar **binários** que entram na ISO (e, com Ghidra configurado, analisá-los a fundo). A conferência de proveniência do `live-build` foi feita com Python (§6).

## 6. Verificação cruzada com as fontes oficiais (2026-10-22)

Cada decisão do projeto foi comparada com o código-fonte da versão **que vai no trixie**, não com o `main` dos repositórios.

**Proveniência:** o pacote `live-build_20250505+deb13u1_all.deb` (SHA-256 conferido contra o índice `Packages`) foi comparado arquivo a arquivo com o tag `debian/1%20250505+deb13u1` de `salsa.debian.org/live-team/live-build`: `config`, `chroot`, `chroot_hooks`, `binary_iso`, `functions/configuration.sh`, `functions/compatibility.sh` e `lb` são **idênticos** (após normalizar CRLF do checkout no Windows).

| Afirmação / decisão do projeto | Fonte verificada | Resultado |
|---|---|---|
| Todas as opções de `auto/config` existem | `scripts/build/config` (tag trixie) | ✅ todas (24) |
| Nome da ISO `live-image-amd64.hybrid.iso` | `binary_iso`, `LB_IMAGE_NAME=live-image` | ✅ confirmado |
| `includes.chroot` aplicado **depois** dos pacotes; hooks `config/hooks/live/*.chroot` | `scripts/build/chroot`, `chroot_hooks`, `compatibility.sh` | ✅ |
| `live-build` adiciona `live-boot live-config live-config-systemd systemd-sysv` | `scripts/build/config` | ✅ |
| Parâmetros `username= hostname= locales= keyboard-layouts= timezone=` | componentes do `live-config` | ✅ |
| Usuário Live é criado | `live-config/components/0030-user-setup` | ❌ **corrigido**: só roda se o pacote `user-setup` existir; ele é *Recommends* do `live-config` e o build usa `--apt-recommends false` → `user-setup` adicionado em `00-base` |
| Senha do usuário Live | `0030-user-setup` | ℹ️ hash fixo da senha **`live`**; `0040-sudo` dá `NOPASSWD: ALL` — aceitável só no Live; o Calamares não copia esse usuário (ele é criado em tempo de boot, no overlay) |
| Agente polkit `lxpolkit` funciona no XFCE | `lxsession 0.5.6-2: data/lxpolkit.desktop.in.in` | ❌ **corrigido**: `NotShowIn=...;XFCE;...` → trocado por `mate-polkit` (`NotShowIn=GNOME;KDE;`) |
| `xfce4-screensaver` inicia no XFCE | `xfce4-screensaver 4.18.4: data/xfce4-screensaver.desktop.in` | ✅ `OnlyShowIn=XFCE;` |
| Driver *modesetting* sem pacote extra | lista de arquivos de `xserver-xorg-core` (trixie) | ✅ `modesetting_drv.so` |
| `ufw`: habilitar e política padrão | `ufw 0.36.2-9: conf/ufw.conf`, `conf/ufw.defaults` | ✅ `ENABLED=no` (o hook muda para `yes`); entrada `DROP`, saída `ACCEPT` |
| `ConditionKernelCommandLine=!boot=live` | man `systemd.unit` | ✅ negação com `!`; `chave=valor` casa a atribuição exata |
| Calamares lê a imagem do Live | `calamares-settings-debian 13.0.13-1: modules/unpackfs.conf` | ✅ `/run/live/medium/live/filesystem.squashfs` (caminho do `live-boot`) |
| Calamares remove pacotes Live | `modules/packages.conf` | ✅ remove `live-boot*`, `live-config*`, `live-tools`, `calamares-settings-debian` |
| `os-prober` precisa ser ativado à mão | `helpers/calamares-bootloader-config` | ❌ **doc corrigida**: o helper já define `GRUB_DISABLE_OS_PROBER=false` e roda `update-grub` |
| Instalação offline do GRUB | mesmo helper: `apt-get install grub-efi` no alvo | ⚠️ **corrigido**: sem pool de pacotes na ISO isso exigiria rede → `grub-efi` adicionado em `40-installer` |
| Repositórios do sistema instalado sem backports | `helpers/calamares-sources-final` | ⚠️ difere: grava `trixie-backports` e `deb-src` (documentado; aceito por ora) |
| Repositório local durante a instalação | `helpers/calamares-sources-media` | ℹ️ usa `[trusted=yes] file:/run/live/medium` temporariamente (configuração do próprio Debian, removida ao final); nosso teste estático só vale para os arquivos deste repositório |
| Grupo de administração / root | `modules/users.conf` | ✅ grupo `sudo`, `setRootPassword: false` |
| Marca do instalador | `settings.conf: branding: debian` | ⚠️ aparece como Debian; precisa de marca própria antes de qualquer distribuição pública |
| Ghidra roda com OpenJDK 21 | README de `NationalSecurityAgency/ghidra` | ❌ **corrigido**: exige **JDK 25** → perfil `java-runtime` usa `openjdk-25-jdk` |
| ZAP 2.17.0, Java 17+, checksums publicados | site + release `v2.17.0` no GitHub | ✅ (release de 2025-12-15) |
| Ghidra 12.2 publica SHA-256 | release `Ghidra_12.2_build` | ✅ hash no texto; arquivo `ghidra_12.2_PUBLIC_20261016.zip` |
| Metasploit: sem binário verificável automaticamente | API do GitHub + docs Rapid7 | ✅ sem releases no GitHub; instalação via `apt.metasploit.com`/script, mantida manual |
| Versões Debian vs. upstream | tags do `nmap/nmap` | ℹ️ upstream `7.992`, trixie `7.95+dfsg-3` (normal em Debian estável: correções de segurança são retroportadas) |
| Espelho de segurança gravado pelo `live-build` | `functions/configuration.sh` | ℹ️ padrão `http://security.debian.org/`; o apt valida assinaturas, então HTTP não quebra a integridade |
| Kali `live-build-config`, Mint `live-installer`, `mint-themes`, Cinnamon, Nemo (§1–§2) | clones já analisados | ✅ sem mudança; nenhum código copiado |

**Problema encontrado no próprio projeto durante a verificação:** 12 arquivos (inclusive `auto/config`, `scripts/build.sh`, `scripts/fetch-package-index.sh`) estavam com **CRLF**, introduzido por edições feitas no Windows; no Debian esses scripts falhariam. Foram convertidos para LF, foi criado `.gitattributes` (`eol=lf`) e `tests/static-checks.sh` passou a reprovar CRLF (com `grep -U`, porque o grep do Windows esconde o `\r`). A varredura anterior que dizia "sem CRLF" estava errada por esse motivo.

## 5. Disponibilidade de ferramentas em Debian trixie

Consultado via `sources.debian.org/api/src/<pacote>/` em 2026-10-22 (pacotes-fonte):

| Categoria do prompt | Presentes em trixie | Ausentes (precisam de módulo/alternativa) |
|---|---|---|
| Reconhecimento / rede | nmap 7.95, hydra 9.5, aircrack-ng | — |
| Tráfego | wireshark 4.4.18 (fonte `wireshark`), tshark | — |
| Aplicações web | sqlmap 1.9.6, gobuster 3.6.0, ffuf 2.1.0, nikto 2.1.5 (antigo) | **zaproxy**, burpsuite |
| Senhas | john 1.9.0, hashcat 6.2.6 | — |
| Engenharia reversa | binwalk 2.4.3 | **ghidra**, radare2 (só em sid, 6.1.8; não em trixie) |
| Forense | sleuthkit 4.12.1, autopsy 2.24 | — |
| Vulnerabilidades / exploração | (lynis 3.1.4 para auditoria do próprio sistema) | **metasploit-framework** |

Observações: `autopsy 2.24` é a versão legada baseada em web do Sleuth Kit, não o Autopsy 4 (Java). `nikto 2.1.5` é muito antigo. Qualidade/atualidade por ferramenta precisa ser reavaliada antes de entrar em um perfil.
