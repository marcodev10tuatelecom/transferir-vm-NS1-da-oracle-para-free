# TPS NS1/NS2 Clean-Room Rebuild

Esta árvore é a implementação reproduzível da reconstrução de NS1 e NS2 a partir de Ubuntu limpo.

## Estado

- `AS_IS_PROVEN`: evidência histórica comprovada.
- `TO_BE_CANONICAL`: estado que esta reconstrução instala.
- `REQUIRES_NEW_CLOUD_VALUE`: dado que depende da nova conta/nuvem.

## Regras

1. Bare metal/VM tradicional; sem containers.
2. NS1 é o único DNS primary/writer.
3. NS2 é DNS secondary read-only via TSIG/XFR.
4. Um único `tps-mediamtx.service` por nó.
5. API, metrics, RTSP, HLS e signaling WebRTC ficam em loopback; RTMP/ICE somente conforme contrato.
6. Nginx é o único frontend HTTP/TLS.
7. Certificados novos são emitidos no destino; chaves privadas antigas não entram no Git.
8. Segredos ficam fora do repositório.
9. Todo gate é fail-closed.
10. Reboot controlado é parte da certificação.

Leia primeiro `docs/00-BIBLE.md` e execute na ordem de `docs/04-RUNBOOK-ORDER.md`.
