# Ordem operacional

Execute NS1 e NS2 por gate. Não conclua toda a máquina A e só depois descubra conflito na B.

1. `00-preflight.sh` — ambos.
2. `01-bootstrap.sh` — NS1, validar; NS2, validar.
3. `02-identities.sh` — NS1; NS2.
4. `03-firewall.sh` — NS1; NS2; confirmar também firewall da nuvem.
5. `04-bind-common.sh` — ambos.
6. `05-bind-ns1-primary.sh` — NS1.
7. transferir TSIG por canal seguro fora do Git.
8. `06-bind-ns2-secondary.sh` — NS2.
9. `07-dns-validate.sh` — ambos e testes cruzados.
10. `08-nginx-base.sh` — ambos.
11. `09-nginx-vhosts.sh` — conforme inventário.
12. apontar registros A de teste/hosts somente quando planejado.
13. `10-tls-issue.sh` — emitir certificados novos.
14. `11-tls-validate.sh`.
15. `12-mediamtx-install.sh`.
16. `13-mediamtx-configure.sh`.
17. `14-media-validate.sh`.
18. `15-repository-layout.sh`.
19. habilitar playout por emissora somente depois de conteúdo válido.
20. `18-observability.sh`.
21. `19-backup.sh`.
22. `99-final-certification.sh`.
23. reboot controlado e repetir `99-final-certification.sh`.
24. cutover de delegação/DS somente depois de tudo acima.
