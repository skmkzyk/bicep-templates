param location01 string = resourceGroup().location

/* ****************************** Web Apps ****************************** */

var app01Name = uniqueString(resourceGroup().id)
resource app01 'Microsoft.Web/sites@2022-03-01' = {
  name: app01Name
  location: location01
  properties: {
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
    }
    serverFarmId: asp01.id
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
