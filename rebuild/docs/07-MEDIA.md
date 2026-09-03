# Media Fabric

## MediaMTX

A instalação fixa versão e SHA-256. O serviço roda como `tpsmedia`. Endpoints administrativos ficam em loopback. O usuário externo de publish vem de `/etc/tps-secrets/media/publish.env`; playout local publica por loopback sem senha e não ganha permissão remota.

## Nove estações

Rádio: `radio-main`, `radio-pop`, `radio-rock`, `radio-classicas`, `radio-country`.

TV: `tvkids-main`, `tvteens-main`, `tvviva-main`, `tvmaisjovem-main`.

Derivado: `tv-main` para RadioTV; não conta como estação independente.

## Repositório

CAS físico em `objects/sha256`; refs por canal; playlist ffconcat gerada somente de refs existentes. A migração de conteúdo é separada do runtime.

## Rádio

Engine transcodifica áudio para AAC 128 kb/s, 44.1 kHz stereo e loudnorm. Ative um canal de cada vez e valide API/HLS antes do seguinte.

## TV

A engine base usa `-c copy`; portanto os assets devem ser previamente normalizados H264+AAC. Isso evita transcodificação 24x7 desnecessária em instância Free Tier. Quando ABR 720/480/360 for necessário, ele deve ser um gate de capacidade separado.
