# Contribuindo

O projeto está em pré-alpha. Contribuições são bem-vindas após a Fase 4 (primeira ISO mínima).

Regras:

1. **Sem afirmações sem evidência.** Não escreva "seguro", "hardened", "reproduzível" ou resultados de teste sem logs anexados.
2. **Segurança de origem:** pacotes apenas do archive Debian (ou módulo documentado com versão + SHA-256/assinatura). Nunca desative verificação de assinatura/certificado; `tests/static-checks.sh` deve passar.
3. **Licenças:** não copie código de outros projetos sem registrar origem e licença compatível com GPL-3.0-or-later em `docs/`.
4. **Mudanças pequenas e verificáveis**, com critério de aceitação no PR. Um pacote novo = justificativa em comentário.
5. **Nada destrutivo:** scripts não podem alterar discos, partições ou bootloader do host.
6. Marcas e arte de terceiros não são aceitas em `branding/`.

Antes do PR: `sh tests/static-checks.sh`.
