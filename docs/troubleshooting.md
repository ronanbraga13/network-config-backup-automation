# Troubleshooting do LAB | Lab Troubleshooting

Este documento registra os principais problemas encontrados durante a implementação e como foram diagnosticados.

## 1. SSH conectava, mas a coleta expirava no FortiGate

### Sintoma

O SSH era estabelecido, porém comandos extensos e a coleta do Oxidized terminavam com:

```text
Timeout::Error
execution expired
```

### Diagnóstico

Foram realizados testes de PMTU no ambiente virtual. O caminho aceitava pacote IP de aproximadamente **1496 bytes**, enquanto o Ubuntu utilizava MTU 1500.

### Workaround validado no PNETLab

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
      mtu: 1496
```

Aplicação:

```bash
sudo netplan try
sudo netplan apply
ip link show eth0
```

Após reboot, o MTU permaneceu 1496 e o serviço Oxidized voltou automaticamente.

> Este ajuste é específico do ambiente PNETLab testado. Não deve ser aplicado como padrão em produção sem diagnóstico de MTU/PMTU.

---

## 2. `Network is unreachable` após boot

### Sintoma

O journal mostrava:

```text
Errno::ENETUNREACH
Network is unreachable
```

### Interpretação

O Oxidized iniciou enquanto a conectividade/rotas do ambiente virtual ainda não estavam completamente disponíveis.

### Validação

```bash
ip route
ping <gateway>
ping <device-ip>
systemctl restart oxidized
journalctl -u oxidized -f
```

O serviço está configurado com:

```ini
After=network-online.target
Wants=network-online.target
```

---

## 3. Host key SSH alterada

### Sintoma

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
Host key verification failed.
```

### Correção

Quando a troca de chave era esperada no LAB:

```bash
ssh-keygen -f ~/.ssh/known_hosts -R "<device-ip>"
```

Depois, a nova fingerprint era validada manualmente.

---

## 4. Cisco IOL sem SSH utilizável

### Sintoma

Em algumas imagens Cisco IOL antigas, `transport input ?` não oferecia SSH, ou o SSH dependia de algoritmos legados.

### Decisão técnica

Em vez de enfraquecer a configuração criptográfica do Ubuntu, os nodes legados do LAB utilizaram Telnet apenas no ambiente controlado:

```cisco
username oxidized_backup privilege 15 secret <LAB_PASSWORD>

line vty 0 4
 login local
 transport input telnet
```

No inventário:

```text
SW-SITE-A:10.10.20.10:ios:telnet
```

> Em produção, Telnet não é recomendado.

---

## 5. Switch remoto alcançável somente com NAT

### Sintoma

O switch possuía gateway configurado, mas o tráfego de retorno para redes remotas não funcionava corretamente.

### Diagnóstico

A tabela de roteamento não possuía default route válida.

### Correção no LAB

```cisco
ip route 0.0.0.0 0.0.0.0 10.10.20.1
```

Após isso, o node tornou-se alcançável sem depender de NAT para mascarar a origem.

---

## 6. pfSense não respondia na porta 22

### Sintoma

O tráfego chegava ao pfSense, mas não havia serviço escutando em TCP/22.

### Diagnóstico

```bash
netstat -an | grep '\.22 '
```

Sem listener, o problema não era de roteamento.

### Correção

SSH habilitado em:

```text
System > Advanced > Admin Access > Secure Shell
```

Depois disso, o node pfSense passou a ser coletado pelo Oxidized.

---

## 7. Interfaces WAN do pfSense invertidas

### Sintoma

ARP incompleto e ausência de resposta nos links simulados das operadoras.

### Causa

As interfaces físicas associadas aos links Claro/Vivo estavam invertidas no pfSense.

### Correção

Revisão do assignment das interfaces e validação com ping/ARP.

---

## 8. Comandos úteis

```bash
systemctl status oxidized --no-pager
journalctl -u oxidized -n 100 --no-pager
journalctl -u oxidized -f
ip link show eth0
ip route
cat /home/oxidized/.config/oxidized/router.db
```

O princípio utilizado durante o LAB foi sempre separar falhas de:

1. camada física/virtual;
2. VLAN;
3. roteamento;
4. serviço TCP;
5. autenticação;
6. comportamento específico do model/protocolo.
