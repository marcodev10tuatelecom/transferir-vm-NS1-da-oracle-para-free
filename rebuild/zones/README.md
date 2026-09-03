# Arquivos de zona são dados, não código

Para reconstrução fiel, exporte do NS1 atual os **arquivos unsigned primários** e coloque-os, fora do Git, em `/root/tps-rebuild/zones`:

- `db.tpsolutions.com.br`
- `db.studiosatweb.com.br`
- outros `db.<zona>` somente se a zona estiver formalmente ativa.

Antes do cutover, atualize nos arquivos de zona somente os registros que realmente mudam (por exemplo A de ns1/ns2 e edges). Incremente o SOA serial. O script recusa zona ausente ou inválida.

Não use `.signed` ou `.jnl` como source of truth de migração.
