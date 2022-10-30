param location string
param natGatewayName string = 'natgw01'
param zone array = []

resource pip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: 'pip-${natGatewayName}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: zone
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natgw 'Microsoft.Network/natGateways@2022-05-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  zones: zone
  properties: {
    publicIpAddresses: [
      { id: pip.id }
    ]
  }
}

output natGatewayId string = natgw.id
