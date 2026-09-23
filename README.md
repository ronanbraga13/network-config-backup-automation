# Network Config Backup Automation

> **PT-BR:** Projeto de laboratório para backup centralizado, versionamento, comparação e restauração de configurações de rede multi-vendor usando **Oxidized, Git e Linux**.  
> **EN:** Lab project for centralized multi-vendor network configuration backup, versioning, comparison and restore using **Oxidized, Git and Linux**.

## Visão geral | Overview

Este projeto foi construído em **PNETLab** para validar uma arquitetura centralizada de backup de configurações de rede, com histórico de versões em Git, interface Web, coleta automática e sob demanda, além de testes práticos de restauração.

This project was built in **PNETLab** to validate a centralized network configuration backup architecture with Git-based version history, Web UI, automatic and on-demand collection, and practical restore testing.

### Vendors e plataformas validados | Validated vendors and platforms

- **Fortinet FortiGate**
- **Cisco IOS** — switches e routers / switches and routers
- **pfSense**
- **Ubuntu Server 22.04.5 LTS**
- **Oxidized 0.37.0**
- **oxidized-web 0.18.1**
- **Git local**

A arquitetura é extensível a outros **firewalls, switches, routers e dispositivos de rede suportados pelo Oxidized**.

The architecture can be extended to other **firewalls, switches, routers and network devices supported by Oxidized**.

## Objetivos | Goals

- Centralizar backups de configurações de rede.
- Manter histórico e rastreabilidade por Git.
- Comparar alterações entre versões.
- Permitir coleta automática e manual.
- Suportar diferentes vendors e protocolos por equipamento.
- Validar procedimentos reais de restauração.
- Criar uma base simples para futura automação, retenção e integração com storage externo.

## Arquitetura validada | Validated architecture

```text
Network Devices
   |
   |-- SSH / Telnet (lab legacy images)
   v
Ubuntu Server + Oxidized
   |
   |-- Git local
   |-- Web UI :8888
   |-- Automatic collection
   |-- On-demand collection
   |-- Version history / Diff
   `-- Restore workflow
```

O ambiente final do LAB possui **7 nodes** gerenciados pelo Oxidized em uma topologia multi-site:

| Node role | Vendor / Model | Input |
|---|---|---|
| Firewall - Matriz | FortiGate | SSH |
| Firewall - Rio | FortiGate | SSH |
| Firewall - MG | pfSense | SSH |
| Switch - Rio | Cisco IOS | Telnet* |
| Switch - MG | Cisco IOS | Telnet* |
| Router - Claro | Cisco IOS | Telnet* |
| Router - Vivo | Cisco IOS | Telnet* |

* Telnet foi utilizado somente por limitação das imagens Cisco IOL antigas disponíveis no PNETLab. Em produção, o padrão recomendado é **SSH**.

## Estrutura do Oxidized

Principais caminhos utilizados no servidor:

```text
/home/oxidized/.config/oxidized/
├── config
├── router.db
└── oxidized.git
```

- `config`: configuração principal do Oxidized.
- `router.db`: inventário dos equipamentos.
- `oxidized.git`: repositório Git bare com configurações e histórico de versões.

Exemplo do inventário multi-vendor:

```text
DEVICE-NAME:MANAGEMENT-IP:model:input
```

Exemplos de modelos usados no LAB:

```text
fortigate:ssh
pfsense:ssh
ios:telnet
```

## Coleta e versionamento | Collection and versioning

A periodicidade é controlada pelo parâmetro `interval`:

```yaml
interval: 86400
```

No LAB, isso representa uma coleta a cada **24 horas**.

O Git local permite:

- histórico de versões;
- diff entre coletas;
- recuperação de uma versão específica;
- auditoria de alterações;
- exportação da configuração atual via CLI.

Exemplo:

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  ls-tree -r --name-only HEAD
```

## Interface Web

A interface Web do Oxidized foi validada para:

- visualizar nodes;
- consultar status;
- executar coleta manual;
- consultar histórico;
- comparar versões;
- abrir a configuração coletada no navegador.

Porta utilizada no LAB:

```text
TCP/8888
```

