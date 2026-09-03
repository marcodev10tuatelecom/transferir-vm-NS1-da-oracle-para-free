# Arquitetura

```text
Internet
  |
  +-- DNS UDP/TCP 53 ---> NS1 primary
  |                    \-> NS2 secondary
  |
  +-- HTTPS 443 -------> Nginx Edge1/Edge2
  |                         |
  |                         +-> static pages
  |                         +-> HLS 127.0.0.1:8888
  |                         +-> WHEP 127.0.0.1:8889
  |
Studio encoders
  +-- RTMP 1935 -------> MediaMTX
  +-- SRT 8890 --------> optional

NS1 BIND -- TSIG/AXFR/IXFR --> NS2 BIND
```

## Independência

Queda de Host01 não deve derrubar DNS/Media. Queda de NS1 não deve impedir NS2 de continuar respondendo suas zonas já transferidas. Queda de NS2 não muda NS1 para outra função.

## Ownership

- BIND: `bind`/systemd distro.
- Nginx: `www-data`/systemd distro.
- MediaMTX: `tpsmedia`.
- Playout: `tps-playout`.
- arquivos de configuração: root, leitura mínima necessária.
