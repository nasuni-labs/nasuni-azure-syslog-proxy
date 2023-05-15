param location string = 'eastus'
param vmName string = 'NasuniSyslogProxy'
param adminUsername string = 'adminuser'
@secure()
param adminPassword string
param existingWorkspaceName string
param existingVnet string

var lawID = resourceId('Microsoft.OperationalInsights/workspaces', existingWorkspaceName)
//var existingVnetID = resourceId('Microsoft.Network/virtualNetworks', existingVnet)

resource myPublicIp 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: 'myPublicIp'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource myNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'myNsg'
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

resource myNic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'myNic'
  location: location
  dependsOn: [
    myPublicIp
    myNsg
  ]
  properties: {
    networkSecurityGroup: {
      id: myNsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', existingVnet, 'default')
          }
          publicIPAddress: {
            id: myPublicIp.id
          }
        }
      }
    ]
  }
}

resource myVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    myNic
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS1_v2'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'fromImage'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: myNic.id
        }
      ]
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vmName, 'Monitoring Metrics Publisher', '123456')
  dependsOn: [
    myVm
  ]
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
    principalId: myVm.identity.principalId
    principalType: 'ServicePrincipal'
  }
  scope: myVm
}

// Deploy Azure Monitor Agent extension on the Virtual Machine
resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  name: '${myVm.name}/AzureMonitorLinuxAgent'
  location: location
  dependsOn: [
    myVm
  ]
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
  name: '${myVm.name}-SyslogDataCollectionRuleAssociation'
  location: location
  dependsOn: [
    myVm
  ]
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
  }
  scope: myVm
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  name: '${myVm.name}/CustomScriptExtension'
  location: location
  dependsOn: [
    myVm
  ]
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
