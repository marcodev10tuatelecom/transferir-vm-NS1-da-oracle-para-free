# Backup e Restore

`19-backup.sh` cria um pacote root-only contendo configuração e segredos necessários para recuperação. Por conter private keys/TSIG, ele **não** pode ir para Git público.

Validação em três níveis:

1. hash e `tar -t` no nó;
2. cópia off-node criptografada e hash conferido;
3. restore em VM isolada, seguida de `named-checkconf -z`, `nginx -t`, MediaMTX config test e certificação funcional.

Backup presente não equivale a restore comprovado.
