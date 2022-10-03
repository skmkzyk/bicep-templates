# Communication for spoke-hub-hub-spoke by ExpressRoute

複数の Hub-spoke があった場合に、その spoke 間の通信を ExpressRoute 折り返しで実現させるという話。

# 構成のポイント

とくに難しいポイントは何もなく、シンプルに作成するのみです。

- Hub-spoke を複数作成する
- Hub には ExpressRoute Gateway を置く
- 1 つの Express Circuit に対して、2 つの Hub の 2 つの ExpressRoute Gateway を接続する

# 結果

[Microsoft/Ethr](https://github.com/Microsoft/Ethr) を使って、各所に通信ができるかを確認します。
以下のそれぞれの結果は、spoke から実行しています。

```
ikko@vm-spoke10:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0d:3a:80:c4:aa brd ff:ff:ff:ff:ff:ff
    inet 10.10.0.4/24 brd 10.10.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::20d:3aff:fe80:c4aa/64 scope link
       valid_lft forever preferred_lft forever
```

すぐ隣の hub 宛ての通信確認。

```
ikko@vm-spoke10:~$ sudo ./ethr -c 10.0.0.4 -p tcp --port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.0.0.4, ip: 10.0.0.4, port: 22
Tracing route to 10.0.0.4 over 30 hops:
 1.|--10.0.0.4 []                                                            2.730ms
Ethr done, measurement complete.
```

ExpressRoute 経由で別の hub 宛ての通信確認。

```
ikko@vm-spoke10:~$ sudo ./ethr -c 10.100.0.4 -p tcp --port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.100.0.4, ip: 10.100.0.4, port: 22
Tracing route to 10.100.0.4 over 30 hops:
 1.|--???
 2.|--10.100.0.4 []                                                          102.212ms
Ethr done, measurement complete.
```

ExpressRoute 経由で別の hub、の配下の spoke への通信確認。

```
ikko@vm-spoke10:~$ sudo ./ethr -c 10.110.0.4 -p tcp --port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.110.0.4, ip: 10.110.0.4, port: 22
Tracing route to 10.110.0.4 over 30 hops:
 1.|--???
 2.|--10.110.0.4 []                                                          101.213ms
Ethr done, measurement complete.
```

なお 1 つの hub に対する spoke 間は規定では通信できません。
これを実現するためには、UDR で「もう片方の spoke の IP アドレス → Virtual Network Gateway」などと構成する案があります。

```
ikko@vm-spoke10:~$ sudo ./ethr -c 10.20.0.4 -p tcp --port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.20.0.4, ip: 10.20.0.4, port: 22
Tracing route to 10.20.0.4 over 30 hops:
 1.|--???
 2.|--???
 3.|--???
 4.|--???
 5.|--???
Ethr done, duration: 10s.
Hint: Use -d parameter to change duration of the test.
```

# 考慮点

ExpressRoute Circuit 折り返しの通信は非推奨という記載が出てきています。

> 1 つまたは複数の ExpressRoute 回線が複数の仮想ネットワークに接続されている場合、仮想ネットワーク間のトラフィックは ExpressRoute 経由でルーティングできます。 ただし、これは推奨されません。 仮想ネットワーク間の接続を有効にするには、仮想ネットワーク ピアリングを構成します。
>
> [Azure ExpressRoute: ディザスター リカバリーの設計 | Microsoft Learn](https://learn.microsoft.com/ja-jp/azure/expressroute/designing-for-disaster-recovery-with-expressroute-privatepeering)

帯域に制限がある場合や、2 つの Hub-spoke 構成と ExpressRoute circuit とのが別のリージョンであり latency が大きくなる場合にはこの構成は非推奨になるかと思います。
ただ、そこまで通信量が大きくなければ問題はありません。

なお、今回達成しようとしている通信は、そもそも Hub 間を VNet Peering で接続しても実現はできません。

# 参考

- [複数の Hub-spoke アーキテクチャで spoke-to-spoke を実現する (ExpressRoute 利用)](https://zenn.dev/skmkzyk/articles/multiple-hub-spoke-expressroute)