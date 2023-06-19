@description('The name of your Virtual Macine.')
param vmName string = 'NasuniSyslogProxy'

@description('Username for the Virtual Machine.')
param adminUsername string = 'adminuser'

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Enter the name of the existing Log Analytics workspace where Syslog messages will be sent.')
param existingWorkspaceName string

@description('Enter the name of an existing Vnet where the resources will be deployed.')
param existingVnet string

@description('Location for all resources.')
param location string

@description('The size of the VM')
param vmSize string = 'Standard_DS1_v2'

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh:{
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

var lawID = resourceId('Microsoft.OperationalInsights/workspaces', existingWorkspaceName)

/*resource syslogProxyPubIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: 'syslogProxyPubIP'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
  }
}*/

resource syslogProxyNSG 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'syslogProxyNSG'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowTcp514'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '514'
        }
      }
      {
        name: 'allowUdp514'
        properties: {
          priority: 110
          protocol: 'Udp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '514'
        }
      }
      
      {
        name: 'SSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource syslogProxyNIC 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'syslogProxyNIC'
  location: location
  properties: {
    networkSecurityGroup: {
      id: syslogProxyNSG.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', existingVnet, 'default')
          }
          /*
          publicIPAddress: {
            id: syslogProxyPubIP.id
          }
          */
        }
      }
    ]
  }
}

resource syslogProxyVM 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'fromImage'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: syslogProxyNIC.id
        }
      ]
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vmName, 'Monitoring Metrics Publisher', '123456')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
    principalId: syslogProxyVM.identity.principalId
    principalType: 'ServicePrincipal'
  }
  scope: syslogProxyVM
}

// Deploy Azure Monitor Agent extension on the Virtual Machine
resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: syslogProxyVM
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceID: lawID
    }
  }
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' = {
  name: 'SyslogDataCollectionRule'
  location: location
  properties: {
    dataSources: {
      syslog: [
        {
          name: 'SyslogDataSource'
          logLevels: ['Info']
          facilityNames: ['auth','authpriv','cron','daemon','kern','lpr','mail','mark','news','syslog','user','uucp','local0','local1','local2','local3','local4','local5','local6','local7']
          streams: [
            'Microsoft-Syslog'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'LogAnalyticsDestination'
          workspaceResourceId: lawID
        }
      ]
    }
    dataFlows: [
      {
        outputStream: 'Microsoft-Syslog'
        destinations: [
          'LogAnalyticsDestination'
        ]
        streams: [
          'Microsoft-Syslog'
        ]
      }
    ]
  }
}

resource dataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  name: '${syslogProxyVM.name}-SyslogDataCollectionRuleAssociation'
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
  }
  scope: syslogProxyVM
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: syslogProxyVM
  name: 'CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/DataConnectors/Syslog/Forwarder_AMA_installer.py'
      ]
      commandToExecute: 'sudo apt-get update && sudo apt-get install -y python3 && sudo python3 Forwarder_AMA_installer.py'
    }
  }
}
