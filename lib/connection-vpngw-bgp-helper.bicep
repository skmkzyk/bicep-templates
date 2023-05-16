param location string
param pipGateway02Name string = 'pip-vpngw02'
param vpnGateway01Name string = 'vpngw01'
param vpnGateway02Name string = 'vpngw02'
param connection01Name string = 'conn-vpngw01'
param enablePrivateIpAddress bool = false
@secure()
param psk string

resource vpngw01 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = {
  name: vpnGateway01Name
}

resource vpngw02 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = {
  name: vpnGateway02Name
}

resource pip_vpngw02 'Microsoft.Network/publicIPAddresses@2022-01-01' existing = {
  name: pipGateway02Name
}

var VpnGw02Ip = enablePrivateIpAddress ? vpngw02.properties.ipConfigurations[0].properties.privateIPAddress : pip_vpngw02.properties.ipAddress

resource lng_vpngw02 'Microsoft.Network/localNetworkGateways@2022-01-01' = {
  name: 'lng-${vpnGateway02Name}'
  location: location
  properties: {
    gatewayIpAddress: VpnGw02Ip
    bgpSettings: {
      asn: vpngw02.properties.bgpSettings.asn
      bgpPeeringAddress: split(vpngw02.properties.bgpSettings.bgpPeeringAddress, ',')[0]
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
    enableBgp: true
    useLocalAzureIpAddress: enablePrivateIpAddress
  }
}
