param location string = resourceGroup().location
param vnetName string
param vnetAddressPrefix string = '10.0.0.0/16'
param subnetName string
param subnetAddressPrefix string = '10.0.0.0/21'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetAddressPrefix
  }
}

output subnetId string = subnet.id
