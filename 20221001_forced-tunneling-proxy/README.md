# Forced tunneling and proxy but Internet access directly from Azure

強制トンネリング環境で、オンプレミスに proxy があるけど、一部の通信を Azure からインターネットに直接出す。

# 前提条件

- 強制トンネリング環境
- オンプレミスに proxy がある
- バックアップのトラフィックなど、それなりに大きなトラフィックについては Azure からインターネットに出したい

# 構成のポイント

- 強制トンネリング環境を再現するため、オンプレミス環境を模した VNet 側に ARS (Azure Route Server) を置く
- FRRouting を用いて NVA を構成し、`default-originate` を利用して `0.0.0.0/0` を経路広報する
- オンプレミス環境の proxy は Squid で構築
- 同 proxy に nginx をインストールし、proxy.pac を公開する
- proxy.pac 上で、オンプレミス proxy に向けるものと、インターネットに直接出すものを分類する
- インターネットに直接出すものに関しては UDR (User Defined Route) で `0.0.0.0/0` を上書きしている (この subnet に関しては強制トンネリングが効いていない)

# 結果

https://ifconfig.me と https://www.ugtop.com でアクセス元の IP アドレスが異なっている。
それぞれ IP が異なって見えており、proxy 経由と直接接続の差となっている。

![compare outbound IP address](./compare-outbound-ip.png)

# 考慮点

結局強制トンネリングを回避している形になるため、NSG や追加の proxy を置くなどして何らかの制限を掛けることにはなると思う。

# FRRouting config sample

強制トンネリング環境を実現するため、`neighbor x.x.x.x default-originate` を利用している。

```
root@vm-nva100:/home/ikko# vtysh

Hello, this is FRRouting (version 8.3.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

vm-nva100# show run
Building configuration...

Current configuration:
!
frr version 8.3.1
frr defaults traditional
hostname vm-nva100
log syslog informational
no ip forwarding
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.100.210.0/24 10.0.0.1
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

強制トンネリングしている状態での `show ip bgp nei x.x.x.x adv` の結果。

```
vm-nva100# show ip bgp nei 10.100.210.4 advertised-routes
BGP table version is 0, local router ID is 10.100.0.4, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

Originating default network 0.0.0.0/0

```

# proxy.pac sample

[こちら](https://findproxyforurl.com/example-pac-file/) を参考に適当に修正。
有効なのは `dnsDomainIs` のあるほんの一部分と、最後の `DIRECT` の部分のみ。

```
ikko@vm-proxy100:/var/www/html$ cat proxy.pac
function FindProxyForURL(url, host) {
    // If the hostname matches, send direct.
    // if (dnsDomainIs(host, "intranet.domain.com") ||
    //     shExpMatch(host, "(*.abcdomain.com|abcdomain.com)"))
    //     return "DIRECT";

    if (dnsDomainIs(host, "ifconfig.me")) {
        return "DIRECT";
    }

    // If the protocol or URL matches, send direct.
    // if (url.substring(0, 4) == "ftp:" ||
    //     shExpMatch(url, "http://abcdomain.com/folder/*"))
    //     return "DIRECT";

    // If the requested website is hosted within the internal network, send direct.
    // if (isPlainHostName(host) ||
    //     shExpMatch(host, "*.local") ||
    //     isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
    //     isInNet(dnsResolve(host), "172.16.0.0", "255.240.0.0") ||
    //     isInNet(dnsResolve(host), "192.168.0.0", "255.255.0.0") ||
    //     isInNet(dnsResolve(host), "127.0.0.0", "255.255.255.0"))
    //     return "DIRECT";

    // If the IP address of the local machine is within a defined
    // subnet, send to a specific proxy.
    // if (isInNet(myIpAddress(), "10.10.5.0", "255.255.255.0"))
    //     return "PROXY 1.2.3.4:8080";

    // DEFAULT RULE: All other traffic, use below proxies, in fail-over order.
    return "PROXY 10.100.0.5:3128";
}
```

Windows Server 側ではこのような設定、特に珍しいことは何もない。

![proxy settings](./proxy-settings.png)
