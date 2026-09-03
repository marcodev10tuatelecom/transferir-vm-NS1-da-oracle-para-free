# transferir-vm-NS1-da-oracle-para-free

Arquivo técnico da recuperação/migração das instâncias Oracle OCI `tuatelecom01` (NS1) e `tuatelecom02` (NS2), realizado em 2026-09-03.

## Objetivo

Migrar a infraestrutura que foi criada em `VM.Standard.A2.Flex` durante a promoção OCI para recursos **Always Free**, preservando dados e mantendo o serviço dentro dos limites gratuitos da tenancy.

## Estado comprovado no momento deste arquivo

- Tenancy: **Camada Gratuita / Promoção**, criada em 2026-07-06.
- `tuatelecom01`: `STOPPED`, `VM.Standard.A2.Flex`, 2 OCPU / 12 GB.
- `tuatelecom02`: `STOPPED`, `VM.Standard.A2.Flex`, 2 OCPU / 12 GB.
- Quota A1 disponível: **2 OCPU / 12 GB** no AD-1 e regional.
- Boot volume NS1: **99 GB**, `free-tier-retained=true`.
- Boot volume NS2: **79 GB**, `free-tier-retained=true`.
- Armazenamento total: **178 GB / 200 GB Always Free**, 22 GB livres.
- Conversão direta `A2 -> A1` foi rejeitada pelo backend com `Invalid ratio of memory in GB to OCPUs ... Valid ratio range: 0 - 0`.
- IP público antigo NS1 `147.15.120.115`: **EPHEMERAL**, não pode ser transferido.
- IP privado antigo NS1 `10.0.0.17`: **EPHEMERAL**.
- Novo IP público reservado criado: **147.15.108.150**, `RESERVED`, `AVAILABLE`, ainda não associado no último estado comprovado.
- Tentativa de `boot-volume-attachment detach` recebeu `IncorrectState` apesar de a instância estar `STOPPED`; nenhum detach foi comprovado.
- Tentativa de `instance terminate` com `--wait-for-state TERMINATED` não chamou a API porque `TERMINATED` não é estado válido do Work Request nesse comando.

## Regra operacional atual

**NÃO executar scripts antigos de migração sem revisar o estado atual.** Em particular, os scripts abaixo são preservados como histórico e podem conter hipóteses que já foram invalidadas pela evidência posterior.

### Histórico de scripts

- `TPS-OCI-FREE-RECOVERY-RX-v1.0.0.sh` — diagnóstico read-only; útil.
- `TPS-OCI-A2-TO-A1-ONE-NODE-CUTOVER-v1.0.0.sh` — tentativa de resize; falhou no backend; histórico.
- `TPS-OCI-NS1-A1-EMERGENCY-RECOVERY-v1.1.0.sh` — histórico; contém consulta de storage posteriormente corrigida.
- `TPS-OCI-NS1-A1-EMERGENCY-RECOVERY-v1.1.1.sh` — resize A2->A1 ainda falhou com ratio `0-0`; histórico.
- `TPS-OCI-NS1-REPLACEMENT-GATE-RX-v1.0.0.sh` — diagnóstico read-only; confirmou IP EPHEMERAL.
- `TPS-OCI-NS1-RESERVED-PUBLIC-IP-PREP-v1.0.0.sh` — criou `147.15.108.150` RESERVED.
- `TPS-OCI-NS1-A1-BOOT-CUTOVER-v1.0.0.sh` — **OBSOLETO / NÃO EXECUTAR**: pressupunha detach de boot funcional e formato convencional do attachment OCID.
- `TPS-OCI-NS1-FINAL-PRETERMINATION-GATE-v1.0.0.sh` — gate de diagnóstico/capacidade preparado depois das evidências de detach/terminate.

## Estrutura

- `scripts/` — todos os scripts e checksums gerados nesta conversa.
- `archive/` — textos/logs extensos colados/exportados durante a investigação.
- `evidence/screenshots/` — manifesto de todas as capturas de tela recebidas.
- `evidence/screenshots-20260903.zip.part-*` — arquivo ZIP das capturas, dividido em partes para transporte via conector.
- `CHAT-CONTEXT-2026-09-03.md` — consolidação cronológica dos fatos técnicos e decisões.
- `MANIFEST-SHA256.txt` — hashes dos arquivos preservados.

## Atenção

Este repositório é **público** no GitHub e contém identificadores técnicos de infraestrutura (OCIDs e endereços IP) porque o pedido foi preservar o conteúdo da investigação. Não adicionar senhas, chaves privadas, tokens, PSKs ou outros segredos.
