# Contexto técnico da conversa — OCI Free recovery — 2026-09-03

## 1. Incidente

As instâncias Oracle OCI `tuatelecom01` e `tuatelecom02`, usadas como NS1/Edge1 e NS2/Edge2 da infraestrutura TPS/StudioSat, apareceram como **Interrompidas/STOPPED** depois do período inicial da conta OCI.

A investigação partiu da hipótese de regras do OCI Free Tier e evoluiu usando a Console OCI e a OCI CLI no Cloud Shell.

## 2. Conta OCI

A Console comprovou:

- Plano: **Camada Gratuita**.
- Tipo de conta: **Promoção**.
- Data inicial: **6 de julho de 2026**.
- Não convertida para Pay As You Go no momento da investigação.

As VMs foram encontradas como `VM.Standard.A2.Flex`, que não estavam marcadas no Resource Search como `free-tier-retained`, enquanto seus boot volumes estavam.

## 3. Recursos Compute

### NS1 — tuatelecom01

- Estado: `STOPPED`.
- Shape: `VM.Standard.A2.Flex`.
- OCPU: 2.
- RAM: 12 GB.
- AD: `PjZm:SA-SAOPAULO-1-AD-1`.
- Fault Domain: `FAULT-DOMAIN-1`.
- IP privado original: `10.0.0.17`.
- IP público original: `147.15.120.115`.
- IP público original: `EPHEMERAL`.
- Boot volume: 99 GB.
- Boot volume: `free-tier-retained=true`.

### NS2 — tuatelecom02

- Estado: `STOPPED`.
- Shape: `VM.Standard.A2.Flex`.
- OCPU: 2.
- RAM: 12 GB.
- IP privado original: `10.0.0.162`.
- IP público original: `163.176.252.248`.
- Boot volume: 79 GB.
- Boot volume: `free-tier-retained=true`.

## 4. Limites Always Free comprovados

Na Console e depois via CLI:

- `standard-a1-core-count`: disponível 2.
- `standard-a1-memory-count`: disponível 12 GB.
- `standard-a1-core-regional-count`: disponível 2.
- `standard-a1-memory-regional-count`: disponível 12 GB.

Armazenamento Block/Boot:

- Usado: 178 GB.
- Disponível: 22 GB.
- Referência Always Free: 200 GB.

Conclusão: os dois boot volumes existentes cabem juntos no limite gratuito: `99 + 79 = 178 GB`.

## 5. Compatibilidade A1/A2

A imagem Ubuntu ARM usada pelas VMs apareceu como compatível com:

- `VM.Standard.A1.Flex`
- `VM.Standard.A2.Flex`

A OCI CLI também retornou `resize-compatible-shapes` contendo A1 e A2 em ambos os sentidos.

## 6. Falha do resize direto

Foram testadas duas estratégias de `UpdateInstance`:

1. A2 -> A1 com `shape-config` explícito.
2. A2 -> A1 sem `shape-config`, para usar o default da shape de destino.

Ambas falharam com HTTP 400:

```text
Invalid ratio of memory in GB to OCPUs. Current ratio: 6.0. Valid ratio range: 0 - 0
```

A partir daí, o resize da mesma instância foi abandonado como caminho operacional.

## 7. Rede e IP reservado

A análise do objeto de IP confirmou:

```text
PUBLIC_IP=147.15.120.115
PUBLIC_IP_LIFETIME=EPHEMERAL
SAME_PUBLIC_IP_REASSIGNMENT_AFTER_INSTANCE_REPLACEMENT=IMPOSSIBLE
```

Foi criado um novo IP público reservado:

```text
RESERVED_PUBLIC_IP=147.15.108.150
LIFETIME=RESERVED
STATE=AVAILABLE
SCOPE=REGION
ASSIGNED_ENTITY_ID=UNASSIGNED
```

Nenhuma VNIC ou instância foi alterada durante a criação desse IP reservado.

## 8. Particularidade do boot-volume attachment

A listagem real do attachment do NS1 retornou:

```text
"display-name": "Remote boot attachment for instance"
"id": <o mesmo OCID da instance tuatelecom01>
"instance-id": <o mesmo OCID da instance tuatelecom01>
"lifecycle-state": "ATTACHED"
```

O `get` aceitou esse OCID e retornou o attachment corretamente. Portanto, neste caso concreto, não se deve pressupor que o ID terá prefixo `ocid1.bootvolumeattachment...`.

