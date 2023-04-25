# Virtual WAN + vhub + DIY VNet + Branch VNet x32

for を大規模に使いまくった検証環境の作成の例。
ほとんどコメントアウトしてあるので必要に応じて後日こぴぺする用。

# ToDo

- branch から ExpressRoute 経由で戻って来た時の DIY VNet で戻りの通信用の GatewaySubnet に割り当てる User Defined Route の定義を忘れてる

  今のところ Ubuntu Server でやっているので非対称通信でもなんとかなっているが、Firewall 的な appliance の場合には通信できないと思う

- sample config #2 でたぶん `as-override` いらないと思うんだけど残っちゃってる

  再度検証するときには config を書き換えてちゃんと検証したい

# 構成案 #1

構成案 #1 は VWAN と両立せず、DIY VNet だけで構成する案。
FRRouting の sample config #1 に該当。

参考 docs はこれ。

https://learn.microsoft.com/azure/route-server/about-dual-homed-network

ARS(Azure Route Server) は AS65515 固定で動作しており、そこから NVA (Network Virtual Appliance) に見立てた Ubuntu Server で経路を受け取り、さらにもう一つの ARS に大して経路広報する必要がある。
その際、AS65515 からもらった経路をさらに AS65515 に経路広報したい、ということになるが、一般的に考えてある AS からもらった経路を (neighbor の IP アドレスが違うとはいえ) 同じ AS に経路広報する必要はないと考えられる。
実際、そのような動きになっているため、これを強制的に経路広報するような設定を入れる必要がある。
それを実現するののひとつが `as-override` という設定であり、別の AS からもらった経路の AS 番号を自分の AS 番号で書き換えて経路を広報する。
というか、書き換えることによって同じ AS 番号の neighbor に対して経路広報してくれるようになる。

docs 上でも以下のような注釈がある。

> BGP で AS パスの AS 番号を確認することによってループが回避されます。 受信ルート サーバーは、受信した BGP パケットの AS パスに自分の AS 番号が設定されている場合、そのパケットをドロップします。 この例では、どちらのルート サーバーも AS 番号は同じ 65515 です。 各ルート サーバーで他のルート サーバーからのルートが削除されるのを防ぐには、NVA と各ルート サーバーのピアリング時に、as-override の BGP ポリシーを適用する必要があります。

参考リンクはたとえばこちらとか。

https://www.n-study.com/bgp-detail/bgp-neighbor-as-override/

具体的には neighbor ごとに 1 行ずつ追加するだけ。

```
router bgp 65001
 neighbor 10.40.210.4 remote-as 65515
 !
 address-family ipv4 unicast
  neighbor 10.40.210.4 as-override <<< here >>>
```

# 構成案 #2

構成案 #2 は Virtual WAN と DIY VNet を両立させる案。
FRRouting の sample config #2 に該当。

# Azure Portal から vHub の VNet Peering を有効化した場合の REST response

docs はここらへん。

https://learn.microsoft.com/azure/templates/microsoft.network/virtualhubs/hubvirtualnetworkconnections
https://learn.microsoft.com/rest/api/virtualwan/hub-virtual-network-connections/list

```json
{
  "value": [
    {
      "etag": "W/\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"",
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualHubs/vhub00/hubVirtualNetworkConnections/conn-vhub00-vnet200",
      "name": "conn-vhub00-vnet200",
      "properties": {
        "allowHubToRemoteVnetTransit": true,
        "allowRemoteVnetToUseHubVnetGateways": true,
        "connectivityStatus": "Connected",
        "enableInternetSecurity": true,
        "provisioningState": "Succeeded",
        "remoteVirtualNetwork": {
          "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualNetworks/vnet200"
        },
        "resourceGuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "routingConfiguration": {
          "associatedRouteTable": {
            "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualHubs/vhub00/hubRouteTables/defaultRouteTable"
          },
          "propagatedRouteTables": {
            "ids": [
              {
                "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualHubs/vhub00/hubRouteTables/defaultRouteTable"
              }
            ],
            "labels": [
              "default"
            ]
          },
          "vnetRoutes": {
            "staticRoutes": [],
            "staticRoutesConfig": {
              "propagateStaticRoutes": true,
              "vnetLocalRouteOverrideCriteria": "Contains"
            }
          }
        }
      },
      "type": "Microsoft.Network/virtualHubs/hubVirtualNetworkConnections"
    }
  ]
}
```

一番シンプルには `remoteVirtualNetwork` だけで必要だろうと思って以下のような Bicep を書いた。

