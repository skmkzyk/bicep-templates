# Create FRRouting VM by cloud-init

`cloud-init` を使って自動化しようシリーズのひとつで、今回は FRRouting を自動化します。
config の投入までは自動化できていませんがいつか頑張りましょう

# 構成のポイント

Azure VM 側の Bicep での設定としては、NVA にするため `enableIPForwarding` を `true` としています。

OS 内部の設定を担う `cloud-init` は FRRouting に書かれている [手順](https://deb.frrouting.org/) をそのまま文法に則って書き直しただけです。
そのほかの設定として NVA にするため `net.ipv4.ip_forward` の有効化と、`bgpd=yes` とすることで FRRouting で BGP を有効化しています。

```
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - sed -i.org 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - curl -s https://deb.frrouting.org/frr/keys.asc | apt-key add -
  - FRRVER="frr-stable"
  - echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | tee -a /etc/apt/sources.list.d/frr.list
  - apt update && apt -y install frr frr-pythontools
  - sed -i.org 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
  - systemctl restart frr
```

# 結果

Azure VM に Bastion 経由でログインし、`sudo -s` で昇格した後に `vtysh` で FRRouting のコンソールを開きます。
エラーが出ずに石黒さんのお名前が出れば大丈夫でしょう。

```shell
ikko@vm-hub00:~$ sudo -s
root@vm-hub00:/home/ikko# vtysh

Hello, this is FRRouting (version 8.3.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.
```