## 9. Tentativa de detach

Foi executado:

```bash
oci compute boot-volume-attachment detach \
  --boot-volume-attachment-id "$OLD_INSTANCE" \
  --force \
  --wait-for-state DETACHED \
  --max-wait-seconds 600 \
  --region "$REGION"
```

Uma primeira tentativa foi interrompida com `Ctrl+C`. Em seguida uma nova tentativa retornou:

```text
IncorrectState
Instance ... is in Stopped state, when it was expected to be in Stopped state
```

A mensagem é contraditória. Não foi comprovado detach do boot volume. O estado observado continuava `ATTACHED`.

## 10. Tentativa de terminate

Foi digitado um comando com:

```text
--wait-for-state TERMINATED
```

A própria OCI CLI rejeitou localmente:

```text
Invalid value for '--wait-for-state': invalid choice: TERMINATED.
(choose from ACCEPTED, IN_PROGRESS, FAILED, SUCCEEDED)
```

Logo essa tentativa **não terminou a instância**.

O procedimento futuro deve distinguir o estado do Work Request (`SUCCEEDED`) do lifecycle state da instância (`TERMINATED`) e verificar ambos separadamente.

## 11. Gate final de pré-terminação — resultado de 2026-09-03

O script `TPS-OCI-NS1-FINAL-PRETERMINATION-GATE-v1.0.0.sh` foi executado e confirmou:

```text
INSTANCE.state = STOPPED
INSTANCE.shape = VM.Standard.A2.Flex
BOOT_ATTACHMENT.state = ATTACHED
BOOT_VOLUME.state = AVAILABLE
BOOT_VOLUME.size = 99
BOOT_VOLUME.free = true
RESERVED_IP = 147.15.108.150
RESERVED_IP.lifetime = RESERVED
RESERVED_IP.state = AVAILABLE
RESERVED_IP.assigned = null
A1_CORE.used = 0
A1_CORE.available = 2
A1_MEMORY.used = 0
A1_MEMORY.available = 12
```

O relatório oficial de capacidade física da OCI para `VM.Standard.A1.Flex` com **2 OCPU / 12 GB** retornou:

```text
availability-status = OUT_OF_HOST_CAPACITY
available-count = null
fault-domain = null
```

### Decisão obrigatória

**NÃO TERMINAR `tuatelecom01` enquanto o capacity report continuar `OUT_OF_HOST_CAPACITY`.**

A quota Free existe, mas atualmente não há capacidade física A1 confirmada no AD para recriar NS1. Terminar a A2 agora liberaria seu IP efêmero antigo e deixaria apenas o boot preservado, sem garantia de conseguir lançar a A1 imediatamente.

A documentação da Oracle define `OUT_OF_HOST_CAPACITY` como indisponibilidade de capacidade física da shape e recomenda aguardar e tentar novamente (ou usar outro AD, quando aplicável).

## 12. Estado de segurança atual

- NS1 A2: `STOPPED`, não terminada.
- Boot NS1: 99 GB, existente e `free-tier-retained=true`.
- Attachment NS1: `ATTACHED`.
- NS2: não alterado.
- IP reservado novo: `147.15.108.150`, `AVAILABLE`, não associado.
- Quota A1: 2 OCPU / 12 GB livres.
- Capacidade física A1 2/12: **OUT_OF_HOST_CAPACITY**.

## 13. Próxima ação correta

Repetir apenas o capacity report até o resultado mudar para `AVAILABLE`. Também é útil testar separadamente a capacidade para **1 OCPU / 6 GB**, porque pode haver capacidade para uma configuração menor mesmo quando 2/12 não está disponível.

Nenhum `terminate`, `detach`, `launch` ou alteração de DNS deve ocorrer antes dessa decisão.

## 14. Princípios adotados

- Free-only: não converter a conta para paga como atalho.
- Não apagar boot volumes.
- Não duplicar 99 GB de NS1, pois armazenamento total já é 178/200 GB.
- Fail-closed em qualquer divergência de estado.
- NS1 primeiro; NS2 somente depois de NS1 certificado.
- Preservar evidências de todas as tentativas falhas.
- Não tratar mensagem contraditória da OCI como sucesso.
- Não destruir a A2 enquanto a capacidade física A1 não estiver comprovadamente disponível.