```bicep
resource vnet_peering_vhub 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-09-01' = {
  name: 'conn-vhub00-vnet200'
  parent: vhubs[0]
  properties: {
    remoteVirtualNetwork: {
      id: vnets[0].id
    }
  }
}
```

その場合の REST response は以下のようになるが、`enableInternetSecurity` が `false` になっている。

```json
{
  "value": [
    {
      "etag": "W/\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"",
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualHubs/vhub00/hubVirtualNetworkConnections/conn-vhub00-vnet200",
      "name": "conn-vhub00-vnet200",
      "properties": {
        "allowHubToRemoteVnetTransit": true,
        "allowRemoteVnetToUseHubVnetGateways": true,
        "connectivityStatus": "Connected",
        "enableInternetSecurity": false,
        "provisioningState": "Succeeded",
        "remoteVirtualNetwork": {
          "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualNetworks/vnet200"
        },
        "resourceGuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "routingConfiguration": {
          "associatedRouteTable": {
            "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualHubs/vhub00/hubRouteTables/defaultRouteTable"
          },
          "propagatedRouteTables": {
            "ids": [
              {
                "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Network/virtualHubs/vhub00/hubRouteTables/defaultRouteTable"
              }
            ],
            "labels": [
              "default"
            ]
          },
          "vnetRoutes": {
            "staticRoutes": [],
            "staticRoutesConfig": {
              "propagateStaticRoutes": true,
              "vnetLocalRouteOverrideCriteria": "Contains"
            }
          }
        }
      },
      "type": "Microsoft.Network/virtualHubs/hubVirtualNetworkConnections"
    }
  ]
}
```

`enableInternetSecurity: true` を追加して以下のような Bicep を書いた。

```bicep
resource vnet_peering_vhub 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-09-01' = {
  name: 'conn-vhub00-vnet200'
  parent: vhubs[0]
  properties: {
    remoteVirtualNetwork: {
      id: vnets[0].id
    }
    enableInternetSecurity: true
  }
}
```

# ExpressRoute circuit をガッと作る

docs はここらへん。

https://learn.microsoft.com/en-us/azure/templates/microsoft.network/expressroutecircuits

同じ deployment を複数走らせると、すでに AzurePrivatePeering があるといって怒るので、実質 1 回ずつしか実行しないようにする。

こんな感じで、deploy する ExpressRoute circuit の添え字を変えるようにする。

```bicep
resource circuits_diy 'Microsoft.Network/expressRouteCircuits@2022-09-01' = [for i in [16, 17, 18, 19, 20, 21]: {
```

# `batchSize` decorator が大事

Connection を 1 つの ExpressRoute Gateway に 2 つ以上並行して作成するとエラーになる。

```bicep
@batchSize(1)
resource connections_diy40 'Microsoft.Network/connections@2022-09-01' = [for i in [ 16, 17, 18, 19 ]: {
  name: 'conn-${ergws_diy[0].name}-${circuits[i].name}'
  location: location01
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: ergws_diy[0].outputs.ergwId
    }
    peer: {
      id: circuits[i].id
    }
  }
}]
```

docs こちら。

https://learn.microsoft.com/azure/azure-resource-manager/bicep/loops#deploy-in-batches

ARS (Azure Route Server) 周りでも注意が必要。

https://zenn.dev/skmkzyk/articles/fail-if-simultaneously-deployed

# ExpressRoute /30 link address

ExpressRoute の Primary と Secondary に指定する /30 の、**ネットワークアドレス + 2** の一覧。
計算するのがめんどいので /24 分全部一旦メモ。
今回 ExpressRoute 32 本引く可能性があるので、実質 172.16.0.0/24 の範囲で全部賄える。
DIY VNet は VWAN じゃなくて VNet を DIY して構成する際の、ぶら下げる VNet を示している。

