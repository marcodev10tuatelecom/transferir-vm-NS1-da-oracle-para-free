# Inputs que não pertencem ao código

Este projeto é completo como **mecanismo de reconstrução**, mas certos bytes precisam vir do ambiente/negócio:

1. IPs e CIDRs da nova nuvem.
2. SSH public key autorizada do administrador.
3. TSIG gerado para a nova dupla.
4. Email ACME.
5. Credencial de publisher criada fora do Git.
6. Arquivos unsigned das zonas DNS atuais.
7. Conteúdo audiovisual e playlists editoriais.
8. Regras do firewall da própria nuvem.
9. DS no registrador quando DNSSEC exigir mudança.
10. Decisão de quais FQDNs planejados já devem entrar em produção.

Scripts recusam inventar esses valores.
