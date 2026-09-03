# Organização no GitHub Project

O GitHub Project nº 2 deve acompanhar execução; este repositório guarda a verdade técnica.

## Colunas/status sugeridos

- Backlog
- Ready
- In progress
- Validation
- Blocked
- Done

## Campos sugeridos

- Gate: R00..R11
- Node: NS1 / NS2 / BOTH / EXTERNAL
- Risk: P0 / P1 / P2
- Evidence: link para commit/issue/pacote
- Result: PASS / FAIL / BLOCKED / EXPECTED_DISABLED

## Regra

Uma issue por gate. Fechar somente com evidência e critérios de aceite preenchidos. PRs alteram código; issues registram execução. Não usar comentário de issue como armazenamento de segredo.
