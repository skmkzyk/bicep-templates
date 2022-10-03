param location string = 'eastasia'
param gatewayName string = 'vpngw01'
param vnetName string
param bgpAsn int = 0
param enablePrivateIpAddress bool = false
param useExisting bool = false

resource vnet01 'Microsoft.Network/virtualNetworks@2022-01-01' existing =  {
  name: vnetName

  resource GatewaySubnet 'subnets' existing = {
    name: 'GatewaySubnet'
  }
}

resource pip01 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'pip01-${gatewayName}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource pip02 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'pip02-${gatewayName}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vpngw01 'Microsoft.Network/virtualNetworkGateways@2021-08-01' = {
  name: gatewayName
  location: location
  properties: {
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: { id: pip01.id }
          subnet: { id: vnet01::GatewaySubnet.id }
        }
      }
      {
        name: 'ipconfig2'
        properties: {
          publicIPAddress: { id: pip02.id }
          subnet: { id: vnet01::GatewaySubnet.id }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive: true
    enableBgp: bgpAsn == 0 ? false : true
    bgpSettings: {
      asn: bgpAsn
    }
    enablePrivateIpAddress: enablePrivateIpAddress
  }
}

resource extVpngw01 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = if (useExisting) {
  name: gatewayName  
}

output vpngwName string = !useExisting ? vpngw01.name : extVpngw01.name
output publicIp01Name string = pip01.name
output publicIp02Name string = pip02.name
