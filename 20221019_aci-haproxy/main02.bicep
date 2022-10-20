param location01 string = resourceGroup().location

param publicKeyName string
param sshKeyRGName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
}

@secure()
param acrPassword string

param default_securityRules array
param AzureBastionSubnet_additional_securityRules array

/* ****************************** hub00 ****************************** */

resource vnet_hub00 'Microsoft.Network/virtualNetworks@2022-01-01' = {
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
        name: 'frontend'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg_hub00_frontendSubnet.id }
        }
      }
      {
        name: 'backend'
        properties: {
          addressPrefix: '10.0.10.0/24'
          networkSecurityGroup: { id: nsg_hub00_backendSubnet.id }
        }
      }
      {
        name: 'aci'
        properties: {
          addressPrefix: '10.0.20.0/24'
          networkSecurityGroup: { id: nsg_hub00_aciSubnet.id }
          delegations: [
            {
              name: 'Microsoft.ContainerInstance.containerGroups'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
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

resource nsg_hub00_frontendSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-frontend-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub00_backendSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-backend-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_hub00_aciSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-aci-nsg-eastasia'
  location: location01
  properties: {
    securityRules: default_securityRules
  }
}

resource nsg_AzureBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
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

var vm01Name = 'vm-front01'
module vm_hub01 '../lib/ubuntu2004.bicep' = {
  name: vm01Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'frontend')[0].id
    vmName: vm01Name
    privateIpAddress: '10.0.0.10'
  }
}

var vm11Name = 'vm-back01'
module vm_hub11 '../lib/ubuntu2004.bicep' = {
  name: vm11Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'backend')[0].id
    vmName: vm11Name
    privateIpAddress: '10.0.10.11'
    customData: loadFileAsBase64('./cloud-init.yml')
  }
}

var vm12Name = 'vm-back02'
module vm_hub12 '../lib/ubuntu2004.bicep' = {
  name: vm12Name
  params: {
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'backend')[0].id
    vmName: vm12Name
    privateIpAddress: '10.0.10.12'
    customData: loadFileAsBase64('./cloud-init.yml')
  }
}

var acr01Name = 'acr${uniqueString(resourceGroup().id)}'
resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: acr01Name
}

var aci01Name = 'acri-${uniqueString(resourceGroup().id)}'
var ports = [ {
    port: 80
    protocol: 'TCP'
  } ]
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  location: location01
  name: aci01Name
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    containers: [
      {
        name: aci01Name
        properties: {
          image: '${acr.properties.loginServer}/haproxysample1:v1'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          ports: ports
        }
      }
    ]
    restartPolicy: 'Always'
    osType: 'Linux'
    imageRegistryCredentials: [
      {
        server: acr.properties.loginServer
        username: acr.name
        password: acrPassword
      }
    ]
    ipAddress: {
      type: 'Private'
      ports: ports
    }
    subnetIds: [
      { id: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'aci')[0].id }
    ]
  }
}
