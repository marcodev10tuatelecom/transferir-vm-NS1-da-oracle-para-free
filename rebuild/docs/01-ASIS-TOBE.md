# AS-IS comprovado x TO-BE clean-room

| Área | AS-IS histórico relevante | TO-BE desta reconstrução |
|---|---|---|
| DNS NS1 | primary funcional | único primary/writer |
| DNS NS2 | houve snapshot com falha pública | secondary TSIG/XFR certificado antes do cutover |
| Nginx | múltiplas fases/árvores históricas | uma árvore ativa, sem staging absoluto |
| TLS | já houve `/etc/letsencrypt` e `/etc/letsencrypt-tps` | store único `/etc/letsencrypt` |
| MediaMTX NS1 | `tps-mediamtx.service` funcional | mesma autoridade canônica |
| MediaMTX NS2 | houve processo órfão em snapshot | somente via `tps-mediamtx.service` |
| Repositório | legado `content`/`filler` coexistiu | somente `/srv/tpsmedia/repository` |
| Emissoras | catálogo evoluiu ao longo do projeto | matriz de nove estações versionada |
| Observabilidade | exporters já apareceram failed | só habilitar depois de validação local |

A reconstrução não é clonagem byte-a-byte. É reprodução funcional controlada do estado canônico.
