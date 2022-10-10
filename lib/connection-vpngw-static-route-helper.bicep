param location string = 'eastasia'
param vnet02Name string = 'vnet02'
param pipGateway02Name string = 'pip-vpngw02'
param vpnGateway01Name string = 'vpngw01'
param vpnGateway02Name string = 'vpngw02'
param connection01Name string = 'conn-vpngw01'
@secure()
param psk string

resource vnet02 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnet02Name
}

resource vpngw01 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = {
  name: vpnGateway01Name
}

resource pip_vpngw02 'Microsoft.Network/publicIPAddresses@2022-01-01' existing = {
  name: pipGateway02Name
}

resource lng_vpngw02 'Microsoft.Network/localNetworkGateways@2022-01-01' = {
  name: 'lng-${vpnGateway02Name}-${vpnGateway01Name}'
  location: location
  properties: {
    gatewayIpAddress: pip_vpngw02.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: vnet02.properties.addressSpace.addressPrefixes
    }
  }
}

resource connection01 'Microsoft.Network/connections@2022-01-01' = {
  name: connection01Name
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: vpngw01.id
    }
    connectionProtocol: 'IKEv2'
    localNetworkGateway2: {
      id: lng_vpngw02.id
    }
    sharedKey: psk
  }
}
