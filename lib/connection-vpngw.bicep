param vpnGateway01Name string = 'vpngw01'
param vpnGateway02Name string = 'vpngw02'
param connection01Name string = ''
param connection02Name string = ''
param enableBgp bool = false
param enablePrivateIpAddress bool = false
@secure()
param psk string

var _connection01Name = !empty(connection01Name) ? connection01Name : 'conn-${vpnGateway01Name}-${vpnGateway02Name}'
var _connection02Name = !empty(connection02Name) ? connection02Name : 'conn-${vpnGateway02Name}-${vpnGateway01Name}'

resource vnet01 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: split(vpngw01.properties.ipConfigurations[0].properties.subnet.id, '/')[8]
}

resource pip_vpngw01 'Microsoft.Network/publicIPAddresses@2022-01-01' existing = {
  name: split(vpngw01.properties.ipConfigurations[0].properties.publicIPAddress.id, '/')[8]
}

resource vpngw01 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = {
  name: vpnGateway01Name
}

resource vnet02 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: split(vpngw02.properties.ipConfigurations[0].properties.subnet.id, '/')[8]
}

resource pip_vpngw02 'Microsoft.Network/publicIPAddresses@2022-01-01' existing = {
  name: split(vpngw02.properties.ipConfigurations[0].properties.publicIPAddress.id, '/')[8]
}

resource vpngw02 'Microsoft.Network/virtualNetworkGateways@2022-01-01' existing = {
  name: vpnGateway02Name
}

module connection01_bgp 'connection-vpngw-bgp-helper.bicep' = if (enableBgp) {
  name: '${_connection01Name}-bgp-helper'
  params: {
    location: vpngw01.location
    connection01Name: _connection01Name
    pipGateway02Name: pip_vpngw02.name
    vpnGateway01Name: vpnGateway01Name
    vpnGateway02Name: vpnGateway02Name
    enablePrivateIpAddress: enablePrivateIpAddress
    psk: psk
  }
}

module connection02_bgp 'connection-vpngw-bgp-helper.bicep' = if (enableBgp) {
  name: '${_connection02Name}-bgp-helper'
  params: {
    location: vpngw02.location
    connection01Name: _connection02Name
    pipGateway02Name: pip_vpngw01.name
    vpnGateway01Name: vpnGateway02Name
    vpnGateway02Name: vpnGateway01Name
    enablePrivateIpAddress: enablePrivateIpAddress
    psk: psk
  }
}

module connection01_static_route 'connection-vpngw-static-route-helper.bicep' = if (!enableBgp && !enablePrivateIpAddress) {
  name: '${_connection01Name}-static-route-helper'
  params: {
    location: vpngw01.location
    connection01Name: _connection01Name
    vnet02Name: vnet02.name
    pipGateway02Name: pip_vpngw02.name
    vpnGateway01Name: vpnGateway01Name
    vpnGateway02Name: vpnGateway02Name
    psk: psk
  }
}

module connection02_static_route 'connection-vpngw-static-route-helper.bicep' = if (!enableBgp && !enablePrivateIpAddress) {
  name: '${_connection02Name}-static-route-helper'
  params: {
    location: vpngw02.location
    connection01Name: _connection02Name
    vnet02Name: vnet01.name
    pipGateway02Name: pip_vpngw01.name
    vpnGateway01Name: vpnGateway02Name
    vpnGateway02Name: vpnGateway01Name
    psk: psk
  }
}
