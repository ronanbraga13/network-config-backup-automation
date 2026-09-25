# Custom Cisco IOS model for Oxidized 0.37.0
#
# Based on the upstream Oxidized IOS model and extended for disaster-recovery
# use cases where VLAN data is stored outside running-config (for example,
# VTP Server mode) and operational SVI state must be restored explicitly.
#
# LAB validation:
# - VLAN database converted into valid IOS "vlan" configuration commands.
# - Active SVIs converted into explicit "no shutdown" commands.
# - Full running-config collection retained.
#
# Source project: https://github.com/ytti/oxidized

class IOS < Oxidized::Model
  using Refinements

  prompt /^([\w.@()-]+[#>]\s?)$/
  comment '! '

  cmd :all do |cfg|
    cfg.gsub! /^% Invalid input detected at '\^' marker\.$|^\s+\^$/, ''
    cfg.cut_both
  end

  cmd :secret do |cfg|
    cfg.gsub! /^(snmp-server community).*/, '\\1 <configuration removed>'
    cfg.gsub! /^(snmp-server host \S+( vrf \S+)?( informs?)?( version (1|2c))?) +\S+( .*)?$*/, '\\1 <secret hidden>\\6'
    cfg.gsub! /^(username .+ (password|secret) \d) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^(enable (password|secret)( level \d+)? \d) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^( +(?:password|secret)) (?:\d )?\S+/, '\\1 <secret hidden>'
    cfg.gsub! /^(.*wpa-psk ascii \d) (\S+)/, '\\1 <secret hidden>'
    cfg.gsub! /^(.*key 7) (\d.+)/, '\\1 <secret hidden>'
    cfg.gsub! /^(tacacs-server (.+ )?key) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^(crypto isakmp key) (\S+) (.*)/, '\\1 <secret hidden> \\3'
    cfg.gsub! /^( +ip ospf message-digest-key \d+ md5) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^( +ip ospf authentication-key) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^( +neighbor \S+ password) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^( +vrrp \d+ authentication text) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^( +standby \d+ authentication) .{1,8}$/, '\\1 <secret hidden>'
    cfg.gsub! /^( +standby \d+ authentication md5 key-string) .+?( timeout \d+)?$/, '\\1 <secret hidden> \\2'
    cfg.gsub! /^( +key-string) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^((tacacs|radius) server [^\n]+\n( +[^\n]+\n)* +key) [^\n]+$/m, '\\1 <secret hidden>'
    cfg.gsub! /^( +ppp (chap|pap) password \d) .+/, '\\1 <secret hidden>'
    cfg.gsub! /^( +security wpa psk set-key (?:ascii|hex) \d) (.*)$/, '\\1 <secret hidden>'
    cfg.gsub! /^( +dot1x username \S+ password \d) (.*)$/, '\\1 <secret hidden>'
    cfg.gsub! /^( +mgmtuser username \S+ password \d) (.*) (secret \d) (.*)$/, '\\1 <secret hidden> \\3 <secret hidden>'
    cfg.gsub! /^( +client \S+ server-key \d) (.*)$/, '\\1 <secret hidden>'
    cfg.gsub! /^( +domain-password) \S+ ?(.*)/, '\\1 <secret hidden> \\2'
    cfg.gsub! /^( +pre-shared-key).*/, '\\1 <configuration removed>'
    cfg.gsub! /^(.*server-key(?: \d)?) \S+/, '\\1 <secret hidden>'
    cfg
  end

  cmd :significant_changes do |cfg|
    cfg.reject_lines [
      /^! (Last|No) configuration change (at|since)/,
      '! NVRAM config last updated at'
    ]
  end

  cmd 'show version' do |cfg|
    comments = []
    comments << cfg.lines.first
    lines = cfg.lines
    lines.each_with_index do |line, i|
      slave = ''
      slaveslot = ''

      if line =~ /^Slave in slot (\d+) is running/
        slave = " Slave:"
        slaveslot = ", slot #{Regexp.last_match(1)}"
      end

      comments << "Image:#{slave} Compiled: #{Regexp.last_match(1)}" if line =~ /^Compiled (.*)$/

      if line =~ /^(?:Cisco )?IOS .* Software,? \(([A-Za-z0-9_-]*)\), .*Version\s+(.*)$/
        comments << "Image:#{slave} Software: #{Regexp.last_match(1)}, #{Regexp.last_match(2)}"
      end

      if line =~ /^ROM: (IOS \S+ )?(System )?Bootstrap.*(Version.*)$/
        comments << "ROM Bootstrap: #{Regexp.last_match(3)}"
      end

      comments << "BOOTFLASH: #{Regexp.last_match(1)}" if line =~ /^BOOTFLASH: .*(Version.*)$/
      comments << "Memory: nvram #{Regexp.last_match(1)}" if line =~ /^(\d+[kK]) bytes of (non-volatile|NVRAM)/

      if line =~ /^(\d+[kK]) bytes of (flash memory|flash internal|processor board System flash|ATA CompactFlash)/i
        comments << "Memory: flash #{Regexp.last_match(1)}"
      end

      if line =~ /^(\d+[kK]) bytes of (Flash|ATA)?.*PCMCIA .*(slot|disk) ?(\d)/i
        comments << "Memory: pcmcia #{Regexp.last_match(2)} #{Regexp.last_match(3)}#{Regexp.last_match(4)} #{Regexp.last_match(1)}"
      end

      if line =~ /(\S+(?:\sseries)?)\s+(?:\(([\S ]+)\)\s+processor|\(revision[^)]+\)).*\s+with (\S+k) bytes/i
        sproc = Regexp.last_match(1)
        cpu = Regexp.last_match(2)
        mem = Regexp.last_match(3)
        cpuxtra = ''
        comments << "Chassis type:#{slave} #{sproc}"
        comments << "Memory:#{slave} main #{mem}"
        comments << "Processor ID: #{Regexp.last_match(1)}" if cfg.lines[i + 1] =~ /processor board id (\S+)/i
        if cfg.lines[i + 2] =~ /(cpu at |processor: |#{cpu} processor,)/i
          cpuxtra = cfg.lines[i + 2].gsub("implementation", 'impl').gsub(/^/, ', ').chomp
        end
        comments << "CPU:#{slave} #{cpu}#{cpuxtra}#{slaveslot}"
      end

      comments << line.chomp if line.start_with?('Motherboard')
      comments << "Image: #{Regexp.last_match(1)}" if line =~ /^System image file is "([^"]*)"$/
    end
    comments << "\n"
    comment comments.join "\n"
  end

  cmd 'show vtp status' do |cfg|
    cfg.gsub! /^$\n/, ''
    cfg.gsub! /Configuration last modified by.*\n/, ''
    cfg.gsub! /^/, 'VTP: ' unless cfg.empty?
    comment "#{cfg}\n"
  end

  cmd 'show inventory' do |cfg|
    comment cfg
  end

  # Disaster-recovery extension:
  # VTP Server/Client may keep VLAN definitions outside running-config.
  # Convert show vlan brief into valid IOS configuration statements.
  cmd 'show vlan brief' do |cfg|
    vlans = []

    cfg.each_line do |line|
      if line =~ /^\s*(\d+)\s+(\S+)\s+(active|act\/unsup)/
        vlan_id = Regexp.last_match(1).to_i
        vlan_name = Regexp.last_match(2)

        next if vlan_id == 1
        next if (1002..1005).include?(vlan_id)

        vlans << [vlan_id, vlan_name]
      end
    end

    output = ''

    unless vlans.empty?
      output << "! ===== VLAN CONFIG =====\n"

      vlans.each do |vlan_id, vlan_name|
        output << "vlan #{vlan_id}\n"
        output << " name #{vlan_name}\n"
        output << "!\n"
      end

      output << "! ===== END VLAN CONFIG =====\n\n"
    end

    output
  end

  # Disaster-recovery extension:
  # Running-config may omit explicit "no shutdown" on an operational SVI.
  # Preserve active SVI administrative state for clean-device restores.
  cmd 'show ip interface brief' do |cfg|
    svis = []

    cfg.each_line do |line|
      if line =~ /^(Vlan\d+)\s+\S+\s+\S+\s+\S+\s+up\s+up\s*$/
        svis << Regexp.last_match(1)
      end
    end

    output = ''

    unless svis.empty?
      output << "! ===== SVI STATE CONFIG =====\n"

      svis.each do |svi|
        output << "interface #{svi}\n"
        output << " no shutdown\n"
        output << "!\n"
      end

      output << "! ===== END SVI STATE CONFIG =====\n\n"
    end

    output
  end

  post do
    cmd_line = 'show running-config'
    cmd_line += ' view full' if vars(:ios_rbac)
    cmd cmd_line do |cfg|
      cfg = cfg.cut_head(3)
      cfg = cfg.reject_lines [
        /^ntp clock-period /,
        /^Current configuration : \S+/
      ]
      unless vars("output_store_mode") == "on_significant"
        cfg = cfg.reject_lines [
          /^! (Last|No) configuration change (at|since)(?!.*\d+ by \S+$)/
        ]
      end
      cfg.gsub! /^ tunnel mpls traffic-eng bandwidth[^\n]*\n*(
                    (?: [^\n]*\n*)*
                    tunnel mpls traffic-eng auto-bw)/mx, '\\1'
      cfg.gsub! /^(\s+expression) \d+$/, '\\1 <value removed>'
      cfg
    end
  end

  cfg :telnet do
    username /^Username:/i
    password /^Password:/i
  end

  cfg :telnet, :ssh do
    post_login 'terminal length 0'
    post_login 'terminal width 0'
    pre_logout 'exit'
  end

  macro :enable
end
