# Establish peer between FRRouting and ARS by `cloud-init`

FRRouting と Azure Route Server (ARS) との間の BGP peer を `cloud-init` で自動設定してしまおう、という話

# 構成のポイント

config は固まっていたので、`cloud-init.yml` に書いてそのまま実行するだけ。

# 動作確認

FRRouting の config が入っているはずなので、ARS との BGP peer の確認と、advertised/received route を確認しておきます。

```
ikko@vm-nva00:~$ sudo -s

root@vm-nva00:/home/ikko# vtysh

Hello, this is FRRouting (version 8.3.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

vm-nva00# show ip bgp sum

IPv4 Unicast Summary (VRF default):
BGP router identifier 10.0.0.4, local AS number 65001 vrf-id 0
BGP table version 2
RIB entries 1, using 192 bytes of memory
Peers 2, using 1447 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
10.0.210.4      4      65515        20        17        0    0    0 00:15:29            1        0 N/A
10.0.210.5      4      65515        20        17        0    0    0 00:15:29            1        0 N/A

Total number of neighbors 2

vm-nva00# show ip bgp nei 10.0.210.4 advertised-routes

vm-nva00# show ip bgp nei 10.0.210.4 received
BGP table version is 2, local router ID is 10.0.0.4, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.0.0/16      10.0.210.4                             0 65515 i

Total number of prefixes 1
```
