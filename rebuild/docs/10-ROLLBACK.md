# Rollback

Cada script guarda arquivos sobrescritos em `/var/log/tps-rebuild/<RUN_ID>/backup` quando aplicável.

Rollback não significa restaurar tarballs históricos indiscriminadamente. Em falha de gate:

- pare a nova autoridade;
- restaure somente arquivos alterados pelo gate;
- execute o validador da camada anterior;
- preserve logs/evidência;
- não avance.

No cutover DNS, rollback envolve restaurar registros/delegação anterior apenas se as chaves/DNSSEC continuarem coerentes. Nunca faça rollback de DS sem verificar qual DNSKEY está publicado e servido.
