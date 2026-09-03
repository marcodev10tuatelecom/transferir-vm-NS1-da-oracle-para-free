# Certificação

A certificação possui três perspectivas independentes.

## Local

`99-final-certification.sh` prova configuração, serviços, autoridade de processos, listeners, TLS local/SNI, DNS local/peer, repositório, backup, NTP e ausência de raízes legadas conhecidas.

## Externa

`21-public-validate.sh` deve rodar em terceiro host. Ele prova DNS UDP/TCP, AA, paridade, AXFR bloqueado e HTTPS pelo IP público real.

## Reboot

Depois de local+externa PASS, faça reboot controlado de um nó por vez. Repita local+externa. Nenhum serviço de produção pode depender de `/run` manual, processo órfão ou comando pós-boot não versionado.

Somente a combinação `LOCAL PASS + EXTERNAL PASS + REBOOT PASS` permite registrar `TPS_CANONICAL=PASS`.
