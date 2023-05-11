# A different architecture pattern for ER + VPN

ER + VPN といえば以下のページを参照することが多いです。

https://learn.microsoft.com/ja-jp/azure/vpn-gateway/site-to-site-vpn-private-peering

ですが、ここでは ExpressRoute Gateway のある VNet と VPN Gateway のある VNet が分かれている構成を考えてみます。
なんでやりたいのかといわれると、思いついたから、までなのですが、ちょっとやってみます。

Zenn の記事はこちらです。
併せてごらんくださいませ。

https://zenn.dev/skmkzyk/articles/er-spoke-vpn

# 構成のポイント

今回は [Cloud Lab](https://www.attokyo.co.jp/connectivity/cloudlab.html) で試していることもあり、Cisco の実機がオンプレミス環境にあります。
そのため、Azure 上では完全に再現しきれない構成となっています。

- Hub-Spoke 構成を作る
  - Remote Gateway は有効にせず進めます
  - ついでに ExpressRoute でいい感じに接続しておきます
- Hub に ARS (Azure Route Server) と FRRouting を入れた Azure VM を用意する
  - FRRouting は Spoke 側の GatewaySubnet 部分のみを経路広報します
  - これにより、on-premise 側の Cisco まで reachability があるようにします
  - この Azure VM は IP Forwarding を Azure 側、OS 側の双方で有効化してあります
- Spoke に Private IP address を有効化した VPN Gateway をデプロイします
  - Private IP address 機能を有効にできる SKU は少し限定されているので注意してください
  - VPN Gateway の宛先となる Local Network Gateway には Cisco の loopback アドレスを入れておきます
  - この GatewaySubnet において、10.100.20.1/32 あての明示的な UDR を入れておき、on-premise 側への通信が NVA を経由するようにします
    - NVA から Spoke 側に ARS を使って伝える方法も可能かと思いますが、コストがかかるので UDR で済ませています
- on-premise 側 Cisco Router を設定します
  - Connection を作成した後 Azure Portal から "Download configuration" からダウンロードできる config はそのままでは使えなかったので修正が必要です
  - 具体的には、`tunnel destination 10.10.200.6` などで指定される IP アドレスが Public IP address のままなので適宜変える必要があります
  - Private IP address を有効化した状態での、VPN の IP address と BGP の neighbor は違うので気を付けてください
- On-premise 側 Cisco Router 配下の PC から Spoke まで通信できることを確認します
  - 経路を注意深く見ていくことで VPN を通っていることを確認します

# Sample config

FRRouting の sample config はこちらです。
[Azure Route Server と FRRouting の間で BGP ピアを張る](https://zenn.dev/skmkzyk/articles/azure-route-server-frrouting) の内容を大いに参考にしています。

違いがある点としては、10.10.200.0/24 を追加で ARS で経路広報することで、Remote Gateway を使っていない状態でも、Spoke VNet に reachability を提供するものです。
Remote Gateway を使わずに Hub-Spoke 構成を扱う場合は [Hub-spoke architecture without Remote gateway with VXLAN](https://github.com/skmkzyk/bicep-templates/tree/main/20221006_hub-spoke-wo-remote-gw-vxlan) などが参考になります。

```
vm-hub00# show run
Building configuration...

Current configuration:
!
frr version 8.4.1
frr defaults traditional
hostname vm-hub00
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.0.210.0/24 10.0.0.1
ip route 10.10.200.0/24 10.0.0.1
!
router bgp 65001
 neighbor 10.0.210.4 remote-as 65515
 neighbor 10.0.210.4 ebgp-multihop 255
 neighbor 10.0.210.5 remote-as 65515
 neighbor 10.0.210.5 ebgp-multihop 255
 !
 address-family ipv4 unicast
  redistribute static
  neighbor 10.0.210.4 soft-reconfiguration inbound
  neighbor 10.0.210.4 prefix-list PRE01 out
  neighbor 10.0.210.4 route-map rmap-bogon-asns in
  neighbor 10.0.210.4 route-map rmap-azure-asns out
  neighbor 10.0.210.5 soft-reconfiguration inbound
  neighbor 10.0.210.5 prefix-list PRE01 out
  neighbor 10.0.210.5 route-map rmap-bogon-asns in
  neighbor 10.0.210.5 route-map rmap-azure-asns out
 exit-address-family
exit
!
ip prefix-list PRE01 seq 5 permit 10.10.200.0/24
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

次に Cisco の sample config です。
本物の Cisco に入れていた config なので、FRRouting とは互換性がないかと思います。
また、Azure 上でもこの構成は実現できません。

```
tky01#show run
Building configuration...

Current configuration : 4178 bytes
!
! Last configuration change at 07:53:18 UTC Sat Dec 3 2022
!
version 15.6
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname tky01
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
!
!
!
!
!
!
!
!
!
!
!
!
!
!


!
!
!
!
ip cef
no ipv6 cef
!
!
!
!
!
multilink bundle-name authenticated
!
!
!
!
!
!
!
license udi pid C892FSP-K9 sn FJC2020L0AP
!
!
!
redundancy
!
crypto ikev2 proposal conn-spoke10-onprem01-proposal
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy conn-spoke10-onprem01-policy
 match address local 10.100.20.1
 proposal conn-spoke10-onprem01-proposal
!
crypto ikev2 keyring conn-spoke10-onprem01-keyring
 peer 10.10.200.4
  address 10.10.200.4
  pre-shared-key xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 !
 peer 10.10.200.5
  address 10.10.200.5
  pre-shared-key xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 !
!
!
crypto ikev2 profile conn-spoke10-onprem01-profile
 match address local 10.100.20.1
 match identity remote address 10.10.200.4 255.255.255.255
 match identity remote address 10.10.200.5 255.255.255.255
 authentication local pre-share
 authentication remote pre-share
 keyring local conn-spoke10-onprem01-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
!
!
!
!
!
crypto ipsec transform-set conn-spoke10-onprem01-TransformSet esp-gcm 256
 mode tunnel
!
!
crypto ipsec profile ipsecpro-spoke10-onprem01
 set transform-set conn-spoke10-onprem01-TransformSet
 set ikev2-profile conn-spoke10-onprem01-profile
!
!
!
!
!
!
!
interface Loopback0
 ip address 10.100.20.1 255.255.255.255
!
interface Tunnel13
 ip address 169.254.0.3 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.20.1
 tunnel mode ipsec ipv4
 tunnel destination 10.10.200.4
 tunnel protection ipsec profile ipsecpro-spoke10-onprem01
!
interface Tunnel14
 ip address 169.254.0.4 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.20.1
 tunnel mode ipsec ipv4
 tunnel destination 10.10.200.5
 tunnel protection ipsec profile ipsecpro-spoke10-onprem01
!
interface GigabitEthernet0
 no ip address
!
interface GigabitEthernet1
 no ip address
!
interface GigabitEthernet2
 no ip address
!
interface GigabitEthernet3
 no ip address
!
interface GigabitEthernet4
 no ip address
!
interface GigabitEthernet5
 no ip address
!
interface GigabitEthernet6
 no ip address
!
interface GigabitEthernet7
 switchport access vlan 10
 no ip address
!
interface GigabitEthernet8
 no ip address
 duplex auto
 speed auto
!
interface GigabitEthernet8.714
 encapsulation dot1Q 714
 ip address 172.16.0.1 255.255.255.252
!
interface GigabitEthernet9
 no ip address
 shutdown
 duplex auto
 speed auto
!
interface Vlan1
 no ip address
!
interface Vlan10
 ip address 10.100.10.1 255.255.255.0
!
router bgp 65150
 bgp log-neighbor-changes
 network 10.100.10.0 mask 255.255.255.0
 network 10.100.20.1 mask 255.255.255.255
 neighbor 10.10.200.6 remote-as 65155
 neighbor 10.10.200.6 ebgp-multihop 255
 neighbor 10.10.200.6 update-source Loopback0
 neighbor 10.10.200.6 soft-reconfiguration inbound
 neighbor 10.10.200.6 prefix-list VPNBGP01 out
 neighbor 10.10.200.7 remote-as 65155
 neighbor 10.10.200.7 ebgp-multihop 255
 neighbor 10.10.200.7 update-source Loopback0
 neighbor 10.10.200.7 soft-reconfiguration inbound
 neighbor 10.10.200.7 prefix-list VPNBGP01 out
 neighbor 172.16.0.2 remote-as 12076
 neighbor 172.16.0.2 soft-reconfiguration inbound
 neighbor 172.16.0.2 prefix-list ERBGP01 out
!
ip forward-protocol nd
no ip http server
no ip http secure-server
!
!
ip route 10.10.200.6 255.255.255.255 Tunnel13
ip route 10.10.200.7 255.255.255.255 Tunnel14
ip ssh server algorithm encryption aes128-ctr aes192-ctr aes256-ctr
ip ssh client algorithm encryption aes128-ctr aes192-ctr aes256-ctr
!
!
ip prefix-list ERBGP01 seq 5 permit 10.100.20.1/32
ip prefix-list ERBGP01 seq 10 permit 10.100.10.0/24
!
ip prefix-list VPNBGP01 seq 5 permit 10.100.10.0/24
ipv6 ioam timestamp
!
!
control-plane
!
!
!
mgcp behavior rsip-range tgcp-only
mgcp behavior comedia-role none
mgcp behavior comedia-check-media-src disable
mgcp behavior comedia-sdp-force disable
!
mgcp profile default
!
!
!
!
!
!
!
line con 0
 no modem enable
line aux 0
line vty 0 4
 login
 transport input none
!
scheduler allocate 20000 1000
!
end

```

# 参考

- Azure Route Server と FRRouting の間で BGP ピアを張る

  https://zenn.dev/skmkzyk/articles/azure-route-server-frrouting

- Hub-spoke architecture without Remote gateway with VXLAN

  https://github.com/skmkzyk/bicep-templates/tree/main/20221006_hub-spoke-wo-remote-gw-vxlan