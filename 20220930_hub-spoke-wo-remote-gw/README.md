# Hub-spoke architecture without Remote gateway

Remote Gateway を構成せずに、構成したように hub-spoke の通信を確立させる。

To establish connection from on-premise to hub-spoke architecture without Remote Gateway settings.

# 前提条件
- 拠点が 2 つある
- VNet が 2 つある
- それぞれの拠点から VNet への接続があり、2 つの VNet それぞれに ExpressRoute Gateway がある
- なので VNet Peering で Remote Gateway が設定できない

その環境において、拠点#1 から VNet #1 をとおって、VNet #2 まで通信させたい。

# 構成のポイント

- ExperessRoute を経由して通信させるためには ARS を使って経路広報するしかない
- そのための NVA を FRRouting で構成
- 広報アドレスは VNet #2 全体としているが /32 も可能かも
- NVA 代わりの Azure VM でパケットをフォワーディングする必要があるため `sysctl` で設定変更

# install FRRouting & configure FRRouting, enable forwarding

FRRouting の自動化までは `cloud-init` で済ませてあるので、`vtysh` を叩いて config を入れる部分に関しては、この README の後半を参照ください。

また、`sysctl` にて IP forwarding を有効化する必要があるのですが、`cloud-init` で自動化してあるので不要です。

```yaml
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


この状態で vm_hub100 から vm_hub00 を経由して vm_spoke10 に通信できていることを確認。

```
ikko@vm-hub100:~$ sudo ./ethr -c 10.10.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.10.0.4, ip: 10.10.0.4, port: 22
Tracing route to 10.10.0.4 over 30 hops:
 1.|--???
 2.|--10.0.0.4 []                                                            98.531ms
 3.|--10.10.0.4 []                                                           107.023ms
Ethr done, measurement complete.

```

vm_spoke10 から vm_hub00 を経由して vm_hub100 に通信していることも確認。

```
ikko@vm-spoke10:~$ sudo ./ethr -c 10.100.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.100.0.4, ip: 10.100.0.4, port: 22
Tracing route to 10.100.0.4 over 30 hops:
 1.|--10.0.0.4 []                                                            84.863ms
 2.|--???
 3.|--10.100.0.4 []                                                          140.520ms
Ethr done, measurement complete.
```

なお、VNet #1 の GatewaySubnet に Route Table がないと 10.0.0.4 を bypass してしまう。

```
ikko@vm-hub100:~$ sudo ./ethr -c 10.10.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.10.0.4, ip: 10.10.0.4, port: 22
Tracing route to 10.10.0.4 over 30 hops:
 1.|--???
 2.|--10.10.0.4 []                                                           101.430ms
Ethr done, measurement complete.
```

# 考慮点

NVA が通信経路上どうしても必要なコンポーネントになってしまうため NVA の冗長設計は要注意。

# FRRouting config sample

- VNet #2 にあたる `10.10.0.0/16` を static route で書きつつ、`redistribute static` で経路広報
- 不要な static route が advertise されるので prefix-filter で落とす

```
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
ip route 10.10.0.0/16 10.0.0.1
ip route 10.0.210.0/24 10.0.0.1
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
ip prefix-list PRE01 seq 5 deny 10.0.210.0/24
ip prefix-list PRE01 seq 10 permit any
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

設定後のイメージはこちら。
NVA となっている vm_hub00 におけるルーティングテーブル。

```
vm-hub00# show ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

K>* 0.0.0.0/0 [0/100] via 10.0.0.1, eth0, src 10.0.0.4, 05:01:44
B>  10.0.0.0/16 [20/0] via 10.0.210.4 (recursive), weight 1, 04:01:25
  *                      via 10.0.0.1, eth0, weight 1, 04:01:25
                       via 10.0.210.5 (recursive), weight 1, 04:01:25
                         via 10.0.0.1, eth0, weight 1, 04:01:25
C>* 10.0.0.0/24 is directly connected, eth0, 05:01:44
S>* 10.0.210.0/24 [1/0] via 10.0.0.1, eth0, weight 1, 04:01:30
S>* 10.10.0.0/16 [1/0] via 10.0.0.1, eth0, weight 1, 03:28:00
B>  10.100.0.0/16 [20/0] via 10.0.210.4 (recursive), weight 1, 04:01:25
  *                        via 10.0.0.1, eth0, weight 1, 04:01:25
                         via 10.0.210.5 (recursive), weight 1, 04:01:25
                           via 10.0.0.1, eth0, weight 1, 04:01:25
K>* 168.63.129.16/32 [0/100] via 10.0.0.1, eth0, src 10.0.0.4, 05:01:44
K>* 169.254.169.254/32 [0/100] via 10.0.0.1, eth0, src 10.0.0.4, 05:01:44
```

ARS に広報している経路。

```
vm-hub00# show ip bgp nei 10.0.210.4 advertised-routes
BGP table version is 4, local router ID is 10.0.0.4, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.10.0.0/16     0.0.0.0                  0         32768 ?

Total number of prefixes 1
```

ARS から受け取っている経路。

```
vm-hub00# show ip bgp nei 10.0.210.4 received-routes
BGP table version is 4, local router ID is 10.0.0.4, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.0.0/16      10.0.210.4                             0 65515 i
*> 10.100.0.0/16    10.0.210.4                             0 65515 12076 12076 i

Total number of prefixes 2
```