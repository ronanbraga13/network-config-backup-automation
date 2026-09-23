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

## 2. Configurar Oxidized

```bash
sudo bash scripts/02-configure-oxidized.sh
```

O script solicita:

- usuário padrão dos devices;
- senha;
- nome do primeiro node;
- IP de gerenciamento;
- model Oxidized;
- input (`ssh` ou `telnet`);
- intervalo de coleta.

## 3. Inventário

Formato:

```text
NAME:IP:MODEL:INPUT
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

## 6. Validar Git

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  log --oneline --all
```

## 7. Próximos passos

- adicionar os demais nodes;
- validar coleta de cada model;
- testar diff;
- testar recuperação;
- definir retenção;
- monitorar disco;
- proteger Web UI;
- substituir Telnet legado por SSH sempre que possível.
