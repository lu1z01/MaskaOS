# Ferramentas pesadas ou ausentes do Debian: instalação posterior

Contexto: no Debian 13 "trixie" não existem pacotes de `zaproxy`, `ghidra`, `burpsuite` nem `metasploit-framework` (consulta ao índice em 2026-10-22), e **não usamos repositórios binários do Kali**. Esses programas **não vão na ISO** e **nenhum script do projeto os baixa ou executa**. Este documento descreve o que o usuário pode fazer manualmente.

Informações abaixo vieram das páginas oficiais em 2026-10-22; versões mudam. Confira sempre a página oficial antes de instalar, compare checksums e, se houver, assinaturas. Se não for possível verificar a integridade, não instale.

Aviso: no Live, tudo instalado vai para a RAM e some ao reiniciar (a ISO não tem persistência). Instalações grandes disputam RAM com o sistema; use uma máquina com mais memória ou instale em um sistema Debian dedicado. Use apenas em alvos autorizados.

## Dependência comum: Java

Ghidra e ZAP precisam de Java. O perfil opcional instala o runtime do Debian:

```sh
sudo maska-profile install java-runtime      # instala openjdk-25-jdk (existe no trixie: 25.0.3)
```

Requisitos verificados em 2026-10-22: **Ghidra exige JDK 25 64-bit** (README do repositório `NationalSecurityAgency/ghidra`), por isso o perfil usa `openjdk-25-jdk` e não o `default-jre` (OpenJDK 21). ZAP exige Java 17 ou superior (site oficial). Reconfira a cada versão nova.

## OWASP ZAP

- Versão indicada em zaproxy.org/download e no release mais recente do GitHub (`zaproxy/zaproxy`, `v2.17.0`, publicado em 2025-12-15) em 2026-10-22: **2.17.0**; o release traz `ZAP_2.17.0_Linux.tar.gz`, `ZAP_2_17_0_unix.sh` e checksums no texto. Formas oficiais para Linux: instalador `.sh`, `tar.gz` e **Flatpak (Flathub `org.zaproxy.ZAP`)**.
- Caminho com assinatura de repositório já conhecida: Flatpak. `flatpak` existe no trixie (1.16). Adicionar o Flathub passa a confiar no repositório Flathub; decida conscientemente.
- Caminho manual: baixe o `tar.gz`, compare o checksum com o publicado na página de release do projeto no GitHub (o site diz que os checksums ficam lá; confirme o algoritmo na página), extraia em `~/opt/zap` e execute como usuário comum.

## Ghidra

- Release no GitHub (`NationalSecurityAgency/ghidra`, tag `Ghidra_12.2_build`, publicado em 2026-10-22): **Ghidra 12.2**, arquivo único `ghidra_12.2_PUBLIC_20261016.zip`; o texto do release contém um SHA-256 — compare-o com `sha256sum` desse arquivo.
- Instalação manual: baixe o `.zip` da página de releases, calcule `sha256sum` e compare, extraia em `~/opt/ghidra` e execute `ghidraRun` como usuário comum com o JDK exigido.
- Ferramenta de uso intensivo de memória e disco; no Live, avalie primeiro se há RAM livre (`maska-measure-idle`) ou prefira um sistema instalado.

## Metasploit Framework

- O repositório `rapid7/metasploit-framework` não publica releases binários no GitHub (verificado pela API em 2026-10-22). A Rapid7 distribui para Debian/Ubuntu pelo repositório `apt.metasploit.com` e por um script instalador do repositório `metasploit-omnibus`, que importa a chave de assinatura da Rapid7.
- A documentação consultada **não** informa fingerprint da chave nem passos de verificação manual. Por isso o projeto **não automatiza** essa instalação e não permite `curl | sh` (o teste estático rejeita). Se você optar por instalar: baixe o script, **leia-o**, obtenha o fingerprint da chave em documentação oficial da Rapid7 e só então execute, de preferência em uma VM descartável.
- Alternativa que evita instalar no sistema: executar o Metasploit em contêiner ou VM separada. Use só em laboratório próprio ou com autorização.

## Regra para novas ferramentas

Qualquer ferramenta nova só entra em perfil do projeto se: (1) estiver no archive Debian, ou (2) tiver módulo documentado com versão, URL oficial, SHA-256 e/ou assinatura verificável, licença e teste `--version`. Sem isso, fica só como orientação neste arquivo.
