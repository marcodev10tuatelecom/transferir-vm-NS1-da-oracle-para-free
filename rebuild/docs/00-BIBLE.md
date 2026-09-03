# Bíblia de Reconstrução TPS — NS1 + NS2

## 1. Propósito

Reconstruir dois servidores autoritativos/edge a partir de Ubuntu 22.04 LTS limpo em outra conta ou outra nuvem, preservando o desenho funcional e eliminando dívidas históricas.

A Bíblia não copia defeitos observados no ambiente antigo. Ela separa recuperação forense de implantação canônica.

## 2. Resultado final esperado

### NS1

- hostname lógico `tuatelecom01`;
- identidade pública `ns1.tpsolutions.com.br`;
- BIND authoritative primary/writer;
- Nginx :80/:443;
- Certbot webroot + timer único;
- MediaMTX sob `tps-mediamtx.service`;
- RTMP ingest;
- HLS/WebRTC atrás de Nginx;
- repositório de mídia em `/srv/tpsmedia/repository`;
- serviços de playout autorizados;
- observabilidade e backup.

### NS2

- hostname lógico `tuatelecom02`;
- identidade pública `ns2.tpsolutions.com.br`;
- BIND authoritative secondary read-only;
- transferência de zonas autenticada por TSIG;
- Nginx/TLS;
- MediaMTX sob a mesma unidade canônica;
- Edge2/failover ativado somente depois de validação.

## 3. Fronteiras

A nuvem fornece VM, VPC/VCN/VNet, subnet, IP público/privado, firewall externo, rota e console de recuperação. Ubuntu fornece a camada de serviço. O projeto não transforma política interna de um provedor em dependência arquitetural.

## 4. Fonte de verdade

A nova árvore é declarativa e versionada. Arquivos antigos em `/etc/studiosat`, `/etc/mediamtx`, `/srv/tpsmedia/content`, `/srv/tpsmedia/filler` ou unidades históricas não são recriados automaticamente.

## 5. Segurança

Nunca versionar:

- TSIG;
- SSH private keys;
- ACME account private key;
- certificados private key;
- publisher password/token;
- OCI/AWS/GCP/Azure credentials;
- banco de dados secrets.

Todos os scripts recusam placeholders críticos.

## 6. Contas

- `root`: break-glass/local; login SSH remoto deve terminar desabilitado.
- `marco`: autoridade administrativa humana.
- `adminfra`: identidade operacional quando necessária.
- `tpsmedia`: daemon MediaMTX, `nologin`.
- `tps-playout`: execução de playout, `nologin`.

Contas padrão do provedor (`ubuntu`, `opc` etc.) só são aposentadas depois de comprovar acesso alternativo.

## 7. Rede

Contrato público mínimo:

- TCP/UDP 53: DNS authoritative;
- TCP 80: ACME/redirect/health;
- TCP 443: sites, HLS, WHEP/WebRTC signaling;
- TCP 22: somente CIDR administrativo;
- TCP 1935: ingest RTMP quando necessário;
- UDP 8189: ICE WebRTC quando necessário;
- UDP 8890: SRT somente se explicitamente ativado.

Internos/loopback:

- 8554 RTSP;
- 8888 HLS origin;
- 8889 WebRTC HTTP signaling;
- 9997 API;
- 9998 metrics.

## 8. DNS

NS1 mantém os arquivos primários. NS2 nunca recebe arquivo de zona por cópia manual como autoridade de produção; recebe por AXFR/IXFR autenticado. `allow-transfer` público permanece negado.

`tpsolutions.com.br` começa com a política DNSSEC definida no inventário. `studiosatweb.com.br` usa `dnssec-policy default`/inline signing somente depois de o gate DNS local passar. Publicação/alteração de DS no pai é um gate externo separado.

## 9. TLS

Store único: `/etc/letsencrypt`. Método padrão: webroot `/var/lib/tpsmedia/acme`. Nginx continua no ar durante emissão/renovação. `certbot.timer` é a única autoridade de agenda. Deploy hook só recarrega Nginx se `nginx -t` passar.

Lineages esperadas são derivadas dos FQDNs realmente publicados. Não emitir certificado para nome que não resolve para o novo edge.

## 10. MediaMTX

Versão alvo inicial: `v1.20.1`, fixada por inventário e SHA-256 obrigatório. Binário em `/opt/tpsmedia/mediamtx/releases/<version>/mediamtx`, symlink `current`, config `/etc/tpsmedia/mediamtx/mediamtx.yml`, runtime `/var/lib/tpsmedia/mediamtx`.

Paths de reconstrução inicial:

- `radio-main`
- `radio-pop`
- `radio-rock`
- `radio-classicas`
- `radio-country`
- `tvkids-main`
- `tvteens-main`
- `tvviva-main`
- `tvmaisjovem-main`

RadioTV é produto derivado e não conta como décima emissora.

## 11. Repositório

Raiz física única: `/srv/tpsmedia/repository`. Conteúdo é validado por `ffprobe` e SHA-256 antes de virar referência de canal. O repositório não é apagado em rollback de configuração.

## 12. Ordem obrigatória

R00 inventário/nuvem -> R01 bootstrap -> R02 identidade -> R03 firewall -> R04 DNS -> R05 Nginx -> R06 TLS -> R07 MediaMTX -> R08 repositório/playout -> R09 observabilidade/backup -> R10 reboot/certificação -> R11 cutover público.

## 13. Critério de interrupção

Parar imediatamente se ocorrer:

- placeholder `CHANGE_ME` crítico;
- hostname/role divergente;
- `named-checkconf`/`named-checkzone` fail;
- `nginx -t` fail;
- hash de binário fail;
- unidade crítica failed/orphan;
- porta ocupada por autoridade não prevista;
- DNS secondary sem SOA parity;
- AXFR público permitido;
- TLS/SNI inválido;
- MediaMTX API/HLS não responder;
- reboot alterar desired state.

## 14. Cutover

Nunca alterar NS/DS/A públicos antes de a nova dupla responder localmente e por seus IPs públicos. O cutover é reversível enquanto a infraestrutura antiga permanecer íntegra. Diminuir TTL, quando necessário, é mudança DNS independente e deve ser planejada antes.

## 15. Definition of Done

`TPS_CANONICAL=PASS` exige: zero failed críticos, zero processo órfão, DNS AA UDP/TCP nos dois nós, SOA parity, AXFR público bloqueado, Nginx/TLS PASS, uma autoridade ACME, um MediaMTX por nó, streams designados testados, backup produzido, restore testado e reboot sem intervenção manual.
