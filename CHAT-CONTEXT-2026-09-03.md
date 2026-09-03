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

## 11. Estado de segurança no fim desta conversa arquivada

No último estado comprovado antes do pedido de arquivamento:

- NS1 A2 ainda não havia sido comprovadamente terminada.
- Boot NS1 continuava existente, 99 GB, Free Tier retained.
- Attachment era observado como `ATTACHED`.
- NS2 não tinha sido alterado.
- IP reservado `147.15.108.150` estava disponível e não associado.
- A1 quota continuava livre (2 OCPU / 12 GB antes de qualquer lançamento A1).

## 12. Próxima ação preparada

Foi criado `TPS-OCI-NS1-FINAL-PRETERMINATION-GATE-v1.0.0.sh` para revalidar:

- lifecycle real da instância;
- estado real do attachment após o `Ctrl+C` e o erro `IncorrectState`;
- integridade/free-tier do boot;
- estado do reserved IP;
- quota A1;
- relatório de capacidade física A1 2 OCPU / 12 GB.

A decisão planejada era só construir o cutover destrutivo `terminate --preserve-boot-volume true -> launch A1` depois desse gate.

## 13. Princípios adotados

- Free-only: não converter a conta para paga como atalho.
- Não apagar boot volumes.
- Não duplicar 99 GB de NS1, pois armazenamento total já é 178/200 GB.
- Fail-closed em qualquer divergência de estado.
- NS1 primeiro; NS2 somente depois de NS1 certificado.
- Preservar evidências de todas as tentativas falhas.
- Não tratar mensagem contraditória da OCI como sucesso.
