# Restore e recuperação | Restore Workflow

O objetivo do LAB não foi apenas coletar configurações, mas validar que o conteúdo armazenado poderia ser utilizado em um fluxo real de recuperação.

## FortiGate

### Exportação pelo Git local

Listar nodes armazenados:

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  ls-tree -r --name-only HEAD
```

Exportar a versão atual:

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  show HEAD:FGT-SITE-A > /tmp/FGT-SITE-A.conf
```

Para versões anteriores, substitua `HEAD` pelo hash desejado.

### Adequação validada no LAB

O conteúdo coletado pelo Oxidized pode incluir linhas informativas adicionais. No teste realizado, o arquivo foi preparado mantendo o cabeçalho nativo FortiOS e removendo somente o conteúdo adicional que não fazia parte da configuração restaurável.

Exemplo de início esperado:

```text
#config-version=...
#buildno=...
#global_vdom=...
config system global
...
```

O arquivo ajustado foi aceito no FortiGate do laboratório.

### Limitação de permissões identificada

No LAB foi identificado que a coleta do FortiGate depende do nível de acesso da conta administrativa utilizada pelo Oxidized. Com uma conta restrita, `show system admin` exibiu somente a própria conta de coleta.

Isso significa que um arquivo coletado com sucesso pode ainda estar incompleto para fins de disaster recovery. Antes de tratar o arquivo como backup restaurável completo, valide a conta de coleta e execute teste de restore.

Uma nova validação será realizada com `oxidized_backup` como `super_admin`, restrito por trusted host.

### Cuidados

Antes de qualquer restore real, validar:

- modelo;
- versão do FortiOS;
- VDOM;
- interfaces;
- endereçamento;
- dependências de certificados;
- janela de mudança;
- rollback.


---

## Cisco IOS — restore validado com VLANs e SVI

Durante o teste destrutivo do switch Cisco IOS, foi identificado que o `running-config` sozinho não era suficiente para reconstruir completamente um equipamento zerado em todos os cenários.

Em VTP Server, as VLANs podem estar armazenadas fora do `running-config` (por exemplo, na VLAN database). Além disso, uma SVI operacional pode não trazer um `no shutdown` explícito no conteúdo coletado.

Para tratar esses dois pontos, o projeto inclui um modelo IOS customizado em:

```text
models/ios.rb
```

O modelo mantém a coleta padrão do Cisco IOS e adiciona:

- `show vlan brief`, convertido automaticamente em comandos `vlan <id>` e `name <nome>`;
- `show ip interface brief`, usado para gerar `no shutdown` para SVIs que estavam `up/up` no momento da coleta;
- o `show running-config` normal do Oxidized.

Exemplo do conteúdo restaurável gerado:

```text
! ===== VLAN CONFIG =====
vlan 10
 name VLAN0010
!
vlan 20
 name VLAN0020
!
vlan 30
 name VLAN0030
!
! ===== END VLAN CONFIG =====

! ===== SVI STATE CONFIG =====
interface Vlan20
 no shutdown
!
! ===== END SVI STATE CONFIG =====
```

### Teste de recuperação realizado

O `SW_RIO_01` foi removido do LAB e recriado zerado. A restauração foi realizada a partir do backup coletado pelo Oxidized:

```text
enable
configure terminal
<colar configuração coletada>
end
write memory
```

Após a restauração foram validados:

- VLANs 10, 20 e 30;
- portas access nas VLANs correspondentes;
- trunk 802.1Q com VLANs 10,20,30;
- SVI Vlan20 com endereço de gerenciamento;
- SVI `up/up` sem intervenção manual adicional;
- convergência de Spanning Tree;
- conectividade ICMP com o gateway;
- retorno do equipamento à coleta do Oxidized.

O segundo teste de ping apresentou 100% de sucesso após a convergência da camada 2.

### Instalação como modelo IOS padrão

Faça backup do model original da versão instalada antes de substituí-lo. No LAB com Oxidized 0.37.0:

```bash
OXIDIZED_MODEL_DIR="/var/lib/gems/3.0.0/gems/oxidized-0.37.0/lib/oxidized/model"

cp "$OXIDIZED_MODEL_DIR/ios.rb" "$OXIDIZED_MODEL_DIR/ios.rb.original"
cp models/ios.rb "$OXIDIZED_MODEL_DIR/ios.rb"

ruby -c "$OXIDIZED_MODEL_DIR/ios.rb"
systemctl restart oxidized
```

Com o modelo instalado como `ios.rb`, os equipamentos permanecem usando `ios` no `router.db`; não é necessário manter o identificador temporário `ios_restore`.

> A substituição dentro do diretório da gem pode ser sobrescrita por upgrade/reinstalação do Oxidized. O arquivo versionado neste repositório é a cópia de referência para reaplicação e auditoria.


## pfSense

O model do pfSense utilizado no LAB apresentou a configuração em XML pela Web UI do Oxidized.

### Procedimento validado

1. Abrir o node `PFSENSE-MG`.
2. Abrir a versão desejada.
3. Visualizar o conteúdo XML.
4. No navegador, usar **Ctrl + S**.
5. Salvar com extensão `.xml`.
6. Importar o arquivo no fluxo de Backup & Restore do pfSense.

Exemplo de nome:

```text
PFSENSE-MG_YYYY-MM-DD.xml
```

Após o restore realizado no LAB, o pfSense carregou a configuração e iniciou a reinstalação de packages em segundo plano.

Durante esse processo, a própria interface orienta evitar alterações até a conclusão.

---

## Git como histórico

O Git local permite recuperar qualquer versão ainda presente no histórico.

Histórico:

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  log --oneline --all
```

Visualização de uma versão específica:

```bash
sudo -u oxidized git \
  --git-dir=/home/oxidized/.config/oxidized/oxidized.git \
  show <COMMIT>:<NODE>
```

## Limites desta validação

Os restores foram validados em ambiente controlado PNETLab. O resultado comprova o procedimento apenas nos cenários efetivamente testados.

O pfSense teve o fluxo de backup/restore validado. No FortiGate, a nova descoberta sobre visibilidade condicionada às permissões da conta exige uma validação adicional com conta dedicada de privilégio adequado antes de considerar o backup completo. Outros vendors devem ser testados individualmente.

Próxima evolução planejada: backup nativo automatizado do FortiGate com envio direto para servidor via SFTP.
