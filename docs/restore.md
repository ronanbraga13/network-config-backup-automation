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