> Em produção, a publicação da interface deve ser protegida por controles corporativos adequados, preferencialmente HTTPS e controle de acesso.

## Restore validado | Validated restore

### FortiGate

O conteúdo coletado pelo Oxidized foi exportado para `.conf`, ajustado para manter apenas o cabeçalho compatível com o FortiOS e utilizado com sucesso em um teste de restauração no ambiente de laboratório.

### pfSense

A configuração coletada pelo Oxidized foi apresentada em **XML** pela interface Web.

Procedimento validado:

1. Abrir a versão desejada na Web UI do Oxidized.
2. Usar **Ctrl + S** no navegador.
3. Salvar o arquivo com extensão `.xml`.
4. Utilizar o XML no processo de restore do pfSense.

Após o restore, o pfSense carregou a configuração e iniciou a reinstalação dos packages em segundo plano.

## Troubleshooting relevante | Key troubleshooting

### MTU no PNETLab

Durante o LAB, sessões SSH para FortiGate conectavam, mas comandos extensos podiam expirar. Testes de PMTU mostraram um limite efetivo inferior ao MTU padrão do Ubuntu.

Workaround validado no ambiente virtual:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
      mtu: 1496
```

Após tornar o MTU **1496** persistente via Netplan e reiniciar o servidor:

- o MTU permaneceu após reboot;
- o serviço Oxidized iniciou automaticamente;
- as coletas voltaram a funcionar.

> Esse ajuste é específico do cenário PNETLab testado e não deve ser tratado como requisito padrão de produção.

### Cisco IOL legado

Algumas imagens IOL do LAB não ofereciam suporte SSH adequado ou exigiam algoritmos criptográficos legados. Para não enfraquecer a configuração SSH do servidor Ubuntu, Telnet foi utilizado apenas nesses nodes de laboratório.

## Resultados | Results

- ✅ Servidor Oxidized operacional após reboot.
- ✅ Git local validado.
- ✅ Web UI validada.
- ✅ Coleta automática validada.
- ✅ Coleta sob demanda validada.
- ✅ Histórico e diff validados.
- ✅ 7 nodes em ambiente multi-site.
- ✅ FortiGate, Cisco IOS e pfSense integrados.
- ✅ SSH e input por node validados.
- ✅ Restore de FortiGate validado.
- ✅ Restore de pfSense via XML validado.
- ✅ Persistência do MTU do LAB validada.

## Próximas evoluções | Next steps

- Portal Web simplificado para cadastro de novos hosts.
- File Server / NAS para cópias adicionais.
- Política de retenção para ambientes de maior escala.
- Export automático de configurações prontas para restore.
- HTTPS para a Web UI.
- Separação por grupos/clientes.
- Inclusão de outros vendors suportados pelo Oxidized.
- Monitoramento de falhas de coleta e capacidade de disco.

## Segurança | Security

Este repositório de portfólio não contém:

- senhas;
- PSKs;
- certificados privados;
- hashes reutilizáveis;
- configurações completas de clientes;
- endereços públicos reais;
- segredos de produção.

Os exemplos são de laboratório e/ou foram sanitizados antes da publicação.

## Créditos e projeto de terceiros | Credits and third-party project

Este projeto utiliza o [Oxidized](https://github.com/ytti/oxidized), uma ferramenta open source para backup e versionamento de configurações de dispositivos de rede.

Oxidized é mantido por seus respectivos contribuidores e distribuído sob a **Apache License 2.0**.

This project uses [Oxidized](https://github.com/ytti/oxidized), an open-source tool for network device configuration backup and versioning.

Oxidized is maintained by its respective contributors and distributed under the **Apache License 2.0**.

Este repositório **não é afiliado ao projeto oficial do Oxidized**. O conteúdo representa uma implementação de laboratório, documentação, automações, troubleshooting e arquitetura desenvolvidos para estudo e demonstração técnica.

This repository **is not affiliated with the official Oxidized project**. Its content represents a lab implementation, documentation, automation, troubleshooting and architecture developed for study and technical demonstration purposes.

## Autor

**Ronan Braga**

Projeto de portfólio técnico focado em **Network Security, Network Automation, Linux, Fortinet, Cisco, pfSense, Git e troubleshooting**.
