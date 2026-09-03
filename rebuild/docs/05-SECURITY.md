# Segurança

## Git público

Este repositório pode conter topologia e exemplos, mas não segredos. `.gitignore` cobre extensões usuais; a regra operacional é mais forte que o ignore.

## SSH

Não desligar conta inicial do provedor antes de testar `marco` em uma segunda sessão e confirmar console de recuperação. Estado final: `PasswordAuthentication no`, `PermitRootLogin no`, chave pública para autoridade humana.

## Firewall

Há duas camadas: firewall cloud e firewall guest. Uma não substitui a outra. O script guest não consegue provar NSG/security-list externos.

## DNS

- recursion off;
- transfer default deny;
- TSIG para XFR;
- API RNDC local;
- DS só muda após validação.

## Media

- administração/API/metrics em loopback;
- ingest autenticação deve ser ativada antes de exposição ampla;
- tokens não entram no YAML versionado;
- preferir arquivo de segredo root-readable ou mecanismo do provedor.
