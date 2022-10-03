param location string
param routeServerName string
param vnetName string
param useExisting bool = false
param bgpConnections array = []

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  parent: vnet
  name: 'RouteServerSubnet'
}

resource pip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${routeServerName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource rs 'Microsoft.Network/virtualHubs@2022-01-01' = if (!useExisting) {
  name: routeServerName
  location: location
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
  }

  resource ipconfig 'ipConfigurations' = if (!useExisting) {
    name: 'ipconfig'
    properties: {
      publicIPAddress: { id: pip.id }
      subnet: { id: subnet.id }
    }
  }
}

@batchSize(1)
resource bgp_conn 'Microsoft.Network/virtualHubs/bgpConnections@2022-01-01' = [for peer in bgpConnections: {
  parent: rs
  name: peer.name
  properties: {
    peerIp: peer.ip
    peerAsn: peer.asn
  }
  dependsOn: [
    rs::ipconfig
  ]
}]
