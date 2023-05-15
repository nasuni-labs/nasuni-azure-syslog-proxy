[![Deploy to Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmdriscoll-nasuni%2Fnasuni-syslog-proxy%2Fmaster%2Fmain.json%3Ftoken%3DGHSAT0AAAAAACBVUMC7TADGUCHP3R6EZRQUZCGUDEA)

# Syslog Proxy
This template can be used to deploy a Linux VM in Azure that will act as a syslog proxy for the Nasuni platform. It will forward Notifications or file system audit events to a Log Analytics workspace. The logs can be manually examined or consumed by other services including Microsoft Sentinel.

# Support Statement
* Nasuni Support is limited to the underlying syslog service running on the Nasuni appliances.
* Nasuni Protocol bugs or feature requests should be communicated to Nasuni Customer Success.
* GitHub project to-do's, bugs, and feature requests should be submitted as “Issues” in GitHub under its repositories.

# Prerequisites
* The name of an existing [Log Analytics Workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview) to which syslog data will be sent
* Private networking, such as a [site-to-site VPN](https://learn.microsoft.com/en-us/azure/vpn-gateway/tutorial-site-to-site-portal) or [ExpressRoute](https://azure.microsoft.com/en-us/products/expressroute) connection, established between your Nasuni appliances and the VNET in which the proxy is deployed. This is to ensure that syslog data is protected.

# Resources Deployed
* An Azure Linux VM configured to listen for syslog messages on TCP/514 and UDP/514 and running the Azure Monitor Agent
* A Network Security Group that allows connections on TCP/22, TCP/514, and UDP/514
* An Azure Monitor Data Collection rule that will collect syslog messages

# Post-Deployment Tasks
## Syslog Export Configuration
Configure your Nasuni appliances to send Notifications and/or file system audit events via syslog to the proxy VM. Consult the "Syslog Export" section of the [Nasuni Management Console Guide](http://b.link/Nasuni_NMC_Guide) for configuration instructions.
## Auditing Policy Configuration
Configure the audit policy for each volume for which you would like to collect events. Consult the "File System Auditing" secton of the [Nasuni Management Console Guide](http://b.link/Nasuni_NMC_Guide) for configuration instructions.

# On-premises Alternative
If you prefer to run the syslog proxy VM in your own datacenter, you can deploy a Linux VM and install the Azure Monitor agent on it. For on-prem installations, the Azure Monitor agent requires that the server be managed with Azure Arc.
## Deployment Tasks
1. Install a Linux VM
2. Configure syslog. Microsoft provides a [Python script](https://github.com/Azure/Azure-Sentinel/tree/master/DataConnectors/Syslog) that can configure rsyslogd or syslog-ng
3. Configure the Linux VM for [Azure Arc](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal)
4. Install the [Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage) 
5. Complete the Post-Deployment Tasks above