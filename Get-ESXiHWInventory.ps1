<#
.Synopsis
   GET ESXi PCI Devices Inventory
.DESCRIPTION
   GET ESXi PCI Devices Inventory
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.BASED ON
   https://www.lucd.info/2010/03/07/name-that-hardware/
.AUTHOR
   Juliano Alves de Brito Ribeiro (Find me at: julianoalvesbr@live.com or https://github.com/julianoabr)
.VERSION
   0.1
#>




function Get-ESXiHWInventory
{
    [CmdletBinding()]
   Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.String]$ESXiName,

        #Param2 help description
        [Parameter(Mandatory=$false,
                   Position=1)]
        [switch]
        $csvReport,

        # Param3 help description
        [Parameter(Mandatory=$false,
                   Position=1)]
        [switch]
        $htmlReport,

        [Parameter(Mandatory=$false,
                   Position=2)]
        [System.Boolean]
        $forceDownload = $false,


        [Parameter(Mandatory=$false,
                   Position=3)]
        [System.Collections.Hashtable]
        $deviceTab = @{},

        
        [Parameter(Mandatory=$false,
                   Position=3)]
        [System.Boolean]
        $useProxy=$false,

        [System.String]$CSVFile = "ESXidata.csv",
        
        [System.String]$HTMLFile = "ESXidata.html"

    )


$currentLocation = (Get-location).Path

$sourceURL = "https://pci-ids.ucw.cz/v2.2/pci.ids"

$fileName = $sourceURL.Split('/')[4]

$destinationFile = $currentLocation + '\' + $filename

# Download file if not present or if forced download
if(!(Test-Path $destinationFile) -or $forceDownload){

    if ($useProxy){
    
        $proxyServer = Read-Host "Type Proxy server Name"

        $proxyCred = Get-Credential

        Invoke-WebRequest -Uri $sourceURL -Proxy $proxyServer -ProxyCredential $proxyCred -OutFile $destinationFile -UseBasicParsing -Verbose
    
    }else{
    
        Invoke-WebRequest -Uri $sourceURL -OutFile $destinationFile -UseBasicParsing -Verbose
    
    }
    
}

# Read file into hash tab
Get-Content $filename | where {$_.Length -ne 0 -and $_[0] -ne "#"} | ForEach-Object{
    if($_[0] -eq "`t"){
        if($_[1] -eq "`t"){
            $subdeviceId = $_.Substring(2,4)
            
            if(!$deviceTab[$vendorId].deviceTab.ContainsKey($subdeviceId)){
                
                $deviceTab[$vendorId].deviceTab[$subdeviceId] = $_.Substring(6).TrimStart(" ")
            }
        }
        else{
            $deviceId = "0x" + $_.Substring(1,4)
            
            if(!$deviceTab[$vendorId].deviceTab.ContainsKey($deviceId)){
                
                $deviceTab[$vendorId].deviceTab[$deviceId] = $_.Substring(5).TrimStart(" ")
            }
        }
    }
    else{
        
        $vendorId = "0x" + $_.Substring(0,4)
        
        if(!$deviceTab.ContainsKey($vendorId)){
            
            $deviceTab[$vendorId] = New-Object PSObject -Property @{
                            Vendor = $_.Substring(4).TrimStart(" ")
                            deviceTab = @{}
                            }
            }
        }
}
# End of Read file into hash tab

$reportArray = @()

# List all PCI devices and look up Vendor and description
$ESXi = Get-VmHost -Name $ESXiName | Get-View

$ESXi.Hardware.PciDevice | ForEach-Object {

    $strVendorId = "0x" + "{0}" -f [Convert]::ToString($_.VendorId,16).ToUpper().PadLeft(4, '0')
    
    $strDeviceId = "0x" + "{0}" -f [Convert]::ToString($_.DeviceId,16).ToUpper().PadLeft(4, '0')
                
    $ESXiData = [ordered]@{
        ESXi = $ESXiName
        Slot = $_.Id
        Vendor = &{if($deviceTab.ContainsKey($strVendorId)){$deviceTab[$strVendorId].Vendor}else{$strVendorId}}
        Device = &{if($deviceTab[$strVendorId].deviceTab.ContainsKey($strDeviceId)){$deviceTab[$strVendorId].deviceTab[$strDeviceId]}else{$strDeviceId}}
    }
            
    $objESXi = New-Object -TypeName PSObject -property $ESXiData

    $reportArray +=$objESXi

    Write-Output $objESXi

    }#End of ForEach Object

    #Export to CSV
    if($csvReport.IsPresent){
                
        $EsxiCSVReport = $currentLocation + '\' + $CSVFile
                
        $reportArray | Sort-Object -Property Device | Export-Csv -Path $EsxiCSVReport -NoTypeInformation -UseCulture -Verbose
                
    }

    #Export to HTML
    if($htmlReport.IsPresent){
       
        $EsxiHTMLReport = $currentLocation + '\' + $HTMLFile 
            
        $reportArray | ConvertTo-HTML | Out-File -FilePath $EsxiHTMLReport -Verbose
       
    }


}#End of Function

[System.String] $esxiHostName = Read-Host "Type the ESXi Host Name"

Get-ESXiHWInventory -ESXiName $esxiHostName -csvReport
