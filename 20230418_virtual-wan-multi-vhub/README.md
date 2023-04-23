# Virtual WAN + vhub x5

for を大規模に使いまくった検証環境の作成の例。
ほとんどコメントアウトしてあるので必要に応じて後日こぴぺする用。

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
  // name: 'peering-vhub00-vnet200'
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
  // name: 'peering-vhub00-vnet200'
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

# ExpressRoute circuit をがッと作る

docs はここらへん。

https://learn.microsoft.com/en-us/azure/templates/microsoft.network/expressroutecircuits

# `batchSize` decorator が大事

Connection を 1 つの ExpressRoute Gateway に 2 つ以上並行して作成するとエラーになる。

docs こちら。

https://learn.microsoft.com/azure/azure-resource-manager/bicep/loops#deploy-in-batches


# FRRouting

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