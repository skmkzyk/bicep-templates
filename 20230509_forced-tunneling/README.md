# Build a forced tunneling architecture with Azure Route Server

Azure Route Server を使った強制トンネリングの環境を作成する。

# 構成のポイント

- ExpressRoute circuit を適当に作成する
- クラウド想定の VNet と、オンプレミス想定の VNet を作成し、ExpressRoute でそれぞれを接続する
- クラウド想定の VNet には強制トンネリングの影響を回避してリモート接続するための jump server を作成する
- オンプレミス想定の VNet には ARS (Azure Route Server) と NVA のための Ubuntu Server 20.04 を作成する
- ARS と NVA の間で BGP の neighbor を張る
- クラウド想定の VNet にある client 用 Azure VM から通信させ、その送信元が NVA の Public IP アドレスになっていることを確認する

この main.bicep においては、それぞれの Azure VM は以下の名前で作成されます。

- client: vm-hub00
- jump server: vm-jump01
- NVA: vm-nva100

# FRRouting sample config

参考にした Zenn の記事から、IP アドレスを変更しています。
また、0.0.0.0/0 を経路広報するために `neighbor x.x.x.x default-originate` という設定を追加しています。

```
vm-nva100# show run
Building configuration...

Current configuration:
!
frr version 8.5.1
frr defaults traditional
hostname vm-nva100
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.100.210.0/24 10.100.0.1
!
router bgp 65001
 neighbor 10.100.210.4 remote-as 65515
 neighbor 10.100.210.4 ebgp-multihop 255
 neighbor 10.100.210.5 remote-as 65515
 neighbor 10.100.210.5 ebgp-multihop 255
 !
 address-family ipv4 unicast
  neighbor 10.100.210.4 default-originate
  neighbor 10.100.210.4 soft-reconfiguration inbound
  neighbor 10.100.210.4 route-map rmap-bogon-asns in
  neighbor 10.100.210.4 route-map rmap-azure-asns out
  neighbor 10.100.210.5 default-originate
  neighbor 10.100.210.5 soft-reconfiguration inbound
  neighbor 10.100.210.5 route-map rmap-bogon-asns in
  neighbor 10.100.210.5 route-map rmap-azure-asns out
 exit-address-family
exit
!
bgp as-path access-list azure-asns seq 5 permit _65515_
bgp as-path access-list bogon-asns seq 5 permit _0_
bgp as-path access-list bogon-asns seq 10 permit _23456_
bgp as-path access-list bogon-asns seq 15 permit _1310[0-6][0-9]_|_13107[0-1]_
bgp as-path access-list bogon-asns seq 20 deny _65515_
bgp as-path access-list bogon-asns seq 25 permit ^65
!
route-map rmap-bogon-asns deny 5
 match as-path bogon-asns
exit
!
route-map rmap-bogon-asns permit 10
exit
!
route-map rmap-azure-asns deny 5
 match as-path azure-asns
exit
!
route-map rmap-azure-asns permit 10
exit
!
end
```

# 結果

少し mask しましたが、この IP アドレスが NVA に関連付けた Public IP アドレスであることは確認しています。

```powershell
> curl.exe -k https://ifconfig.me
52.140.x.x
```

# 参考

- ExpressRoute 検証環境をシュッと作る

  https://zenn.dev/skmkzyk/articles/crisp-expressroute

- Azure Route Server と FRRouting の間で BGP ピアを張る

  https://zenn.dev/skmkzyk/articles/azure-route-server-frrouting

- ARS と NVA を使った強制トンネリング環境を作る

  https://zenn.dev/skmkzyk/articles/forced-tunneling-with-ars-and-nva
