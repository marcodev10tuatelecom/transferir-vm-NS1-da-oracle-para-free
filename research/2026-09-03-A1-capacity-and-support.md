# A1 Always Free — capacidade, recriação e suporte — 2026-09-03

## Hipótese levantada

Foi levantada a hipótese de que `OUT_OF_HOST_CAPACITY` seria uma mensagem apenas diplomática e que, depois de uma primeira utilização/reclamação de A1 Always Free, a recriação poderia na prática não voltar a funcionar.

## O que é comprovado oficialmente

1. A documentação atual da Oracle continua dizendo que recursos Always Free podem ser excluídos e reprovisionados conforme necessário depois do fim da avaliação. Não existe, na documentação pública consultada, uma regra oficial de “uso único” para A1 Always Free.
2. A Oracle documenta `OUT_OF_HOST_CAPACITY` como indisponibilidade de infraestrutura física para a shape/placement solicitado. O workaround oficial é usar `CreateComputeCapacityReport`, outro AD, shape menor/diferente ou aguardar e tentar novamente.
3. Para Free/Always Free A1, a Oracle chama a falta de host de temporária, mas não publica SLA nem prazo máximo para a capacidade voltar.

## Evidência externa relevante de 2026

Há relatos recentes que se parecem muito com o caso TPS:

- Cloud Customer Connect, 2026-03-23: usuário em `sa-saopaulo-1` relatou mais de 3 dias e mais de 1000 tentativas de criar `VM.Standard.A1.Flex`, tanto com configuração maior quanto com 1 OCPU/6 GB, sempre recebendo `Out of host capacity`.
- Cloud Customer Connect, agosto de 2026: vários usuários relataram instâncias Always Free A1 desabilitadas após a atualização dos limites e dificuldades para redimensionar/recriar; há relatos específicos de São Paulo.
- Reddit, julho/agosto de 2026: usuários com boot volume preservado após reclamation/termination relataram quota disponível porém falha recorrente por `Out of host capacity` ao tentar recriar A1.

Esses relatos são anedóticos e não provam política deliberada da Oracle. Eles mostram, porém, que o problema pode ser prolongado e estrutural em determinadas regiões/tenancies, e que “temporário” não deve ser interpretado operacionalmente como “alguns minutos”.

## Nova rota oficial de suporte descoberta

Release Note da Oracle de 2026-08-25 informa que o **Console AI Experience Preview** está disponível para clientes Free Tier e Always Free cuja home region é **São Paulo**. O recurso permite:

- troubleshooting;
- criar Service Requests (SRs);
- contactar agentes de suporte ao vivo.

Portanto, a premissa anterior de que esta tenancy Free não teria nenhum caminho de suporte humano precisa ser revisada. Existe agora um canal oficial recente via Console AI Preview, sujeito às limitações do piloto.

## Decisão operacional

- NÃO terminar `tuatelecom01` enquanto A1 estiver `OUT_OF_HOST_CAPACITY`.
- Manter o boot de 99 GB e o reserved IP `147.15.108.150` intactos.
- Continuar capacity reports para 2 OCPU/12 GB e 1 OCPU/6 GB.
- Em paralelo, abrir SR via Console AI solicitando análise dos erros contraditórios do backend (`ratio 0-0`, `Stopped ... expected Stopped`) e, preferencialmente, reabilitação/conversão da instância para A1 dentro de 2 OCPU/12 GB sem apagar o boot.
- Não fornecer senhas, chaves privadas, tokens ou PSKs ao Console AI.

## Fontes públicas consultadas

- Oracle — Always Free Resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Oracle — OCI Free Tier: https://docs.oracle.com/pt-br/iaas/Content/FreeTier/freetier.htm
- Oracle — Compute Known Issues / Out of host capacity: https://docs.oracle.com/en-us/iaas/Content/Compute/known-issues.htm
- Oracle — Console AI Preview, release 2026-08-25: https://docs.oracle.com/en-us/iaas/releasenotes/console/consoleai-preview-oc1-aug-2026.htm
- Oracle Customer Connect — São Paulo A1 out of capacity: https://community.oracle.com/CustomerConnect/discussion/949983/cannot-upgrade-free-tier-to-payg-a1-flex-out-of-capacity-in-sa-saopaulo-1-for-3-days
