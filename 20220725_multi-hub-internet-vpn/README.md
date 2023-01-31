# Communication for spoke-hub-hub-spoke by Internet VPN

複数の Hub-spoke があった場合に、その spoke 間の通信を VPN Gateway を利用したインターネット VPN で実現させるという話。

## 複数の Hub-spoke の離れた spoke 同士で通信を可能にしようシリーズ

- ExpressRoute circuit 折り返し
  - https://github.com/skmkzyk/bicep-templates/tree/main/20220726_multi-hub-expressroute
- Internet VPN 折り返し
  - https://github.com/skmkzyk/bicep-templates/tree/main/20220725_multi-hub-internet-vpn
- Private IP VPN 折り返し
  - 後で書く

# 構成のポイント

シンプルに作るだけ。

- hub-spoke 構成を 2 セット作成する
- それぞれにはふたつの spoke がある
- hub にはそれぞれ VPN Gateway を作成
- このふたつの VPN Gateway の間で IPsec VPN と BGP を構成する
- Remote Gateway を有効化した VNet Peering を作る際に、hub 側に VPN Gateway ができてないと失敗するので、明示的な `dependsOn` が入っています

ちなみに以下の状態になっています。

- hub 同士は VNet Peering でつながっているわけではない、つないでもできるけど
- hub 同士は ExpressRoute でつながっているわけではない、つないでもいいけど

# 結果

以下の Azure VM に Bastion でログインした後、各 Azure VM へ 22/tcp で traceroute をとります。
この Azure VM は hub00 の配下の spoke のひとつ、spoke10 (10.10.0.0/16) に配置されています。

```shell
ikko@vm-spoke10:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:22:48:69:0e:81 brd ff:ff:ff:ff:ff:ff
    inet 10.10.0.4/24 brd 10.10.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::222:48ff:fe69:e81/64 scope link
       valid_lft forever preferred_lft forever
```

spoke10 に直接接続されている hub00 にある Azure VM 宛てはもちろん通ります。

```shell
ikko@vm-spoke10:~$ sudo ./ethr -c 10.0.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.0.0.4, ip: 10.0.0.4, port: 22
Tracing route to 10.0.0.4 over 30 hops:
 1.|--10.0.0.4 []                                                            3.110ms
Ethr done, measurement complete.
```

spoke10 から hub00 を経由しての spoke20 は経路がないため通信できません。
これを可能とするためには追加の UDR が必要です。

```shell
ikko@vm-spoke10:~$ sudo ./ethr -c 10.20.0.4 -p tcp -port 22 -t tr

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

spoke10 から hub00 を経由して hub100 にある Azure VM へは通ります。
hub00 から hub100 に通る部分の 1 hop が見えないのはちょっと不思議だなと思いますね。

```shell
ikko@vm-spoke10:~$ sudo ./ethr -c 10.100.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.100.0.4, ip: 10.100.0.4, port: 22
Tracing route to 10.100.0.4 over 30 hops:
 1.|--10.100.0.4 []                                                          9.730ms
Ethr done, measurement complete.
```

同様にその spoke である spoke110 と spoke120 にある Azure VM へも通信可能です。

```shell
ikko@vm-spoke10:~$ sudo ./ethr -c 10.110.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.110.0.4, ip: 10.110.0.4, port: 22
Tracing route to 10.110.0.4 over 30 hops:
 1.|--10.110.0.4 []                                                          7.440ms
Ethr done, measurement complete.
```

```shell
ikko@vm-spoke10:~$ sudo ./ethr -c 10.120.0.4 -p tcp -port 22 -t tr

Ethr: Comprehensive Network Performance Measurement Tool (Version: v1.0.0)
Maintainer: Pankaj Garg (ipankajg @ LinkedIn | GitHub | Gmail | Twitter)

Using destination: 10.120.0.4, ip: 10.120.0.4, port: 22
Tracing route to 10.120.0.4 over 30 hops:
 1.|--10.120.0.4 []                                                          9.009ms
Ethr done, measurement complete.
```

# 参考

- [複数の Hub-spoke アーキテクチャで spoke-to-spoke を実現する (Internet VPN 利用)](https://zenn.dev/microsoft/articles/multiple-hub-spoke-internet-vpn)
