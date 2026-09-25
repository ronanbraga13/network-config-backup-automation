# Quick Start

> Exemplo para laboratório. Revise segurança, credenciais, HTTPS, modelo de acesso e hardening antes de qualquer uso produtivo.

## 1. Preparar Ubuntu

Requisito validado:

```text
Ubuntu Server 22.04 LTS ou superior
```

Execute:

```bash
sudo bash scripts/01-install-oxidized.sh
```

## 2. Escolher o modelo de configuração

Após o `01-install-oxidized.sh`, escolha apenas um dos fluxos:

### Host + Git

```bash
sudo bash scripts/02-configure-oxidized.sh
```

### Grupos + arquivos

```bash
sudo bash scripts/03-configure-oxidized-groups-files.sh
```

### Grupos + Git + arquivos

```bash
sudo bash scripts/04-configure-oxidized-groups-git-and-files.sh
```

O fluxo `01 -> 04` é suportado diretamente; não é necessário executar `02` ou `03` antes do `04`.

## 3. Inventário

Formato base por host:

```text
NAME:IP:MODEL:INPUT
```

Nos modos por grupo (`03` e `04`):

```text
NAME:IP:MODEL:INPUT:GROUP
```

Exemplo:

```text
FGT-SITE-A:10.0.20.1:fortigate:ssh
PFSENSE-SITE-B:10.20.20.1:pfsense:ssh
SW-SITE-B:10.20.20.10:ios:telnet
```

Arquivo:

```text
/home/oxidized/.config/oxidized/router.db
```

Após alterações, use a função de reload da Web UI ou reinicie o serviço quando apropriado.

## 4. Validar serviço

```bash
systemctl status oxidized --no-pager
journalctl -u oxidized -n 50 --no-pager
```

## 5. Web UI

```text
http://SERVER_IP:8888
```

No LAB a interface foi publicada diretamente em TCP/8888.

> Em produção, use controles de acesso e HTTPS/reverse proxy conforme o padrão da organização.


## 6. Arquivos de backup atuais

No modo **Grupos + Git + arquivos**, os backups atuais ficam em:

```text
/home/oxidized/.config/oxidized/configs/
```

Listar:

```bash
find /home/oxidized/.config/oxidized/configs -maxdepth 2 -type f
```

Exemplo:

```text
/home/oxidized/.config/oxidized/configs/GRP_RIO/SW-RIO-01
```

Para copiar um backup para sua máquina local via SCP:

```bash
scp usuario@IP_DO_SERVIDOR:/home/oxidized/.config/oxidized/configs/GRP_RIO/SW-RIO-01 .
```

Para copiar um grupo inteiro:

```bash
scp -r usuario@IP_DO_SERVIDOR:/home/oxidized/.config/oxidized/configs/GRP_RIO .
```

No Windows, o mesmo caminho pode ser acessado via WinSCP.


## 7. Validar Git

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  log --oneline --all
```

## 8. Atenção com FortiGate

A coleta do FortiGate respeita as permissões da conta administrativa usada pelo Oxidized. No LAB, uma conta restrita não apresentou todos os administradores em `show system admin`.

Para uso como backup completo de recuperação:

- valide a visibilidade da conta;
- aplique o princípio de menor privilégio compatível com o objetivo;
- restrinja origem/trusted hosts quando aplicável;
- faça teste real de restore antes de produção.

O restore do pfSense foi validado no LAB. Outros vendors devem ser testados individualmente.

## 9. Próximos passos

- adicionar os demais nodes;
- validar coleta de cada model;
- testar diff;
- testar recuperação;
- definir retenção;
- monitorar disco;
- proteger Web UI;
- substituir Telnet legado por SSH sempre que possível.
