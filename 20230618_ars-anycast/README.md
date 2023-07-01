# Anycast multi-region load balancing

GitHub に載っている multi-region load balancing の例を試してみます。
気づいたら 1 つの region にすべての VNet を配置しており multi-region になっていないのですが、まぁ実質同じなのでもうこのままで置いておきますごめんなさい。

# 構成のポイント

- ARS + NVA を用いて、Anycast での multi-region load balancing を実現する
  - Anycast に利用する IP アドレス (今回の例では `9.9.9.9`) は実際の設計においては変えた方がいいはずです
  - AS-PATH を利用した Active-Standby 構成の方があり得るのかもしれませんが、とりあえずは同じ AS-PATH になっています
    - そのため、オンプレミスを模した VNet にある ExpressRoute Gateway によって適当に load balancing されています
- 2 つの VNet に ARS + NVA + Web サーバを置いてあります
  - それぞれ vm-web00 と vm-web10 が最終的な backend の Web サーバになっていて、返す html ファイルを若干編集してそれが分かるようにしてあります
  - 本来はこの 2 つの VNet が別々の region にある想定です
  - 参考にした GitHub では NVA として動作させるため ExaBGP を利用していますが、お気に入りの FRRouting に変更しています
  - Reverse proxy として使用している haproxy も nginx でもいいかと思っています
- 3 番目の VNet がオンプレミスを模した環境になっており、上の 2 つの VNet とはそれぞれ別の ExpressRoute circuit で接続されています
  - この VNet の region はどこでもいいです
  - 今回の話とかは関係ないですがこの状態でも 2 つの VNet は 3 番目の VNet で折り返して通信することはできません
    - 折り返して通信したい場合には 2 つの ExpressRoute circuit 間で Global Reach を有効にする必要があります

# 結果

いくつかの障害・復旧パターンを見てみます。
前述のとおり traffic をどちらにも寄せていないため、定常状態では vm-web00 と vm-web10 に分散されています。
障害発生時には vm-web00 側への到達性を無くすため、vm-web10 だけがログに表示される想定です。

ログの出力においては少しわかりづらくなっていますが、以下の 2 つのコマンドの出力が混ざっています。
まず、`curl` の接続待ちがどれほどあるのかがわかりやすくなるように ``while :; do echo "========== `date` =========="; sleep 1; done &`` を事前に実行してあります。
これにより、どんな状態であってもとりあえず 1 秒ごとに時刻を含んだログが出力されます。
そして、メインのログ出力は ``while :; do echo "========== `date` =========="; curl -s -v http://9.9.9.9 2>&1| grep -e '^\* ' -e 'vm-web'; sleep 0.5; done`` です。
これにより 0.5sec の間隔をあけて `curl` を実行しています。
この 2 つの組み合わせにより、`curl` が `*   Trying 9.9.9.9:80...` で止まっている様子がわかりやすくなっているかと思います。
定常状態では、時刻を示す行が重複していて若干わかりづらい部分もありますがまぁ気にしないでおきます。

## Connection resource を削除した場合

障害のシミュレーションとして、Connection resource を削除して region を切り離してみます。
ログは後ろの方に貼っておきますが、30 秒程度の断があるように思います。
ただしこれは 1 つの HTTP 接続においての話であり、リトライまでの間隔により変化しますし、複数の HTTP 接続がある場合にはそれぞれが別の事象を経験するはずです。

## Connection resource を再度作成した場合

同じ folder にある `reconnect-connection.bicep` を利用して Connection resource を再度作成してみます。
他の resource を変更しないようにするため、専用の bicep ファイルを用意しています。
再接続の際にはあまり影響はないのかと思っていたのですが、Azure 内部の動作によるのか削除時と同様 30 秒程度の断があるようです。

## FRRouting を stop した場合

`vm-nva00` にて `systemctl stop frr` を実行し、BGP daemon を落としてみます。
こちらに関してはかなりスピードが速く Network is unreachable が何回かかえってくるものの数秒で切り替わります。

## FRRouting を start した場合

同様に `systemctl start frr` を実行して BGP daemon を起動してみます。
こちらに関しては何も気づけるような変化はなく、気づいたら vm-web00 にも load balancing されているという感じです。

# 参考

- adstuart/azure-routeserver-anycast: Use Azure Route Server for multi-region Anycast load balancing within private networks

  https://github.com/adstuart/azure-routeserver-anycast

# sample config

使用した FRRouting と haproxy の config を以下に貼っておきます。

## FRRouting config

`interface lo` に anycast 用の IP アドレスを付与し、BGP で経路広報しています。
10.0.210.4 と 10.0.210.5 は Azure Route Server の IP アドレスです。
いくつか `route-map` がありますが、ほかの config からの流用です。

