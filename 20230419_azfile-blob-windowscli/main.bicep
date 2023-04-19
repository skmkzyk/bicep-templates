param location01 string = resourceGroup().location

param kvName string
param kvRGName string
param secretName string

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: kvName
  scope: resourceGroup(kvRGName)
}

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

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
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.100.0/24'
          networkSecurityGroup: { id: nsg_AzureBastionSubnet.id }
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

resource nsg_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'vnet-hub00-AzureBastionSubnet-nsg-eastasia'
  location: location01
  properties: {
    securityRules: concat(default_securityRules, AzureBastionSubnet_additional_securityRules)
  }
}

var bast00Name = 'bast-hub00'
module bast00 '../lib/bastion.bicep' = {
  name: bast00Name
  params: {
    location: location01
    bastionName: bast00Name
    vnetName: vnet_hub00.name
  }
}

var vm00Name = 'vm-hub00'
module vm_hub00 '../lib/windows10.bicep' = {
  name: vm00Name
  params: {
    location: location01
    adminPassword: kv.getSecret(secretName)
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
  }
}

var sa00name = uniqueString(resourceGroup().id)
resource sa00 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: sa00name
  location: location01
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
  }

  resource bs00 'blobServices' = {
    name: 'default'

    resource container00 'containers' = {
      name: 'container00'
    }
  }

  resource fs00 'fileServices' = {
    name: 'default'

    resource share00 'shares' = {
      name: 'share00'
    }
  }
}

resource pdns00 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
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

resource pdns01 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
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

var pe00Name = 'endp-${sa00name}-blob'
resource pe_blob00 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: pe00Name
  location: location01
  properties: {
    subnet: { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id }
    customNetworkInterfaceName: 'nic-${sa00name}-blob'
    privateLinkServiceConnections: [
      {
        name: pe00Name
        properties: {
          privateLinkServiceId: sa00.id
          groupIds: [
            'blob'
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
          name: replace(pdns00.name, '.', '-')
          properties: {
            privateDnsZoneId: pdns00.id
          }
        }
      ]
    }
  }
}

var pe01Name = 'endp-${sa00name}-share'
resource pe_share01 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: pe01Name
  location: location01
  properties: {
    subnet: { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id }
    customNetworkInterfaceName: 'nic-${sa00name}-share'
    privateLinkServiceConnections: [
      {
        name: pe00Name
        properties: {
          privateLinkServiceId: sa00.id
          groupIds: [
            'file'
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
