# Create FRRouting VM by cloud-init

`cloud-init` を使って自動化しようシリーズのひとつで、今回は FRRouting を自動化します。
~~config の投入までは自動化できていませんがいつか頑張りましょう。~~
config の追加まで実現しました。

# 構成のポイント

Azure VM 側の Bicep での設定としては、NVA にするため `enableIPForwarding` を `true` としています。

OS 内部の設定を担う `cloud-init` は FRRouting に書かれている [手順](https://deb.frrouting.org/) をそのまま文法に則って書き直しただけです。
そのほかの設定として NVA にするため `net.ipv4.ip_forward` の有効化と、`bgpd=yes` とすることで FRRouting で BGP を有効化しています。

FRRouting の実際の config は `/etc/frr/frr.conf` ですが、一度 `/tmp/frr.conf` へ書くようにしています。
これは、`cloud-init` の module の順序が `write_files` が先で `run_cmd` が後のため、`write_files` で `/etc/frr/frr.conf` にしてしまうとファイルが作成された後に FRRouting が install されてしまうためです。
`run_cmd` の中で FRRouting を install し、そのあとに `/tmp/frr.conf` から `/etc/frr/frr.conf` へとコピーし `systemctl restart frr` することで、正しく動くような感じにしています。

```
#cloud-config
packages_update: true
packages_upgrade: true
write_files:
  - path: /tmp/frr.conf
    content: |
      frr version 8.3.1
      frr defaults traditional
      hostname vm-hub00
      log syslog informational
      no ipv6 forwarding
      service integrated-vtysh-config
      !
      ip route 10.0.210.0/24 10.0.0.1
      !
runcmd:
  - sed -i.org 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - curl -s https://deb.frrouting.org/frr/keys.asc | apt-key add -
  - FRRVER="frr-stable"
  - echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | tee -a /etc/apt/sources.list.d/frr.list
  - apt update && apt -y install frr frr-pythontools
  - sed -i.org 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
  - cp /tmp/frr.conf /etc/frr/frr.conf
  - systemctl restart frr

```

# 結果

Azure VM に Bastion 経由でログインし、`sudo -s` で昇格した後に `vtysh` で FRRouting のコンソールを開きます。
`show run` して、`ip route` の行が含まれているのでこれは `cloud-init` で配置した config を読み込んでいることがわかります。
今回はデフォルトの `/etc/frr/frr.conf` からの変更点は小さいですが、大きな config もこれで流し込めるはずです。

```shell
ikko@vm-hub00:~$ sudo -s
root@vm-hub00:/home/ikko# vtysh

Hello, this is FRRouting (version 8.3.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

vm-hub00# show run
Building configuration...

Current configuration:
!
frr version 8.3.1
frr defaults traditional
hostname vm-hub00
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.0.210.0/24 10.0.0.1
!
end
```
