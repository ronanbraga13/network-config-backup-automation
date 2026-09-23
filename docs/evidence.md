# Evidências de validação | Validation Evidence

## Topologia técnica sanitizada

![Topologia técnica do LAB](../images/topology-lab.jpg)

A imagem de arquitetura foi preparada a partir da topologia real do PNETLab e contém somente informações de laboratório. Evidências operacionais adicionais devem permanecer screenshots reais, com informações sensíveis ocultadas quando necessário.


Este documento consolida as evidências técnicas obtidas durante o LAB. As capturas de tela originais permanecem fora do repositório até passarem por revisão final de exposição de dados.

## 1. Coleta multi-vendor

O Oxidized foi validado com **7 nodes**:

| Node | Plataforma | Transporte | Resultado |
|---|---|---|---|
| FGT-MATRIZ | Fortinet FortiGate | SSH | Coleta validada |
| FGT-RIO | Fortinet FortiGate | SSH | Coleta validada |
| PFSENSE-MG | pfSense | SSH | Coleta validada |
| SW-RIO-01 | Cisco IOS | Telnet* | Coleta validada |
| SW-MG-01 | Cisco IOS | Telnet* | Coleta validada |
| RTR-CLARO | Cisco IOS | Telnet* | Coleta validada |
| RTR-VIVO | Cisco IOS | Telnet* | Coleta validada |

\* Uso restrito ao LAB por limitação das imagens Cisco IOL antigas.

## 2. Versionamento Git

Foram validados:

- criação automática de commits;
- histórico de versões por node;
- comparação visual de diferenças pela Web UI;
- recuperação de versões via CLI;
- exportação da configuração atual a partir do repositório Git bare.

Comandos usados:

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  log --oneline --all

sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  ls-tree -r --name-only HEAD
```

## 3. Coleta manual pela Web

A interface Web foi utilizada para:

- consultar nodes;
- verificar status;
- executar coleta sob demanda;
- recarregar o inventário;
- abrir configurações coletadas;
- consultar versões;
- comparar mudanças.

## 4. Restore FortiGate

O arquivo coletado foi:

1. exportado do Git;
2. salvo como `.conf`;
3. ajustado para manter o cabeçalho nativo FortiOS;
4. importado em um FortiGate do LAB.

Resultado: **restore validado no cenário testado**.

## 5. Restore pfSense

A configuração coletada foi exibida pelo Oxidized em XML.

Procedimento validado:

1. abrir a versão pela Web UI;
2. usar **Ctrl + S**;
3. salvar com extensão `.xml`;
4. importar o XML no pfSense.

Após a restauração, o pfSense carregou a configuração e iniciou a reinstalação automática dos packages.

Resultado: **restore validado no cenário testado**.

## 6. Persistência após reboot

Foi realizado reboot do servidor Ubuntu após configuração do Netplan.

Validações:

- MTU 1496 permaneceu configurado no ambiente PNETLab;
- serviço `oxidized.service` voltou automaticamente;
- Web UI voltou;
- inventário foi carregado;
- coletas voltaram a operar.

## 7. Troubleshooting baseado em evidências

Durante o projeto foram diagnosticados e tratados:

- PMTU/MTU causando timeout em SSH;
- rotas ausentes após boot;
- default route ausente em Cisco L2;
- SSH não habilitado no pfSense;
- interfaces WAN invertidas no pfSense;
- limitações de SSH em imagens Cisco IOL legadas;
- mudança de SSH host key após reconstrução de equipamento.

Detalhes: [troubleshooting.md](troubleshooting.md).

## 8. Política de publicação das imagens

Antes de publicar screenshots em um repositório público, revisar e remover quando aplicável:

- credenciais;
- hashes;
- PSKs;
- certificados;
- nomes de clientes;
- endereços públicos;
- dados de produção;
- identificadores que não sejam necessários à demonstração.

As imagens públicas do portfólio devem representar somente o ambiente de laboratório ou conteúdo sanitizado.
