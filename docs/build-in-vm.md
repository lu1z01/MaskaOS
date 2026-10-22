# Construir, validar e copiar a ISO para o Ventoy

Guia para a VM Debian 13 hospedada no HD externo. **Nada abaixo foi executado ainda**; revise cada passo antes. Nenhum passo formata, particiona ou altera o Ventoy.

## Regras de segurança

- O disco virtual da VM fica em uma **pasta** (ex.: `VMs\`) na partição de dados do Ventoy. Não use `Ventoy2Disk`, não "atualize"/"instale" o Ventoy e não mexa na pequena partição `VTOYEFI`.
- Faça uma cópia de segurança do conteúdo importante do HD antes de começar (ele guarda outros dados e outras ISOs).
- Não há nada neste repositório que grave em discos. Se o build falhar, apague apenas o disco virtual da VM.
- A cópia da ISO para o Ventoy é um **arquivo copiado pelo Explorer**, feito por você.

## 1. Preparar a VM (Windows)

1. Verifique o sistema de arquivos da partição de dados do Ventoy (Explorer → Propriedades): exFAT ou NTFS servem; FAT32 não (limite 4 GB por arquivo).
2. Instale o VirtualBox (do site oficial) ou use outro hipervisor de sua preferência.
3. Baixe a ISO **netinst do Debian 13 amd64** de `cdimage.debian.org/debian-cd/current/amd64/iso-cd/` e **verifique** `SHA512SUMS` e a assinatura conforme `debian.org/CD/verify`. Não use ISO de outras fontes.
4. Crie a VM: tipo Linux/Debian 64-bit, **4096 MB** de RAM, 4 vCPUs, disco VDI dinâmico de **60 GB** (estimativa) salvo em `<Ventoy>:\VMs\maska-build\`. Rede NAT.
5. Instale o Debian 13 **minimal** (sem ambiente gráfico; marque "SSH server" apenas se quiser; "standard system utilities"). Crie um usuário normal com `sudo`.

## 2. Preparar o Debian da VM

```sh
sudo apt update
sudo apt install --no-install-recommends live-build debootstrap squashfs-tools xorriso \
     isolinux syslinux-common syslinux-utils grub-pc-bin grub-efi-amd64-bin mtools dosfstools \
     git curl xz-utils gpgv debian-archive-keyring python3 shellcheck ca-certificates
```

Copie o repositório para o **disco da VM** (por exemplo `~/maska`, via `git clone` ou `scp`). Não use pasta compartilhada do hipervisor: `build.sh` recusa `/media`, `/mnt` e `/run/media`, e permissões/symlinks falhariam.

## 3. Verificações antes do build

```sh
cd ~/maska
sh scripts/check-env.sh
sh scripts/fetch-package-index.sh    # com gpgv + debian-archive-keyring, valida a assinatura do InRelease
sh tests/static-checks.sh
```

Todos devem terminar sem `ERRO`. `AVISO` (por exemplo, sem assinatura GPG) exige entender o motivo antes de prosseguir.

## 4. Build

```sh
sh scripts/build.sh      # roda check-env, índice, testes estáticos, lb config e sudo lb build
```

Saída: `build/out/<arquivo>.iso` e `build/out/SHA256SUMS`; log em `build/build.log`. Se a ISO não aparecer, leia o log antes de alterar qualquer arquivo. O nome real da ISO (provavelmente `live-image-amd64.hybrid.iso`) e a duração devem ser registrados.

## 5. Validar a ISO (na VM)

```sh
sh scripts/verify-iso.sh build/out/*.iso
sha256sum -c build/out/SHA256SUMS
```

Confira também o manifesto (`build/binary/live/filesystem.packages` ou equivalente) conforme o critério 4 de [build-plan.md](build-plan.md#4-critérios-de-aceitação-do-primeiro-build).

## 6. Levar a ISO para o Windows e conferir o SHA-256

Opção sem software extra: servidor HTTP temporário que serve **apenas** `build/out`.

Na VM (NAT):
```sh
cd build/out && python3 -m http.server 8000
```
No VirtualBox, adicione regra de redirecionamento de portas NAT: host `127.0.0.1:8000` → convidado `8000`. No Windows (PowerShell):

```powershell
cd $env:USERPROFILE\Downloads
curl.exe -O http://127.0.0.1:8000/SHA256SUMS
curl.exe -O http://127.0.0.1:8000/<arquivo>.iso
Get-FileHash -Algorithm SHA256 .\<arquivo>.iso
Get-Content .\SHA256SUMS
```
Os dois hashes devem ser idênticos. Encerre o servidor (`Ctrl+C`) e remova a regra de porta.

## 7. Testar antes do Ventoy (VM de teste)

Crie outra VM (4096 MB, EFI desligado, depois ligado), anexe a ISO, inicialize e siga os critérios 5–9 de [build-plan.md](build-plan.md#4-critérios-de-aceitação-do-primeiro-build), incluindo a [medição de RAM](build-plan.md#5-meta-de-ram-em-repouso-e-como-medir). Registre em `docs/test-reports/`.

## 7b. Ensaio de instalação em VM

Com a VM de teste em **UEFI** e disco virtual vazio, execute o instalador e verifique os critérios 12–13 de [build-plan.md](build-plan.md#4-critérios-de-aceitação-do-primeiro-build). É só na VM: o disco virtual é descartável.

## 8. Copiar para o Ventoy (manual)

1. Conecte o HD externo. A partição grande de dados aparece como uma unidade (por exemplo `E:`).
2. No Explorer, copie o arquivo `.iso` para a **raiz** (ou uma pasta) dessa unidade. É só copiar um arquivo — o Ventoy lista ISOs automaticamente.
3. Ejete o disco com segurança.
4. No computador de teste, inicialize pelo HD externo (menu de boot do firmware) e escolha a ISO no menu do Ventoy. Tente primeiro o modo normal; se não inicializar, o menu do Ventoy oferece outros modos (ex.: GRUB2) — **registre o que funcionou**. Compatibilidade com Ventoy e com Secure Boot **não está testada**.
5. A ISO inicia como Live: usa RAM e não altera o disco interno enquanto você não abrir o instalador. **Não abra o instalador no notebook antes de concluir o ensaio em VM** e ler [instalacao-no-notebook.md](instalacao-no-notebook.md).

## 9. Se algo der errado

- Falha no build: guarde `build/build.log`; reexecute `./scripts/build.sh` depois de entender a causa. Limpeza da árvore de build: apague a pasta `build/` (nunca fora do repositório).
- Disco da VM cheio: aumente o disco virtual no hipervisor; não use ferramentas de disco do host.
- ISO não aparece no Ventoy: confirme que o arquivo termina em `.iso` e que a cópia terminou antes de ejetar.
