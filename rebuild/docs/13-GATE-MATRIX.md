# Matriz de Gates

| Gate | Escopo | Script principal | Aceite |
|---|---|---|---|
| R00 | inventário | `00-preflight.sh` | Ubuntu/NTP/rede/capacidade PASS |
| R01 | bootstrap | `01-bootstrap.sh` | pacotes/diretórios PASS |
| R02 | identidade | `02-identities.sh` | service users + admin verificado |
| R03 | firewall | `03-firewall.sh` | guest + cloud rules comprovadas |
| R04 | DNS base | `04-bind-common.sh` | config base válida |
| R05 | NS1 DNS | `05-bind-ns1-primary.sh` | primary AA, zones válidas |
| R06 | NS2 DNS | `06-bind-ns2-secondary.sh` | XFR/secondary PASS |
| R07 | DNS pair | `07-dns-validate.sh` | SOA parity |
| R08 | web/TLS | `08..11b` | Nginx + certbot dry-run PASS |
| R09 | Media | `12..17c` | MediaMTX + repository + selected playout PASS |
| R10 | Ops | `18..20` | observabilidade + backup PASS |
| R11 | Certificação | `21` + `99` + reboot | local/external/reboot PASS |
