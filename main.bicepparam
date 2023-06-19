using './main.bicep'

param vmName = 'NasuniSyslogProxytest'
param adminUsername = 'adminuser'
param authenticationType = 'password'
param adminPasswordOrKey = ''
param existingWorkspaceName = 'nasdristest'
param existingVnet = 'vnet1'
param location = 'eastus'
param vmSize = 'Standard_DS1_v2'

