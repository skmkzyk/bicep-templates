param location01 string = resourceGroup().location

param default_securityRules array

/* ****************************** hub00 ****************************** */

resource vnet_hub00 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: 'vnet-hub00'
  location: location01
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg_default.id }
        }
      }
    ]
  }
}

resource nsg_default 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'vnet-hub00-default-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

var app01Name = uniqueString(resourceGroup().id)
resource app01 'Microsoft.Web/sites@2022-03-01' = {
  name: app01Name
  location: location01
  properties: {
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
    }
    serverFarmId: asp01.id
    publicNetworkAccess: 'Enabled'
  }
}

resource asp01 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'asp-${app01Name}'
  location: location01
  kind: 'linux'
  sku: {
    tier: 'PremiumV3'
    name: 'P1V3'
  }
  properties: {
    reserved: true
    zoneRedundant: true
  }
}

resource pdns01 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'

  resource vnetlink01 'virtualNetworkLinks' = {
    name: uniqueString(vnet_hub00.id)
    location: 'global'
    properties: {
      virtualNetwork: { id: vnet_hub00.id }
      registrationEnabled: false
    }
  }
}

var pe00Name = 'endp-${app01Name}'
resource pe_akv01 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: pe00Name
  location: location01
  properties: {
    subnet: { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id }
    customNetworkInterfaceName: 'nic-${app01Name}'
    privateLinkServiceConnections: [
      {
        name: pe00Name
        properties: {
          privateLinkServiceId: app01.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }

  resource zonegroup01 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: replace(pdns01.name, '.', '-')
          properties: {
            privateDnsZoneId: pdns01.id
          }
        }
      ]
    }
  }
}
