param vnet01Name string
param vnet02Name string
param useRemoteGateways bool = false

resource vnet01 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnet01Name
}

resource vnet02 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnet02Name
}

var vnet01Suffix = replace(vnet01Name, 'vnet-', '')
var vnet02Suffix = replace(vnet02Name, 'vnet-', '')

resource peering_hub_spoke01 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  parent: vnet01
  name: '${vnet01Suffix}-to-${vnet02Suffix}'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: { id: vnet02.id }
  }
}

resource peering_spoke01_hub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  parent: vnet02
  name: '${vnet02Suffix}-to-${vnet01Suffix}'
  properties: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: { id: vnet01.id }
    useRemoteGateways: useRemoteGateways
  }
}
