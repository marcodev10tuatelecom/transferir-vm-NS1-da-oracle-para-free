# Status da reconstrução completa NS1/NS2

## Estado atual

**NÃO ESTÁ PRONTO ainda como Bíblia completa para reconstruir NS1 e NS2 em outra nuvem a partir de Ubuntu limpo.**

O repositório atual está, neste momento, organizado principalmente como arquivo técnico da recuperação OCI/Free Tier e contém diagnósticos, evidências e alguns scripts de recuperação. Ele ainda não contém todos os instaladores, configurações canônicas, templates, variáveis por nó e validadores necessários para uma reconstrução integral dos dois servidores em outra nuvem.

## O que já existe no repositório

- contexto consolidado da recuperação OCI;
- evidência do estado atual de NS1/NS2;
- scripts de diagnóstico Free Tier;
- capacity watcher A1;
- gate de pré-terminação do NS1;
- pesquisa e evidências sobre A1/Free Tier;
- manifesto de screenshots da investigação.

## O que ainda falta para considerar a reconstrução completa pronta

1. Bootstrap comum Ubuntu 22.04 ARM64 com prechecks, atualização controlada, pacotes-base e política de reboot.
2. Usuários/grupos canônicos e sudo (`root`, `marco`, `adminfra` e contas técnicas), com permissões e ownership finais.
3. Rede por provedor, hostname, `/etc/hosts`, sysctl, NTP, DNS resolver local e validação de rotas.
4. Firewall/UFW completo para NS1 e NS2, com matriz de portas e validação externa/interna.
5. Instalação e configuração completa do BIND9 autoritativo.
6. Zonas DNS canônicas e recordsets exatos para todos os domínios atualmente publicados.
7. DNSSEC: política, chaves/rollover, signing, DS, parental agents e procedimentos de restauração/migração.
8. Nginx: instalação, estrutura canônica, todos os vhosts, snippets, headers, health checks e páginas públicas.
9. PKI/TLS: estrutura `/etc/letsencrypt-tps`, emissão/reemissão dos certificados, hooks e validação; nenhuma chave privada deve ser versionada no GitHub.
10. FFmpeg/ffprobe: versão-alvo, instalação, codecs e testes.
11. MediaMTX: versão, binário, usuário, diretórios, YAML canônico, systemd, listeners, paths e autenticação.
12. Serviços systemd de rádio/TV/remux/publishers, scripts de runtime e timers.
13. Estrutura de diretórios de mídia e repositórios das emissoras, ownership e quotas.
14. Configuração específica NS1 versus NS2, incluindo funções primária/secundária e replicação/transferência onde aplicável.
15. Health checks completos de DNS, HTTP/HTTPS, HLS, RTMP, WebRTC, MediaMTX API e serviços systemd.
16. Scripts de backup/restore, rollback e fail-closed.
17. Cutover para nova nuvem, incluindo estratégia de IPs, TTL, glue/NS, DNSSEC e testes antes/depois.
18. Validação final TPS-12/AS-BUILT dos dois nós.
19. Manifesto SHA256 de todos os artefatos finais.
20. Documentação de execução sequencial: servidor novo -> bootstrap -> NS1 -> certificação -> NS2 -> certificação -> cutover.

## Regra de segurança

Nenhuma senha, chave SSH privada, token, PSK, chave privada TLS ou segredo DNSSEC privado deve ser commitado neste repositório público. A documentação deve indicar como criar, importar ou restaurar esses segredos por canal seguro.

## Critério de pronto

O projeto só poderá ser marcado `REBUILD_READY=YES` quando todos os módulos acima tiverem:

- script final versionado;
- `bash -n` PASS;
- ShellCheck PASS na versão-alvo quando aplicável;
- idempotência demonstrada;
- precheck e pós-check;
- rollback/fail-closed;
- evidência de validação;
- documentação por nó;
- dependências e ordem de execução explícitas.

Estado atual: `REBUILD_READY=NO`.