```
vm-nva00# show run
Building configuration...

Current configuration:
!
frr version 8.5.2
frr defaults traditional
hostname vm-nva00
log syslog informational
no ip forwarding
no ipv6 forwarding
service integrated-vtysh-config
!
interface lo
 ip address 9.9.9.9/32
exit
!
router bgp 65001
 neighbor 10.0.210.4 remote-as 65515
 neighbor 10.0.210.4 ebgp-multihop 255
 neighbor 10.0.210.5 remote-as 65515
 neighbor 10.0.210.5 ebgp-multihop 255
 !
 address-family ipv4 unicast
  network 9.9.9.9/32
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

## haproxy config

GitHub に書かれていたものを、ほぼそのまま既存の config に追記しています。
IP アドレスだけは環境に合うよう変更しています。

```
$ diff -u /etc/haproxy/haproxy.cfg.org /etc/haproxy/haproxy.cfg
--- /etc/haproxy/haproxy.cfg.org        2023-03-22 21:18:54.000000000 +0000
+++ /etc/haproxy/haproxy.cfg    2023-07-01 06:47:28.842734008 +0000
@@ -32,3 +32,12 @@
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http
+
+frontend http_front
+       bind    *:80
+       stats   uri /haproxy?stats
+       default_backend http_back
+
+backend http_back
+       balance roundrobin
+       server  backend01 10.0.0.20:80 check
```

# ログ

## Connection resource を削除した場合

```
========== Sat Jul  1 09:16:18 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:16:19 UTC 2023 ==========
========== Sat Jul  1 09:16:19 UTC 2023 ==========
*   Trying 9.9.9.9:80...
========== Sat Jul  1 09:16:20 UTC 2023 ==========
========== Sat Jul  1 09:16:21 UTC 2023 ==========
========== Sat Jul  1 09:16:22 UTC 2023 ==========
========== Sat Jul  1 09:16:23 UTC 2023 ==========
========== Sat Jul  1 09:16:24 UTC 2023 ==========
========== Sat Jul  1 09:16:25 UTC 2023 ==========
========== Sat Jul  1 09:16:26 UTC 2023 ==========
========== Sat Jul  1 09:16:27 UTC 2023 ==========
========== Sat Jul  1 09:16:28 UTC 2023 ==========
========== Sat Jul  1 09:16:29 UTC 2023 ==========
========== Sat Jul  1 09:16:30 UTC 2023 ==========
========== Sat Jul  1 09:16:31 UTC 2023 ==========
========== Sat Jul  1 09:16:32 UTC 2023 ==========
========== Sat Jul  1 09:16:33 UTC 2023 ==========
========== Sat Jul  1 09:16:34 UTC 2023 ==========
========== Sat Jul  1 09:16:35 UTC 2023 ==========
========== Sat Jul  1 09:16:36 UTC 2023 ==========
========== Sat Jul  1 09:16:37 UTC 2023 ==========
========== Sat Jul  1 09:16:38 UTC 2023 ==========
========== Sat Jul  1 09:16:39 UTC 2023 ==========
========== Sat Jul  1 09:16:40 UTC 2023 ==========
========== Sat Jul  1 09:16:41 UTC 2023 ==========
========== Sat Jul  1 09:16:42 UTC 2023 ==========
========== Sat Jul  1 09:16:43 UTC 2023 ==========
========== Sat Jul  1 09:16:44 UTC 2023 ==========
========== Sat Jul  1 09:16:45 UTC 2023 ==========
========== Sat Jul  1 09:16:46 UTC 2023 ==========
========== Sat Jul  1 09:16:47 UTC 2023 ==========
========== Sat Jul  1 09:16:48 UTC 2023 ==========
========== Sat Jul  1 09:16:49 UTC 2023 ==========
========== Sat Jul  1 09:16:50 UTC 2023 ==========
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:16:51 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
========== Sat Jul  1 09:16:51 UTC 2023 ==========
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:16:51 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:16:52 UTC 2023 ==========
========== Sat Jul  1 09:16:52 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:16:53 UTC 2023 ==========
*   Trying 9.9.9.9:80...
========== Sat Jul  1 09:16:53 UTC 2023 ==========
========== Sat Jul  1 09:16:54 UTC 2023 ==========
========== Sat Jul  1 09:16:55 UTC 2023 ==========
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 3042 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:16:56 UTC 2023 ==========
========== Sat Jul  1 09:16:56 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 3 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:16:57 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:16:57 UTC 2023 ==========
========== Sat Jul  1 09:16:57 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:16:58 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 32 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:16:58 UTC 2023 ==========
========== Sat Jul  1 09:16:58 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:16:59 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
```

## Connection resource を再度作成した場合

```
========== Sat Jul  1 09:27:23 UTC 2023 ==========
========== Sat Jul  1 09:27:24 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:27:24 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:27:24 UTC 2023 ==========
========== Sat Jul  1 09:27:25 UTC 2023 ==========
*   Trying 9.9.9.9:80...
========== Sat Jul  1 09:27:25 UTC 2023 ==========
========== Sat Jul  1 09:27:26 UTC 2023 ==========
========== Sat Jul  1 09:27:27 UTC 2023 ==========
========== Sat Jul  1 09:27:28 UTC 2023 ==========
========== Sat Jul  1 09:27:29 UTC 2023 ==========
========== Sat Jul  1 09:27:30 UTC 2023 ==========
========== Sat Jul  1 09:27:31 UTC 2023 ==========
========== Sat Jul  1 09:27:32 UTC 2023 ==========
========== Sat Jul  1 09:27:33 UTC 2023 ==========
========== Sat Jul  1 09:27:35 UTC 2023 ==========
========== Sat Jul  1 09:27:36 UTC 2023 ==========
========== Sat Jul  1 09:27:37 UTC 2023 ==========
========== Sat Jul  1 09:27:38 UTC 2023 ==========
========== Sat Jul  1 09:27:39 UTC 2023 ==========
========== Sat Jul  1 09:27:40 UTC 2023 ==========
========== Sat Jul  1 09:27:41 UTC 2023 ==========
========== Sat Jul  1 09:27:42 UTC 2023 ==========
========== Sat Jul  1 09:27:43 UTC 2023 ==========
========== Sat Jul  1 09:27:44 UTC 2023 ==========
========== Sat Jul  1 09:27:45 UTC 2023 ==========
========== Sat Jul  1 09:27:46 UTC 2023 ==========
========== Sat Jul  1 09:27:47 UTC 2023 ==========
========== Sat Jul  1 09:27:48 UTC 2023 ==========
========== Sat Jul  1 09:27:49 UTC 2023 ==========
========== Sat Jul  1 09:27:50 UTC 2023 ==========
========== Sat Jul  1 09:27:51 UTC 2023 ==========
========== Sat Jul  1 09:27:52 UTC 2023 ==========
========== Sat Jul  1 09:27:53 UTC 2023 ==========
========== Sat Jul  1 09:27:54 UTC 2023 ==========
========== Sat Jul  1 09:27:55 UTC 2023 ==========
========== Sat Jul  1 09:27:56 UTC 2023 ==========
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:27:57 UTC 2023 ==========
========== Sat Jul  1 09:27:57 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:27:57 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:27:58 UTC 2023 ==========
========== Sat Jul  1 09:27:58 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:27:58 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:27:59 UTC 2023 ==========
========== Sat Jul  1 09:27:59 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:27:59 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
```

## FRRouting を stop した場合

```
========== Sat Jul  1 09:43:26 UTC 2023 ==========
========== Sat Jul  1 09:43:26 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:26 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 3 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:43:27 UTC 2023 ==========
========== Sat Jul  1 09:43:27 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:27 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:28 UTC 2023 ==========
========== Sat Jul  1 09:43:28 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 2 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:43:28 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:29 UTC 2023 ==========
========== Sat Jul  1 09:43:29 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 2 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:43:30 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:30 UTC 2023 ==========
========== Sat Jul  1 09:43:30 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:31 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* connect to 9.9.9.9 port 80 failed: Network is unreachable
* Failed to connect to 9.9.9.9 port 80 after 2 ms: Network is unreachable
* Closing connection 0
========== Sat Jul  1 09:43:31 UTC 2023 ==========
========== Sat Jul  1 09:43:31 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:32 UTC 2023 ==========
========== Sat Jul  1 09:43:32 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:32 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:33 UTC 2023 ==========
========== Sat Jul  1 09:43:33 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:33 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:34 UTC 2023 ==========
========== Sat Jul  1 09:43:34 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:35 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:43:35 UTC 2023 ==========
========== Sat Jul  1 09:43:35 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
```

## FRRouting を start した場合

```
========== Sat Jul  1 09:45:20 UTC 2023 ==========
========== Sat Jul  1 09:45:21 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:45:21 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:45:21 UTC 2023 ==========
========== Sat Jul  1 09:45:22 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:45:22 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:45:22 UTC 2023 ==========
========== Sat Jul  1 09:45:23 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web10)</h1>
========== Sat Jul  1 09:45:23 UTC 2023 ==========
========== Sat Jul  1 09:45:23 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
========== Sat Jul  1 09:45:24 UTC 2023 ==========
*   Trying 9.9.9.9:80...
* Connected to 9.9.9.9 (9.9.9.9) port 80 (#0)
* Mark bundle as not supporting multiuse
* Connection #0 to host 9.9.9.9 left intact
<h1>Welcome to nginx! (vm-web00)</h1>
```