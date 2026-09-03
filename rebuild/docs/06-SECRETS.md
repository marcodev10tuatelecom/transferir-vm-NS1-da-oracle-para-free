# Segredos

Diretório runtime recomendado: `/etc/tps-secrets`, owner `root:root`, modo `0700`.

Arquivos possíveis:

- `/etc/tps-secrets/dns/tpsolutions-ns1-ns2.key` — TSIG compartilhado NS1/NS2;
- `/etc/tps-secrets/media/publish.env` — credenciais de publish quando ativadas;
- material ACME é gerenciado pelo Certbot em `/etc/letsencrypt`.

Nunca copiar esses arquivos para este Git. Para TSIG, gere em NS1 com `tsig-keygen -a hmac-sha256 tpsolutions-ns1-ns2` e transfira ao NS2 por canal administrativo seguro. Compare SHA-256 dos arquivos nos dois nós sem imprimir o conteúdo.
