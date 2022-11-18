# Public IP in VNet

Public IP (というか単なるおれおれ global IP) アドレスを VNet の中で使いたい、という話があったので検証環境を組みました。

# 構成のポイント

FRRouting を使いまして、まずは目的の global IP アドレス (1.2.3.4/32) を `eth0` の secondary IP として付与します。
そのうえで、これを BGP で ARS (Azure Route Server) に経路広報しておきます。
また、この NVA VM の NIC の設定で、IP forwarding を有効化しておきます。
オレオレ Bicep library を使っているので 1 行追加するだけです。

```bicep
var vm10Name = 'vm-spoke10'
module vm_spoke10 '../lib/ubuntu2004.bicep' = {
  name: vm10Name
  params: {
...
    enableIPForwarding: true
  }
}
```

これらの設定により、branch を想定した ExpressRoute の先の VNet からもこの 1.2.3.4/32 に対して通信ができます。

加えて、1.2.0.0/16 の IP address 空間を設定した VNet も接続してみましたが、こっからはつながらないことを確認しています。
/16 の中から /32 だけを抜くってのができないってことですね。

# 結果

[Microsoft/Ethr](https://github.com/Microsoft/Ethr) を使って TCP traceroute を取ったのと、シンプルに ping も試してあります。

```shell
ikko@vm-hub200:~$ sudo ./ethr -c 1.2.3.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 1.2.3.4, ip: 1.2.3.4, port: 22
Tracing route to 1.2.3.4 over 30 hops:
 1.|--???
 2.|--1.2.3.4 []                                                             4.999ms
Ethr done, measurement complete.
```

```
ikko@vm-hub200:~$ ping -c 3 1.2.3.4
PING 1.2.3.4 (1.2.3.4) 56(84) bytes of data.
64 bytes from 1.2.3.4: icmp_seq=1 ttl=63 time=5.25 ms
64 bytes from 1.2.3.4: icmp_seq=2 ttl=63 time=5.35 ms
64 bytes from 1.2.3.4: icmp_seq=3 ttl=63 time=5.28 ms

--- 1.2.3.4 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 5.245/5.291/5.351/0.044 ms
```

# sample config

```
vm-spoke10# show run
Building configuration...

Current configuration:
!
frr version 8.4
frr defaults traditional
hostname vm-spoke10
log syslog informational
no ip forwarding
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.0.210.0/24 10.0.0.1
!
interface eth0
 ip address 1.2.3.4/32
exit
!
router bgp 65001
 neighbor 10.0.210.4 remote-as 65515
 neighbor 10.0.210.4 ebgp-multihop 255
 neighbor 10.0.210.5 remote-as 65515
 neighbor 10.0.210.5 ebgp-multihop 255
 !
 address-family ipv4 unicast
  network 1.2.3.4/32
  neighbor 10.0.210.4 soft-reconfiguration inbound
  neighbor 10.0.210.4 route-map rmap-bogon-asns in
  neighbor 10.0.210.4 route-map rmap-azure-asns out
  neighbor 10.0.210.5 soft-reconfiguration inbound
  neighbor 10.0.210.5 route-map rmap-bogon-asns in
  neighbor 10.0.210.5 route-map rmap-azure-asns out
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