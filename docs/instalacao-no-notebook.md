# Instalar o Maska OS no seu notebook

**Status: nada disto foi executado.** A ISO ainda não existe; o instalador (Calamares) nunca foi testado neste projeto. Este guia define a ordem segura. Instalar em disco **altera partições e o boot do notebook**: o projeto não faz isso por você — nenhum script grava em discos, e o instalador só roda quando você o abre e confirma.

## 0. Decisões que são suas (antes de qualquer coisa)

| Decisão | Opções | Observação |
|---|---|---|
| Windows | **Manter (dual boot)** ou **substituir** | Substituir apaga o Windows e seus dados daquele disco. Dual boot altera o gerenciador de boot e exige espaço livre |
| Criptografia | Disco criptografado (LUKS) ou não | Protege contra perda/roubo; senha esquecida = dados perdidos |
| Espaço | Quanto dar ao Linux | Hoje há ~30 GB livres em C:. O tamanho instalado real só será conhecido após o primeiro build/instalação em VM; decida o tamanho depois disso, com folga |

## 1. Preparação no Windows (somente se manter o Windows)

1. **Backup completo fora do notebook** (arquivos + imagem do sistema). Sem backup, não continue.
2. **BitLocker / criptografia do dispositivo:** verifique em Configurações → Privacidade e segurança → Criptografia do dispositivo (ou BitLocker). Se estiver ativa, **anote e guarde a chave de recuperação** (conta Microsoft) — alterar partições/boot pode pedir essa chave.
3. Desative **Inicialização rápida** e hibernação (Painel de Controle → Opções de energia) para o Windows não deixar o NTFS "sujo".
4. **Reduza a partição C: pelo próprio Windows** (Gerenciamento de Disco → Reduzir Volume), deixando espaço **não alocado**. Não crie nem formate partições no Windows para o Linux; o instalador usa o espaço livre.
5. **Secure Boot:** o plano usa GRUB e shim assinados pelo Debian, compatíveis com Secure Boot ativo (**não testado**). Iniciando a ISO pelo Ventoy, o Secure Boot pode exigir inscrever a chave do Ventoy (tela MOK). Desativar o Secure Boot altera o firmware: só faça se entender o efeito.

## 2. Ensaiar numa VM primeiro (obrigatório)

Antes de tocar no notebook, instale a ISO numa **VM UEFI** com disco virtual vazio (ver [build-in-vm.md](build-in-vm.md), §7). Registre em `docs/test-reports/`:

- A instalação termina sem erro; o sistema reinicia no Maska OS instalado (não no Live).
- Login funciona com o usuário criado no instalador; sem usuário/senha do Live no sistema instalado.
- `sudo ufw status verbose` mostra ativo; `systemctl status unattended-upgrades` e timers `apt-daily*` presentes; `tlp-stat -s` mostra TLP ativo.
- Português do Brasil e teclado `br` presentes; Wi-Fi, áudio e Bluetooth funcionam (os que a VM permitir).
- Instalação com criptografia (LUKS): pede a senha no boot e inicializa.
- `sudo apt update && sudo apt full-upgrade` conclui usando apenas repositórios Debian.

Se qualquer item falhar, **não prossiga** para o notebook.

## 3. Instalação no notebook

1. Inicialize a ISO pelo Ventoy (HD externo) ou, de preferência, por um **pendrive dedicado** à instalação. O Ventoy não precisa ser alterado: apenas copie o `.iso` (ver [build-in-vm.md](build-in-vm.md), §8).
2. No Live, teste Wi-Fi, vídeo, áudio e teclado **antes** de abrir o instalador.
3. Abra o instalador. Na etapa de partições:
   - **Identifique o disco interno pelo tamanho e modelo.** O HD externo de 1 TB com o Ventoy **nunca** é o destino. Se tiver dúvida, desconecte o HD externo depois de a ISO carregar (verifique antes se a ISO foi carregada na RAM; senão desconectar derruba o Live) ou use o pendrive dedicado.
   - Dual boot: escolha o espaço **não alocado** criado no passo 1.4; **não** apague nem formate as partições do Windows (EFI System, Microsoft reserved, C:, Recuperação).
   - A partição **EFI System já existente** deve ser **reaproveitada** (ponto de montagem `/boot/efi`, **sem formatar**), senão o boot do Windows quebra.
   - Use o resumo final do instalador: leia a lista do que será alterado e confira cada dispositivo.
4. Defina criptografia conforme decidido em §0.
5. Ao concluir, reinicie, remova a mídia e confirme que o menu de boot lista o Linux (e o Windows, no dual boot).

## 4. Depois de instalar

```sh
sudo apt update && sudo apt full-upgrade
sudo ufw status verbose
sudo timeshift --list        # configure o primeiro ponto de restauração pelo aplicativo Timeshift
tlp-stat -s
```

- Dual boot: o instalador do Debian (Calamares) **reativa o `os-prober` e roda `update-grub`** (verificado na fonte do `calamares-settings-debian` 13.0.13). Se mesmo assim o Windows não aparecer, confira `GRUB_DISABLE_OS_PROBER=false` em `/etc/default/grub` e rode `sudo update-grub`.
- Repositórios: o instalador grava um `/etc/apt/sources.list` com `trixie`, `trixie-updates`, `trixie-security` e também `trixie-backports` e `deb-src`. Os backports não são aplicados automaticamente; se não quiser baixar índices de código-fonte, comente as linhas `deb-src`.
- Instale perfis opcionais conforme necessidade: `sudo maska-profile list`, `sudo maska-profile install multimidia` etc. No sistema instalado a instalação é permanente.
- Firmware: `sudo fwupdmgr get-updates` (lê o LVFS; aplicar atualizações de firmware é decisão sua).

## 5. Se algo der errado

- **Windows não inicia / pede chave BitLocker:** use a chave de recuperação guardada no passo 1.2.
- **Linux não inicia:** reinicie pela mídia Live e inspecione; não reinstale por cima sem entender o erro.
- **Reverter para só Windows:** restaure do backup do passo 1.1 ou use a mídia de recuperação do Windows. Remover o Linux (partições e entrada de boot) exige cuidado: faça somente a partir de um procedimento oficial da Microsoft/Debian, com o backup em mãos.
- Em qualquer dúvida sobre qual disco é qual, **pare**.