| virtualcircuit | Primary | Secondary | diy-vnet |
| --- | --- | --- | --- |
| virtualcircuit100 | 172.16.2.0/30 | 172.16.6.0/30 | |
| virtualcircuit101 | 172.16.10.0/30 | 172.16.14.0/30 | |
| virtualcircuit102 | 172.16.18.0/30 | 172.16.22.0/30 | |
| virtualcircuit103 | 172.16.26.0/30 | 172.16.30.0/30 | |
| virtualcircuit104 | 172.16.34.0/30 | 172.16.38.0/30 | |
| virtualcircuit105 | 172.16.42.0/30 | 172.16.46.0/30 | |
| virtualcircuit106 | 172.16.50.0/30 | 172.16.54.0/30 | |
| virtualcircuit107 | 172.16.58.0/30 | 172.16.62.0/30 | |
| virtualcircuit108 | 172.16.66.0/30 | 172.16.70.0/30 | |
| virtualcircuit109 | 172.16.74.0/30 | 172.16.78.0/30 | |
| virtualcircuit110 | 172.16.82.0/30 | 172.16.86.0/30 | |
| virtualcircuit111 | 172.16.90.0/30 | 172.16.94.0/30 | |
| virtualcircuit112 | 172.16.98.0/30 | 172.16.102.0/30 | |
| virtualcircuit113 | 172.16.106.0/30 | 172.16.110.0/30 | |
| virtualcircuit114 | 172.16.114.0/30 | 172.16.118.0/30 | |
| virtualcircuit115 | 172.16.122.0/30 | 172.16.126.0/30 | |
| virtualcircuit116 | 172.16.130.0/30 | 172.16.134.0/30 | vnet40 |
| virtualcircuit117 | 172.16.138.0/30 | 172.16.142.0/30 | vnet40 |
| virtualcircuit118 | 172.16.146.0/30 | 172.16.150.0/30 | vnet40 |
| virtualcircuit119 | 172.16.154.0/30 | 172.16.158.0/30 | vnet40 |
| virtualcircuit120 | 172.16.162.0/30 | 172.16.166.0/30 | vnet50 |
| virtualcircuit121 | 172.16.170.0/30 | 172.16.174.0/30 | vnet50 |
| virtualcircuit122 | 172.16.178.0/30 | 172.16.182.0/30 | vnet50 |
| virtualcircuit123 | 172.16.186.0/30 | 172.16.190.0/30 | vnet50 |
| virtualcircuit124 | 172.16.194.0/30 | 172.16.198.0/30 | vnet60 |
| virtualcircuit125 | 172.16.202.0/30 | 172.16.206.0/30 | vnet60 |
| virtualcircuit126 | 172.16.210.0/30 | 172.16.214.0/30 | vnet60 |
| virtualcircuit127 | 172.16.218.0/30 | 172.16.222.0/30 | vnet60 |
| virtualcircuit128 | 172.16.226.0/30 | 172.16.230.0/30 | vnet70 |
| virtualcircuit129 | 172.16.234.0/30 | 172.16.238.0/30 | vnet70 |
| virtualcircuit130 | 172.16.242.0/30 | 172.16.246.0/30 | vnet70 |
| virtualcircuit131 | 172.16.250.0/30 | 172.16.254.0/30 | vnet70 |

# Connection Monitor の Bicep での deploy

Azure Portal でポチポチするのが苦行すぎるので Bicep で deploy しましょう。(それはそう)

```powershell
Measure-Command { az deployment group create -g NetworkWatcherRG -f main-conmon.bicep}
```

# FRRouting

- sample config #1

