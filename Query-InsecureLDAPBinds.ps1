<#-----------------------------------------------------------------------------
Russell Tomkins
Microsoft Premier Field Engineer

Name:           Query-InsecureLDAPBinds.ps1
Description:    Exports a CSV from the specified domain controller containing 
                all Unsgined and Clear-text LDAP binds made to the DC by
                extracting Event 2889 from the "Directory Services" event log.
                This extract can be used to identifiy applications and hosts
                performing weak and insecure LDAP binds.
                
                The events extracted by the script are only generated when
                LDAP diagnostics are enabled as per below. 
                https://technet.microsoft.com/en-us/library/dd941829(v=ws.10).aspx
                
Usage:          .\Query-InsecureLDAPBinds.ps1 [-ComputerName <DomainController>]
                     [-Hours <Hours>]
                Execute the script against the DomainController which has had
                the diagnostic logging enabled. By default, the script will 
                return the past 24 hours worth of events. You can increase or 
                decrease this value as required
Date:           1.0 - 27-01-2016 Russell Tomkins - Initial Release
                1.1 - 27-01-2016 Russell Tomkins - Removed Type Info from CSV   
-------------------------------------------------------------------------------
Disclaimer
The sample scripts are not supported under any Microsoft standard support 
program or service. 
The sample scripts are provided AS IS without warranty of any kind. Microsoft
further disclaims all implied warranties including, without limitation, any 
implied warranties of merchantability or of fitness for a particular purpose.
The entire risk arising out of the use or performance of the sample scripts and 
documentation remains with you. In no event shall Microsoft, its authors, or 
anyone else involved in the creation, production, or delivery of the scripts be
liable for any damages whatsoever (including, without limitation, damages for 
loss of business profits, business interruption, loss of business information, 
or other pecuniary loss) arising out of the use of or inability to use the 
sample scripts or documentation, even if Microsoft has been advised of the 
possibility of such damages.
-----------------------------------------------------------------------------#>
# -----------------------------------------------------------------------------
# Begin Main Script
# -----------------------------------------------------------------------------
# Prepare Variables
Param (
        [parameter(Mandatory=$false,Position=0)][String]$ComputerName = "localhost",
        [parameter(Mandatory=$false,Position=1)][Int]$Hours = 24,
        [parameter(Mandatory=$false,Position=2)][PSCredential]$Credential,
        [parameter(Mandatory=$false,Position=3)][string]$OutputPath='.\InsecureLDAPBinds.csv')

# Create an Array to hold our returnedvValues
$InsecureLDAPBinds = @()

# Grab the appropriate event entries
If($null -eq $Credential) {
    $Events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{Logname='Directory Service';Id=2889; StartTime=(get-date).AddHours("-$Hours")}
} else {
    $Events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{Logname='Directory Service';Id=2889; StartTime=(get-date).AddHours("-$Hours")} -Credential $Credential
}

# Loop through each event and output the 
ForEach ($Event in $Events) { 
	$eventXML = [xml]$Event.ToXml()
	
	# Build Our Values
	$Client = ($eventXML.event.EventData.Data[0])
	$IPAddress = $Client.SubString(0,$Client.LastIndexOf(":")) #Accomodates for IPV6 Addresses
	$Port = $Client.SubString($Client.LastIndexOf(":")+1) #Accomodates for IPV6 Addresses
	$User = $eventXML.event.EventData.Data[1]
	Switch ($eventXML.event.EventData.Data[2])
		{
		0 {$BindType = "Unsigned"}
		1 {$BindType = "Simple"}
		}
    # Find DNS name if available
    Try {
        $DNSName = [System.Net.Dns]::gethostentry($IPAddress).hostname
    } catch {
        $DNSName = ""
    }
        
	# Add Them To a Row in our Array
	$Row = "" | Select-Object IPAddress,DNSName,Port,User,BindType
    $Row.IPAddress = $IPAddress
    $Row.DNSName = $DNSName
	$Row.Port = $Port
	$Row.User = $User
	$Row.BindType = $BindType
	
	# Add the row to our Array
	$InsecureLDAPBinds += $Row
}
# Dump it all out to a CSV.
#Write-Host $InsecureLDAPBinds.Count "records saved to $OutputPath for Domain Controller" $ComputerName
$InsecureLDAPBinds #| Export-CSV -NoTypeInformation $OutputPath
# -----------------------------------------------------------------------------
# End of Main Script
# -----------------------------------------------------------------------------

<# How I, Perry Harris use this:
$cred = Get-Credential
$DCs = get-ADDomainController -Filter *
Invoke-Command -ComputerName $DCs.HostName -Credential $cred -FilePath Query.InsecureLDAPBinds.ps1 -AsJob
Get-Job |Wait-Job
$Results = Get-Job |Receive-Job
Get-Job | Remove-Job
$Results |Export-Excel -Path InsecureLogins.XLSX -BoldTopRow -AutoSize -AutoFilter -FreezeTopRow
#>

