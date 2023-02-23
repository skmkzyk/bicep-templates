param location string = 'eastasia'
param bastionName string = ''
param vnetName string

var vnetSuffix = replace(vnetName, 'vnet-', '')
var _bastionName = bastionName != '' ? bastionName : 'bast-${vnetSuffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName

  resource azureBastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'pip-${_bastionName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bast01 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: _bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    scaleUnits: 2
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet::azureBastionSubnet.id }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
}
