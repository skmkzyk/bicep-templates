# Automatic VXLAN configuration by cloud-init

`cloud-init` を使って VXLAN を構成する。

# 前提条件

- VNet が 2 つある
- 2 つの VNet は VNet Peering で接続されている
- 2 つの VNet にある 2 つの Azure VM の間で VXLAN を使って通信できるようにする

# 構成のポイント

このデプロイには `parameter.json` は不要です

今回は `cloud-init` を使って複数行の `conf` ファイルみたいなやつを作成するのを試します。

vm-hub00 の方の `cloud-init` のファイルを参考までに張り付けておきます。
内容としては、[Ubuntu Server 20.04 で post-up script を使う](https://zenn.dev/skmkzyk/articles/ubuntu-2004-post-up-script) のほぼ焼き直しです。
ファイルの作成、permission の設定、そのあと実際に反映させるために仕方なく `reboot` しています。
ファイルの内容をそのまま `sh` してもいいかなという気もしますがあまり変なことをするのもあれなので素直に。

対向の vm-spoke10 の方は IP アドレスが違うくらいでほぼ違いはありません。

```cloud-init
#cloud-config
packages_update: true
packages_upgrade: true
write_files:
  - path: /etc/networkd-dispatcher/routable.d/50-ifup-hooks
    content: |
      #!/bin/sh

      for d in up post-up; do
          hookdir=/etc/network/if-${d}.d
          [ -e $hookdir ] && /bin/run-parts $hookdir
      done
      exit 0
  - path: /etc/networkd-dispatcher/off.d/50-ifdown-hooks
    content: |
      #!/bin/sh

      for d in down post-down; do
          hookdir=/etc/network/if-${d}.d
          [ -e $hookdir ] && /bin/run-parts $hookdir
      done
      exit 0
  - path: /etc/network/if-post-up.d/vxlan
    content: |
      #!/bin/sh

      if [ "$IFACE" = "eth0" ]; then
        ip link add vxlan0 type vxlan id 77 remote 10.10.0.4 dstport 4789 dev eth0
        ip link set up vxlan0
        ip address add 169.254.0.1/24 dev vxlan0
      fi
runcmd:
  - chmod +x /etc/networkd-dispatcher/routable.d/50-ifup-hooks
  - chmod +x /etc/networkd-dispatcher/off.d/50-ifdown-hooks
  - mkdir -p /etc/network/if-post-up.d
  - chmod u+x /etc/network/if-post-up.d/vxlan
  - reboot
```

構成後、Azure VM 同士は、VNet の IP アドレス (10.0.0.4 <-> 10.10.0.4) 間と、VXLAN での IP アドレス (169.254.0.1 <-> 169.254.0.2) でそれぞれ `ping` が叩けるようになるはずです。

# 結果

VNet Peering されたとなりの vm-spoke10 (10.10.0.4) との通信を確認。

```shell
ikko@vm-hub00:~$ ping -c 4 10.10.0.4
PING 10.10.0.4 (10.10.0.4) 56(84) bytes of data.
64 bytes from 10.10.0.4: icmp_seq=1 ttl=64 time=1.49 ms
64 bytes from 10.10.0.4: icmp_seq=2 ttl=64 time=1.34 ms
64 bytes from 10.10.0.4: icmp_seq=3 ttl=64 time=1.56 ms
64 bytes from 10.10.0.4: icmp_seq=4 ttl=64 time=1.27 ms

--- 10.10.0.4 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 1.271/1.415/1.559/0.116 ms
```

`vxlan0` がちゃんと生えていることを確認。

```shell
ikko@vm-hub00:~$ ip -d link show vxlan0
3: vxlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether b2:ac:1c:29:e7:0b brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 77 remote 10.10.0.4 dev eth0 srcport 0 0 dstport 4789 ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 62780 gso_max_segs 65535
```

そのうえで `vxlan0` を使って 169.254.0.2 へと `ping` が叩けることを確認。

```shell
ikko@vm-hub00:~$ ping -c 4 169.254.0.2
PING 169.254.0.2 (169.254.0.2) 56(84) bytes of data.
64 bytes from 169.254.0.2: icmp_seq=1 ttl=64 time=1.10 ms
64 bytes from 169.254.0.2: icmp_seq=2 ttl=64 time=1.03 ms
64 bytes from 169.254.0.2: icmp_seq=3 ttl=64 time=1.51 ms
64 bytes from 169.254.0.2: icmp_seq=4 ttl=64 time=1.20 ms

--- 169.254.0.2 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.028/1.209/1.505/0.181 ms
```

# 参考

- [Ubuntu Server 20.04 で post-up script を使う](https://zenn.dev/skmkzyk/articles/ubuntu-2004-post-up-script)
- [Module Reference — cloud-init 22.3 documentation](https://cloudinit.readthedocs.io/en/latest/topics/modules.html)
