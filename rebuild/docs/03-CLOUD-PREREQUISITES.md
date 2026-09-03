# Pré-requisitos da nova nuvem

Antes do Ubuntu:

1. Criar duas VMs em domínios de falha diferentes quando possível.
2. Reservar IPs públicos estáveis, quando o provedor oferecer.
3. Criar IPs privados estáveis.
4. Garantir console serial/rescue fora do SSH.
5. Não publicar DNS antes dos gates.
6. Abrir no firewall externo somente o contrato documentado.
7. Registrar snapshot/backup inicial da VM vazia.

## Requisito mínimo sugerido

- Ubuntu Server 22.04 LTS;
- 2+ vCPU por nó;
- 8+ GiB RAM quando o nó também executar mídia;
- disco suficiente para SO + logs + working set;
- NTP funcional.

Esses valores são baseline operacional, não equivalem a garantia de capacidade para transcodificação pesada.

## Valores que devem ser conhecidos

- `PUBLIC_IPV4` de cada nó;
- `PRIVATE_IPV4` de cada nó;
- CIDR privado entre os nós;
- interface principal;
- CIDR administrativo SSH;
- email ACME;
- provider firewall/NSG/security group aplicado.
