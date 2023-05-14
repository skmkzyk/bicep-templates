param location01 string = resourceGroup().location
param location02 string = 'japanwest'

var branch_number = range(0, 10)
// var branch_number = [ 0, 1, 4, 5 ]

// resource circuits_jpe 'Microsoft.Network/expressRouteCircuits@2022-09-01' = [for i in [0, 1, 4, 5, 8, 9]: {
//   name: 'cct${i + 100}'
//   location: location01
//   sku: {
//     family: 'MeteredData'
//     name: 'Standard_MeteredData'
//     tier: 'Standard'
//   }
//   properties: {
//     serviceProviderProperties: {
//       bandwidthInMbps: 50
//       peeringLocation: 'Tokyo'
//       serviceProviderName: 'Oracle Cloud FastConnect'
//     }
//   }
// }]

// resource circuits_jpw 'Microsoft.Network/expressRouteCircuits@2022-09-01' = [for i in [12, 13]: {
//   name: 'cct${i + 100}'
//   location: location02
//   sku: {
//     family: 'MeteredData'
//     name: 'Standard_MeteredData'
//     tier: 'Standard'
//   }
//   properties: {
//     serviceProviderProperties: {
//       bandwidthInMbps: 50
//       peeringLocation: 'Tokyo'
//       serviceProviderName: 'Oracle Cloud FastConnect'
//     }
//   }
// }]

// resource circuits_diy 'Microsoft.Network/expressRouteCircuits@2022-09-01' = [for i in [16, 17, 18, 19, 20, 21]: {
//   name: 'cct${i + 100}'
//   location: location01
//   sku: {
//     family: 'MeteredData'
//     name: 'Standard_MeteredData'
//     tier: 'Standard'
//   }
//   properties: {
//     serviceProviderProperties: {
//       bandwidthInMbps: 50
//       peeringLocation: 'Tokyo'
//       serviceProviderName: 'Oracle Cloud FastConnect'
//     }
//   }
// }]
