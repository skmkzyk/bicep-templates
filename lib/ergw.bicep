param location string = 'eastasia'
param gatewayName string = 'ergw01'
param vnetName string
param useExisting bool = false

resource vnet01 'Microsoft.Network/virtualNetworks@2022-01-01' existing =  {
  name: vnetName

  resource GatewaySubnet 'subnets' existing = {
    name: 'GatewaySubnet'
  }
}

resource pip01 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'pip-${gatewayName}'
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

resource ergw01 'Microsoft.Network/virtualNetworkGateways@2021-08-01' = if (!useExisting) {
  name: gatewayName
  location: location
  properties: {
    sku: {
      name: 'ErGw1AZ'
      tier: 'ErGw1AZ'
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: { id: pip01.id }
          subnet: { id: vnet01::GatewaySubnet.id }
        }
      }
    ]
    gatewayType: 'ExpressRoute'
  }
}

resource extErgw01 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = if (useExisting) {
  name: gatewayName  
}

output ergwName string = !useExisting ? ergw01.name : extErgw01.name
output ergwId string = !useExisting ? ergw01.id : extErgw01.id
output publicIpName string = pip01.name
