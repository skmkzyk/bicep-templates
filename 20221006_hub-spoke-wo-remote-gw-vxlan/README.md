# Hub-spoke architecture without Remote gateway with VXLAN

Remote Gateway を構成せずに、構成したように hub-spoke の通信を確立させる。

To establish connection from on-premise to hub-spoke architecture without Remote Gateway settings.

# 前提条件
- 拠点が 2 つある
- VNet が 2 つある
- それぞれの拠点から VNet への接続があり、2 つの VNet それぞれに ExpressRoute Gateway がある
- なので VNet Peering で Remote Gateway が設定できない

その環境において、拠点 #1 から VNet #1 をとおって、VNet #2 まで通信させたい。

# 構成のポイント

OS の設定は `cloud-init` で済ませてあり、`net.ipv4.ip_forward` の有効化と FRRouting の install までが完了しています。

今回は `vm-hub00` (VNet #1) と `vm-hub100` (拠点 #1) を VXLAN で接続し、その間は static route で設定します。
なのでぶっちゃけ FRRouting 無しでも行けると思います。

- `vm-hub00` での起動スクリプトでの VXLAN の設定

```
ikko@vm-hub00:~$ cat /etc/network/if-post-up.d/vxlan
#!/bin/sh

if [ "$IFACE" = "eth0" ]; then
  ip link add vxlan0 type vxlan id 77 remote 10.100.0.4 dstport 4789 dev eth0
  ip link set up vxlan0
  ip address add 169.254.0.1/24 dev vxlan0
fi
```

- `vm-hub00` での VXLAN の設定

```
ikko@vm-hub00:~$ ip -d a show vxlan0
3: vxlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 36:13:d7:05:69:74 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 77 remote 10.100.0.4 dev eth0 srcport 0 0 dstport 4789 ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx numtxqueues 1 numrxqueues 1 gso_max_size 62780 gso_max_segs 65535
    inet 169.254.0.1/24 scope global vxlan0
       valid_lft forever preferred_lft forever
    inet6 fe80::3413:d7ff:fe05:6974/64 scope link
       valid_lft forever preferred_lft forever
```

- `vm-hub00` の FRRougin の config

10.100.0.4 だけは VXLAN 通ってほしくないので /32 で抜きます。

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
ip route 10.100.0.0/16 169.254.0.2
ip route 10.100.0.4/32 10.0.0.1
!
end
```

- `vm-hub100` での起動スクリプトでの VXLAN の設定

```
ikko@vm-hub100:~$ cat /etc/network/if-post-up.d/vxlan
#!/bin/sh

if [ "$IFACE" = "eth0" ]; then
  ip link add vxlan0 type vxlan id 77 remote 10.0.0.4 dstport 4789 dev eth0
  ip link set up vxlan0
  ip address add 169.254.0.2/24 dev vxlan0
fi
```

- `vm-hub100` の VXLAN の設定

```
ikko@vm-hub100:~$ ip -d a show vxlan0
3: vxlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 9a:f7:0f:3c:02:99 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 77 remote 10.0.0.4 dev eth0 srcport 0 0 dstport 4789 ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx numtxqueues 1 numrxqueues 1 gso_max_size 62780 gso_max_segs 65535
    inet 169.254.0.2/24 scope global vxlan0
       valid_lft forever preferred_lft forever
    inet6 fe80::98f7:fff:fe3c:299/64 scope link
       valid_lft forever preferred_lft forever
```

- `vm-hub100` の FRRouting の config

```
vm-hub100# show run
Building configuration...

Current configuration:
!
frr version 8.3.1
frr defaults traditional
hostname vm-hub100
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.10.0.0/16 169.254.0.1
!
end
```

# 結果

- `vm-hub100` のとなりにある `vm-hub101` からの疎通確認

`vm-hub100` から試すと、送信元 IP アドレスが VXLAN の 169.254.0.2 になってしまうため通信できない。

```
ikko@vm-hub101:~$ sudo ./ethr -c 10.10.0.4 -t tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.10.0.4, ip: 10.10.0.4, port: 22
Tracing route to 10.10.0.4 over 30 hops:
 1.|--10.100.0.4 [vm-hub100.internal.cloudapp.net]                           1.382ms
 2.|--???
 3.|--10.10.0.4 []                                                           112.470ms
Ethr done, measurement complete.
```

- `vm-spoke10` からの疎通確認

```
ikko@vm-spoke10:~$ sudo ./ethr -c 10.100.0.5 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.100.0.5, ip: 10.100.0.5, port: 22
Tracing route to 10.100.0.5 over 30 hops:
 1.|--10.0.0.4 []                                                            1.468ms
 2.|--???
 3.|--10.100.0.5 []                                                          105.984ms
Ethr done, measurement complete.
```

# 考慮点

上にもちょっと書いてあるんですが、`vm-hub100` から `vm-spoke10` は通信できない。
`vm-hub100` と同じ subnet にある `vm-hub101` などからは通信ができる。
Linux で Cisco の拡張 ping みたいなのができればいいんですがどうも見当たらない。

# 参考

- [Ubuntu Server 20.04 で post-up script を使う](https://zenn.dev/skmkzyk/articles/ubuntu-2004-post-up-script)
