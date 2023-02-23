param location01 string = resourceGroup().location

param sshKeyRGName string
param publicKeyName string

resource public_key 'Microsoft.Compute/sshPublicKeys@2022-03-01' existing = {
  name: publicKeyName
  scope: resourceGroup(sshKeyRGName)
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
        name: 'anf'
        properties: {
          addressPrefix: '10.0.10.0/24'
          delegations: [
            {
              name: 'NetAppDelegation'
              properties: {
                serviceName: 'Microsoft.NetApp/volumes'
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

resource nsg_default 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'vnet-hub00-default-nsg-eastasia'
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

// resource hg01 'Microsoft.Compute/hostGroups@2022-11-01' = {
//   name: 'hg01'
//   location: location01
//   zones: [ '3' ]
//   properties: {
//     platformFaultDomainCount: 3
//     supportAutomaticPlacement: true
//   }

//   resource host01 'hosts' = {
//     name: 'host01'
//     location: location01
//     sku: {
//       name: 'DSv3-Type3'
//     }
//     properties: {
//       platformFaultDomain: 0
//     }
//   }

//   resource host02 'hosts' = {
//     name: 'host02'
//     location: location01
//     sku: {
//       name: 'DSv3-Type3'
//     }
//     properties: {
//       platformFaultDomain: 0
//     }
//   }
// }

// resource hg01 'Microsoft.Compute/hostGroups@2022-11-01' existing = {
//   name: 'hg01'

//   resource host01 'hosts' existing = {
//     name: 'host01'
//   }

//   resource host02 'hosts' existing = {
//     name: 'host02'
//   }
// }

var vm00Name = 'vm-hub00'
module vm_hub00 '../lib/ubuntu2004.bicep' = {
  name: vm00Name
  params: {
    zones: [ '3' ]
    location: location01
    keyData: public_key.properties.publicKey
    subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
    vmName: vm00Name
    vmSize: 'Standard_D2s_v3'
    enableAcceleratedNetworking: true
    // hostId: hg01::host01.id
  }
}

// var vm01Name = 'vm-hub01'
// module vm_hub01 '../lib/ubuntu2004.bicep' = {
//   name: vm01Name
//   params: {
//     zones: [ '3' ]
//     location: location01
//     keyData: public_key.properties.publicKey
//     subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'default')[0].id
//     vmName: vm01Name
//     vmSize: 'Standard_D2s_v3'
//     enableAcceleratedNetworking: true
//     hostId: hg01::host02.id
//   }
// }

resource anf01 'Microsoft.NetApp/netAppAccounts@2022-05-01' = {
  name: 'anf01'
  location: location01

  // resource cp01 'capacityPools' = {
  //   name: 'cp01'
  //   location: location01
  //   properties: {
  //     serviceLevel: 'Premium'
  //     size: 13194139533312
  //   }

  //   resource volaz01 'volumes' = {
  //     name: 'volaz01'
  //     location: location01
  //     zones: [ '1' ]
  //     properties: {
  //       creationToken: 'nfsaz01'
  //       subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'anf')[0].id
  //       usageThreshold: 4398046511104
  //     }
  //   }

  //   resource volaz02 'volumes' = {
  //     name: 'volaz02'
  //     location: location01
  //     zones: [ '2' ]
  //     properties: {
  //       creationToken: 'nfsaz02'
  //       subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'anf')[0].id
  //       usageThreshold: 4398046511104
  //     }
  //   }

  //   resource volaz03 'volumes' = {
  //     name: 'volaz03'
  //     location: location01
  //     zones: [ '3' ]
  //     properties: {
  //       creationToken: 'nfsaz03'
  //       subnetId: filter(vnet_hub00.properties.subnets, subnet => subnet.name == 'anf')[0].id
  //       usageThreshold: 4398046511104
  //     }
  //   }
  // }
}
