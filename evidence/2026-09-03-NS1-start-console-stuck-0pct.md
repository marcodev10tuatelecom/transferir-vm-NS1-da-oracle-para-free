# Evidência — tentativa de iniciar `tuatelecom01` pela Console OCI

Data: 2026-09-03

Duas capturas enviadas pelo usuário mostram a Console OCI em **Computação -> Instâncias -> Iniciar instâncias**, para `tuatelecom01`, permanecendo em:

```text
0%
Enviando a solicitação
Processando...
```

As capturas foram feitas em momentos consecutivos e não mostram conclusão, erro ou mudança de lifecycle state.

## Interpretação permitida pela evidência

A interface gráfica estava parada em `0% / Enviando a solicitação` no momento das capturas.

## O que NÃO pode ser concluído apenas pela tela

- não é possível afirmar que a API de START foi aceita;
- não é possível afirmar que a instância mudou para STARTING;
- não é possível afirmar que a instância permaneceu STOPPED;
- não é possível afirmar que houve erro de backend.

A próxima verificação deve ser read-only via OCI CLI, consultando diretamente o lifecycle state da instância antes de repetir qualquer ação START.
