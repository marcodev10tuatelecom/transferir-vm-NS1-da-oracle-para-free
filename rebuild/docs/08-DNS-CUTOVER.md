# DNS / DNSSEC / Cutover

1. Construa NS1 e NS2 sem mudar delegação.
2. Teste `dig @IP_NOVO` UDP e TCP externamente.
3. Confirme AA e SOA parity.
4. Confirme AXFR público negado.
5. Confirme TSIG/XFR privado.
6. Para zona assinada, confira DNSKEY/RRSIG local.
7. Só então atualize glue/endereço de nameserver no registrador quando necessário.
8. Só publique/altere DS depois de a cadeia nova estar validada.
9. Não confunda regra operacional do registrador com dependência arquitetural do servidor.

Se DNSSEC estiver ativo durante mudança de chave, trate rollover/DS como projeto separado; não gere uma nova chave e troque DS no mesmo instante sem janela de propagação comprovada.