```
# show run
Building configuration...

Current configuration:
!
frr version 8.5
frr defaults traditional
hostname nva40
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.200.0.0/16 10.40.0.1
ip route 10.210.0.0/16 10.40.0.1
ip route 10.40.210.0/24 10.40.0.1
!
router bgp 65001
 neighbor 10.40.210.4 remote-as 65515
 neighbor 10.40.210.4 ebgp-multihop 255
 neighbor 10.40.210.5 remote-as 65515
 neighbor 10.40.210.5 ebgp-multihop 255
 neighbor 10.200.210.4 remote-as 65515
 neighbor 10.200.210.4 ebgp-multihop 255
 neighbor 10.200.210.5 remote-as 65515
 neighbor 10.200.210.5 ebgp-multihop 255
 neighbor 10.210.210.4 remote-as 65515
 neighbor 10.210.210.4 ebgp-multihop 255
 neighbor 10.210.210.5 remote-as 65515
 neighbor 10.210.210.5 ebgp-multihop 255
 !
 address-family ipv4 unicast
  neighbor 10.40.210.4 as-override
  neighbor 10.40.210.4 soft-reconfiguration inbound
  neighbor 10.40.210.4 prefix-list PRE-40 out
  neighbor 10.40.210.4 route-map rmap-bogon-asns in
  neighbor 10.40.210.4 route-map rmap-azure-asns out
  neighbor 10.40.210.5 as-override
  neighbor 10.40.210.5 soft-reconfiguration inbound
  neighbor 10.40.210.5 prefix-list PRE-40 out
  neighbor 10.40.210.5 route-map rmap-bogon-asns in
  neighbor 10.40.210.5 route-map rmap-azure-asns out
  neighbor 10.200.210.4 as-override
  neighbor 10.200.210.4 soft-reconfiguration inbound
  neighbor 10.200.210.4 prefix-list PRE-200 out
  neighbor 10.200.210.4 route-map rmap-bogon-asns in
  neighbor 10.200.210.4 route-map rmap-azure-asns out
  neighbor 10.200.210.5 as-override
  neighbor 10.200.210.5 soft-reconfiguration inbound
  neighbor 10.200.210.5 prefix-list PRE-200 out
  neighbor 10.200.210.5 route-map rmap-bogon-asns in
  neighbor 10.200.210.5 route-map rmap-azure-asns out
  neighbor 10.210.210.4 as-override
  neighbor 10.210.210.4 soft-reconfiguration inbound
  neighbor 10.210.210.4 prefix-list PRE-210 out
  neighbor 10.210.210.4 route-map rmap-bogon-asns in
  neighbor 10.210.210.4 route-map rmap-azure-asns out
  neighbor 10.210.210.5 as-override
  neighbor 10.210.210.5 soft-reconfiguration inbound
  neighbor 10.210.210.5 prefix-list PRE-210 out
  neighbor 10.210.210.5 route-map rmap-bogon-asns in
  neighbor 10.210.210.5 route-map rmap-azure-asns out
 exit-address-family
exit
!
ip prefix-list PRE-210 seq 5 deny 10.40.0.0/16
ip prefix-list PRE-210 seq 10 deny 10.200.0.0/16
ip prefix-list PRE-210 seq 15 deny 10.210.0.0/16
ip prefix-list PRE-210 seq 20 permit any
ip prefix-list PRE-200 seq 5 deny 10.40.0.0/16
ip prefix-list PRE-200 seq 10 deny 10.200.0.0/16
ip prefix-list PRE-200 seq 15 deny 10.210.0.0/16
ip prefix-list PRE-200 seq 20 permit any
ip prefix-list PRE-40 seq 5 deny 10.40.0.0/16
ip prefix-list PRE-40 seq 10 deny 10.116.0.0/16
ip prefix-list PRE-40 seq 15 deny 10.117.0.0/16
ip prefix-list PRE-40 seq 20 deny 10.118.0.0/16
ip prefix-list PRE-40 seq 25 deny 10.119.0.0/16
ip prefix-list PRE-40 seq 30 permit any
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

- sample config #2

```
nva40# show run
Building configuration...

Current configuration:
!
frr version 8.5
frr defaults traditional
hostname nva40
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.200.0.0/16 10.40.0.1
ip route 10.210.0.0/16 10.40.0.1
ip route 10.220.0.0/16 10.40.0.1
ip route 10.40.210.0/24 10.40.0.1
!
router bgp 65001
 neighbor 10.40.210.4 remote-as 65515
 neighbor 10.40.210.4 ebgp-multihop 255
 neighbor 10.40.210.5 remote-as 65515
 neighbor 10.40.210.5 ebgp-multihop 255
 !
 address-family ipv4 unicast
  redistribute static
  neighbor 10.40.210.4 as-override
  neighbor 10.40.210.4 soft-reconfiguration inbound
  neighbor 10.40.210.4 prefix-list PRE-40 out
  neighbor 10.40.210.4 route-map rmap-bogon-asns in
  neighbor 10.40.210.4 route-map rmap-azure-asns out
  neighbor 10.40.210.5 as-override
  neighbor 10.40.210.5 soft-reconfiguration inbound
  neighbor 10.40.210.5 prefix-list PRE-40 out
  neighbor 10.40.210.5 route-map rmap-bogon-asns in
  neighbor 10.40.210.5 route-map rmap-azure-asns out
 exit-address-family
exit
!
ip prefix-list PRE-200 seq 5 permit 10.116.0.0/16
ip prefix-list PRE-200 seq 10 permit 10.117.0.0/16
ip prefix-list PRE-200 seq 15 permit 10.118.0.0/16
ip prefix-list PRE-200 seq 20 permit 10.119.0.0/16
ip prefix-list PRE-200 seq 25 deny any
ip prefix-list PRE-40 seq 5 permit 10.200.0.0/16
ip prefix-list PRE-40 seq 10 permit 10.210.0.0/16
ip prefix-list PRE-40 seq 15 permit 10.220.0.0/16
ip prefix-list PRE-40 seq 20 deny any
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
