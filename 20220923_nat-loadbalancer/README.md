# Hub-Spoke communication without remote gateway setting via Private Link Service and Private Endpoint

諸事情あって Remote Gateway が使えない Hub-Spoke 構成において、ExpressRoute 越しで通信させたい。

# 前提条件

- Hub-Spoke の構成ではあるものの、Spoke 側に ExpressRoute Gateway があり、Remote Gateway の設定が使えない
- そのため、VNet Peering している VNet の IP アドレス帯が ExpressRoute の BGP で広報されてこない

という状態で、拠点を想定した ExpressRoute で接続された VNet から Spoke の VM へと通信を確立したい。

# 構成のポイント

- Spoke 側の VM の前に Standard LB を配置し、Private Link Service を作成する
- 作成した Private Link Service に対して Hub 側で Private Endpoint を作成する
- VNet Peering しているものの、それに対してさらに Private Link Service & Private Endpoint を構成する

単に Bicep で Private Link Service & Private Endpoint を構成する練習になった気もする。

- Backend が Ubuntu Server 20.04 のため Health probe はあまり考えず SSH (22/tcp) を指定している
- `parameter.json` には ExpressRoute circuit の Resource ID と authorizationKey を 2 つ与える必要がある

# 結果

まずは [Microsoft/Ethr](https://github.com/Microsoft/Ethr) を利用して通信経路を念のため確認しておきます。
とくに不思議なことはなく、相変わらず返事が返ってこない ExpressRoute Gateway らしき ??? と、相手の 10.0.0.4 が見えています。

```shell
ikko@vm-hub100:~$ sudo ./ethr -c 10.0.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.0.0.4, ip: 10.0.0.4, port: 22
Tracing route to 10.0.0.4 over 30 hops:
 1.|--???
 2.|--10.0.0.4 []                                                            92.431ms
Ethr done, measurement complete.
```

こちらは Private Endpoint 宛てですが、見た目上は 10.0.0.4 宛ての通信確認と変わりません。

```shell
ikko@vm-hub100:~$ sudo ./ethr -c 10.0.0.5 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.0.0.5, ip: 10.0.0.5, port: 22
Tracing route to 10.0.0.5 over 30 hops:
 1.|--???
 2.|--10.0.0.5 []                                                            95.407ms
Ethr done, measurement complete.
```

10.0.0.4 に対して SSH し、リモートで `hostname` および `ip a` コマンドを実行し、相手サーバが何であるかを明示的に確認します。
こちらは Private Link Service とは関係ないですが、ExpressRoute 越しのとなりの VNet にある VM であることがわかります。

```shell
ikko@vm-hub100:~$ ssh 10.0.0.4 'hostname; ip a'
vm-hub00
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:81:a2:b6 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.4/24 brd 10.0.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe81:a2b6/64 scope link
       valid_lft forever preferred_lft forever
```

こちらが本命です。
10.0.0.5 という ExpressRoute 越しのとなりの VNet の IP アドレスに SSH しているようですが、実態としてはその先の 10.10.0.4 に対して SSH していることがわかります。
これは Private Link Service およびそれに対応した Private Endpoint を経由して通信しています。
これにより、一種の NAT 越しではありますが、Remote Gateway の設定なし (設定できない環境) でも Hub-Spoke の Spoke 側への到達性を実現できます。

```shell
ikko@vm-hub100:~$ ssh 10.0.0.5 'hostname; ip a'
vm-spoke10
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:85:7d:a3 brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.4/24 brd 10.10.10.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe85:7da3/64 scope link
       valid_lft forever preferred_lft forever
```

# 考慮点

NAT を利用した構成のため、双方向通信はできない。

# 参考

- VXLAN を利用した解決方法で、NAT を利用しないため双方向通信が可能

https://github.com/skmkzyk/bicep-templates/tree/main/20221006_hub-spoke-wo-remote-gw-vxlan