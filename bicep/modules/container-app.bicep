param name string
param location string
param imageUri string
param imageTag string

param appEnvironment resource 'Microsoft.App/managedEnvironments@2023-05-01'

param acrServer string
param acrIdentityResource resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31'

type IpSecurityRestrictionRule = {
  name: string
  ipAddressRange: string
  action: 'Allow' | 'Deny'
}

param ipRestrictions IpSecurityRestrictionRule[]

resource app 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${name}-app'
  location: location
  properties: {
    environmentId: appEnvironment.id
    template: {
      containers: [
        {
          name: name
          image: '${imageUri}:${imageTag}'
          // resources: {
          //   cpu: json('0.5')
          //   memory: '250Mb'
          // }
        }
      ]
    }
    configuration: {
      // registries: [
      //   {
      //     server: acrServer
      //     identity: 'system'
      //   }
      // ]
      ingress: {
        targetPort: 1883
        exposedPort: 1883
        transport: 'tcp'
        external: true
        allowInsecure: false
        ipSecurityRestrictions: map(ipRestrictions, item => {
            ipAddressRange: item.ipAddressRange
            name: item.name
            action: item.action
          })
      }
    }
  }
}
