Using module .\SqlDeepLogWriter.psm1
Class BackupFile {
    [string]$PhysicalFile
    
    BackupFile([string]$PhysicalFile){
        $this.PhysicalFile=$PhysicalFile
    }
}
class BackupFileCleaner {
    [bool]$HasDirectory = $false
    [string]$FilePath = ""
    [string]$FileExtension = ".bak"
    [int]$DaysOld = 10
    [int]$ThroughDay = 100
    hidden [LogWriter]$Logger

    BackupFileCleaner([bool]$HasDirectory, [string]$FileExtension, [string]$FilePath, [int32]$ThroughDay, [LogWriter]$Logger) {
        $this.Init($HasDirectory, $FilePath, $FileExtension, 10, $ThroughDay, $Logger)
    }

    BackupFileCleaner([bool]$HasDirectory, [string]$FilePath, [string]$FileExtension, [int32]$DaysOld, [int32]$ThroughDay, [LogWriter]$Logger) {
        $this.Init($HasDirectory, $FilePath, $FileExtension, $DaysOld, $ThroughDay, $Logger)
    }

    Init([bool]$HasDirectory, [string]$FilePath, [string]$FileExtension, [int32]$DaysOld, [int32]$ThroughDay, [LogWriter]$Logger) {
        $this.HasDirectory = $HasDirectory
        $this.FilePath = $FilePath
        $this.FileExtension = $FileExtension
        $this.DaysOld = $DaysOld
        $this.ThroughDay = $ThroughDay
        $this.Logger = $Logger
    }
  #  $Logger = [WriteLog]::new($this.ErrorFile)
#region functions
    hidden [string] GetCurrentInstance() {
        [string]$myAnswer = ""
        try {
            $myInstanceName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
            $myMachineName = $env:COMPUTERNAME
            $myRegFilter = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL*.' + $myInstanceName + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
            $myPort = (Get-ItemProperty -Path $myRegFilter).TcpPort.Split(',')[0]
            $myDomainName = (Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem).Domain
            $myConnection = $myMachineName
            if ($myDomainName) { $myConnection += '.' + $myDomainName }
            if ($myInstanceName -ne "MSSQLSERVER") { $myConnection += '\' + $myInstanceName }
            if ($myPort) { $myConnection += ',' + $myPort }
            $myAnswer = $myConnection
        }
        catch {
            $this.Logger.Write((($_.ToString()).ToString(),[LogType]::WRN))
        }
        return $myAnswer
    }
    
    hidden [BackupFile[]] GetBackupFileList([string]$ConnectionString, [int]$FromDate, [int]$ThroughDay, [string]$FileExtension) {
        [BackupFile[]]$myAnswer = $null
        $myCommand = "
            DECLARE @myToday AS DATE
            DECLARE @myThroughDay AS INT
            DECLARE @myFromDate AS INT
            DECLARE @myFileExtension AS CHAR(4)

            SET @myFromDate = -1*ABS(" + $FromDate.ToString() + ")
            SET @myThroughDay = -1*ABS(" + $ThroughDay.ToString() + ")
            SET @myToday=CAST(GETDATE() AS DATE)
            SET @myFileExtension = '" + $FileExtension + "'
               
            SELECT 
	            myMediaSet.physical_device_name AS PhysicalFile
            -- ,myBackupSet.backup_start_date as BackupDate
            FROM
	            master.sys.databases AS myDatabase WITH (READPAST)
                LEFT OUTER JOIN master.sys.dm_hadr_availability_replica_states AS myHA WITH (READPAST)  ON myDatabase.replica_id = myHA.replica_id
                LEFT OUTER JOIN msdb.dbo.backupset AS myBackupSet WITH (READPAST)  ON myBackupSet.database_name = myDatabase.name
                AND myBackupSet.backup_start_date  BETWEEN CAST(DATEADD(DAY, @myThroughDay, @myToday) AS DATETIME) AND CAST(DATEADD(DAY, @myFromDate, @myToday) AS DATETIME)
                LEFT OUTER JOIN msdb.dbo.backupmediafamily AS myMediaSet WITH (READPAST) ON myBackupSet.media_set_id = myMediaSet.media_set_id
            WHERE myDatabase.state = 0 --online
                  AND ( myHA.role = 1 OR myHA.role IS NULL )
                  AND myMediaSet.physical_device_name IS NOT NULL
	              AND RIGHT(myMediaSet.physical_device_name, 4) = @myFileExtension
"
 
        try {
            [System.Data.DataRow[]]$myRecords=$null
                $myRecords = Invoke-Sqlcmd -ServerInstance $ConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -ErrorAction Stop 
                [System.Collections.ArrayList]$myBackupFilePath=$null
                $myBackupFilePath=[System.Collections.ArrayList]::new()
                $myRecords|ForEach-Object{$myBackupFilePath.Add([BackupFile]::New($_.PhysicalFile))}
                $myAnswer=$myBackupFilePath.ToArray([BackupFile])
            }
        catch [Exception] {
            $this.Logger.Write($($_.Exception.Message), [LogType]::ERR)
        }
        return $myAnswer
    }

    hidden [BackupFile[]] GetBackupFileList([string]$FolderPath,[string]$FileExtension,[datetime]$OlderThan){
        try {
        [BackupFile[]]$myAnswer = $null
        [System.Collections.ArrayList]$myBackupFilePath=$null
        $myBackupFilePath=[System.Collections.ArrayList]::new()
       # Get-ChildItem -Path $FolderPath -Recurse  | ForEach-Object{Write-Host ($_.FullName + $_.Extension + $_.LastWriteTime)} #|  Where-Object {$_.Extension -eq $FileExtension -and $_.LastWriteTime -lt $OlderThan} | ForEach-Object{$myBackupFilePath.Add([BackupFile]::New($_.FullName))}
        Get-ChildItem -Path $FolderPath -Recurse  |  Where-Object {$_.Extension -eq $FileExtension -and $_.LastWriteTime -lt $OlderThan} | ForEach-Object{$myBackupFilePath.Add([BackupFile]::New($_.FullName))}
        $myAnswer=$myBackupFilePath.ToArray([BackupFile])
        }
        catch [Exception] {
            $this.Logger.Write($($_.Exception.Message), [LogType]::ERR)
        }
        return $myAnswer
    }

    [void] CleanFiles() {
        # Validate input parameters
        if ($null -eq $this.FileExtension -or $this.FileExtension.Trim().Length -ne 4) {
            $this.Logger.Write("FileExtension is not true, use it .bak.", [LogType]::WRN)
            $this.FileExtension = ".bak"
        }

        # Calculate the date limit
        [BackupFile[]]$myFileList=$null
        [datetime]$myDateLimit = (Get-Date).AddDays(-$this.DaysOld)

        # Get all files in the target path with the specified extension that are older than the date limit
        $this.Logger.Write("Get backupFile List for delete from "+ $this.HasDirectory , [LogType]::INF) 
        if ($this.HasDirectory) {
            $myFileList=$this.GetBackupFileList($this.FilePath,$this.FileExtension,$myDateLimit)
        } else {
            $myConnectionString = $this.GetCurrentInstance()
            $this.Logger.Write("Get Backup File List for delete from " + $myConnectionString , [LogType]::INF)
            $myFileList = $this.GetBackupFileList($myConnectionString, $this.DaysOld, $this.ThroughDay ,$this.FileExtension) | Where-Object {$_.PhysicalFile} #-lt $myDateLimit
        }
        # Loop through the files and delete them
        foreach ($myFile in $myFileList.PhysicalFile) {
            try {
               # $this.Logger.Write("Delete backup files List is " + $myFile.PhysicalFile, [LogType]::INF)
                if (Test-Path -Path $myFile -PathType Leaf) {
                    $this.Logger.Write("Delete backup files of " + $myFile, [LogType]::INF)
                    Remove-Item $myFile.PhysicalFile -Force
                }
            }
            catch [Exception] {
                $this.Logger.Write($($_.Exception.Message), [LogType]::ERR)
            }
        }
    }
#endregion
}

#region Functions
Function New-BackupFileCleaner {
    [CmdletBinding(DefaultParameterSetName = 'Directory')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Directory')][string]$FilePath,
        [Parameter(Mandatory = $false, ParameterSetName = 'Instance')][switch]$UseCurrentInstance,
        [Parameter(Mandatory = $false)][string]$FileExtension,
        [Parameter(Mandatory = $false)][int32]$DaysOld,
        [Parameter(Mandatory = $false)][int32]$ThroughDay,
        [Parameter(Mandatory = $true)][LogWriter]$Logger
    )
    Write-Verbose "Creating New-BackupFileCleaner"

    if ($PSCmdlet.ParameterSetName -eq 'Directory') {
        [BackupFileCleaner]::new($true, $FilePath, $FileExtension, $DaysOld, $ThroughDay, $Logger)
        
    } else {
        [BackupFileCleaner]::new($false, "", $FileExtension, $DaysOld, $ThroughDay, $Logger)
    }

    Write-Verbose "New-BackupFileCleaner Created"

}
#endregion

#region Export
Export-ModuleMember -Function New-BackupFileCleaner
#endregion
# SIG # Begin signature block
# MIIboAYJKoZIhvcNAQcCoIIbkTCCG40CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVWHt78epIPkMYWWdlRNEBiOO
# zqSgghYbMIIDFDCCAfygAwIBAgIQE9nPUuFPfIxIdnqq7ThiojANBgkqhkiG9w0B
# AQUFADAWMRQwEgYDVQQDDAtzcWxkZWVwLmNvbTAeFw0yNDEwMjMxMjIwMDJaFw0y
# NjEwMjMxMjMwMDJaMBYxFDASBgNVBAMMC3NxbGRlZXAuY29tMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4r0s4Bg6lsKIg+zgWvLcE9J8xxjWpMGbRM76
# tx3C/GwoHw3af9JKc6EuiCqY7dqcq9MRnF50y0rxLSe9FzoJ9e/WtU5WkVJcvom7
# lHzteYp68D39Wun6oLzzKF1emzMabG5sfb0uglAWDteBlDddBrZUIKVGGNTdHM2m
# wu8l36PBMJDtWUxqFwA4pxwRdKaCn350dBF+QYi+/1hkX09yYBWfLcGDKCjnOISf
# hmW7nbQKbb51swHYljPFH8EMHB/EiUO5+cITzj1fHvmiAm5oH/Y/DXFQClCqgYhi
# 5hISioximlKMOd3E7LIbRgp3b+XZzIBNqaZMYWljZ/KkamHUBQIDAQABo14wXDAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwFgYDVR0RBA8wDYIL
# c3FsZGVlcC5jb20wHQYDVR0OBBYEFMKB2TYWHVb7c2OYPVpTlYhvOm/BMA0GCSqG
# SIb3DQEBBQUAA4IBAQALy82fcFq7qURGF5HHsaCwcG8YyB7nmsZbjJibODEr38ix
# u5s475LJH9gMX2jJ1q//1vtCi4cWdPorXPweBRKeHCwmcpwVmvokgnPIghdA3M04
# 1NXsRtJlH3/Nnu3OZl7N6Iumjj0cst1wY2amXWBNR1pfRmIW6AuZGOuWeNmbGzcj
# zjPJ4STcwSqvVensjRNiZ8Za0Nb9fZcVzpullh4J4fvrVH/ZPAyNQ+w2t20KrI/D
# vgAh44YzFc1iqgLZw8cnWjjo0YSliJR1EO3y1hmBWVtiV56IKsRUdrc3aWcbDYA+
# Lxxc7dQrKYh84SLDMH0BcSIOODcv1PepdmlaUepVMIIFjTCCBHWgAwIBAgIQDpsY
# jvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQw
# IgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAw
# MDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhE
# aWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57
# G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9o
# k3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFh
# mzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463J
# T17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFw
# q1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yh
# Tzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU
# 75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LV
# jHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJ
# bOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8Qg
# UWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IB
# OjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6
# mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/
# BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au
# ZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4
# oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJv
# b3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBw
# oL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0
# E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtD
# IeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlU
# sLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFig
# DkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwY
# w02fc7cBqZ9Xql4o4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzAN
# BgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2Vy
# dCBUcnVzdGVkIFJvb3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5
# WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNV
# BAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1w
# aW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1y
# SVFVxyUDxPKRN6mXUaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50f
# ng8zH1ATCyZzlm34V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO
# 6lE98NZW1OcoLevTsbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12s
# y+iEZLRS8nZH92GDGd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYN
# XNXmG6jBZHRAp8ByxbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9O
# dhVVJnCYJn+gGkcgQ+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7j
# PqJz+ucfWmyU8lKVEStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/
# 8KI8ykLcGEh/FDTP0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixX
# NXkrqPNFYLwjjVj33GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtb
# iiKowSYI+RQQEgN9XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O
# 6V3IXjASvUaetdN2udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwHQYDVR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQY
# MBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUE
# DDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDww
# OjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0G
# CSqGSIb3DQEBCwUAA4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y
# +8dQXeJLKftwig2qKWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExi
# HQwIgqgWvalWzxVzjQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye
# 4Iqs5f2MvGQmh2ySvZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj
# +sAngkSumScbqyQeJsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFq
# cdnGE4AJxLafzYeHJLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZ
# Jyw9P2un8WbDQc1PtkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4
# rUyt+8SVe+0KXzM5h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228V
# ex4Ziza4k9Tm8heZWcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrV
# FZgxtGIJDwq9gdkT/r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZC
# pimHCUcr5n8apIUP/JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8
# /DCCBrwwggSkoAMCAQICEAuuZrxaun+Vh8b56QTjMwQwDQYJKoZIhvcNAQELBQAw
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTAeFw0yNDA5MjYwMDAwMDBaFw0zNTExMjUyMzU5NTlaMEIxCzAJBgNVBAYT
# AlVTMREwDwYDVQQKEwhEaWdpQ2VydDEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0
# YW1wIDIwMjQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC+anOf9pUh
# q5Ywultt5lmjtej9kR8YxIg7apnjpcH9CjAgQxK+CMR0Rne/i+utMeV5bUlYYSuu
# M4vQngvQepVHVzNLO9RDnEXvPghCaft0djvKKO+hDu6ObS7rJcXa/UKvNminKQPT
# v/1+kBPgHGlP28mgmoCw/xi6FG9+Un1h4eN6zh926SxMe6We2r1Z6VFZj75MU/HN
# mtsgtFjKfITLutLWUdAoWle+jYZ49+wxGE1/UXjWfISDmHuI5e/6+NfQrxGFSKx+
# rDdNMsePW6FLrphfYtk/FLihp/feun0eV+pIF496OVh4R1TvjQYpAztJpVIfdNsE
# vxHofBf1BWkadc+Up0Th8EifkEEWdX4rA/FE1Q0rqViTbLVZIqi6viEk3RIySho1
# XyHLIAOJfXG5PEppc3XYeBH7xa6VTZ3rOHNeiYnY+V4j1XbJ+Z9dI8ZhqcaDHOoj
# 5KGg4YuiYx3eYm33aebsyF6eD9MF5IDbPgjvwmnAalNEeJPvIeoGJXaeBQjIK13S
# lnzODdLtuThALhGtyconcVuPI8AaiCaiJnfdzUcb3dWnqUnjXkRFwLtsVAxFvGqs
# xUA2Jq/WTjbnNjIUzIs3ITVC6VBKAOlb2u29Vwgfta8b2ypi6n2PzP0nVepsFk8n
# lcuWfyZLzBaZ0MucEdeBiXL+nUOGhCjl+QIDAQABo4IBizCCAYcwDgYDVR0PAQH/
# BAQDAgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYD
# VR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1N
# hS9zKXaaL3WMaiCPnshvMB0GA1UdDgQWBBSfVywDdw4oFZBmpWNe7k+SH3agWzBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggr
# BgEFBQcBAQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMFgGCCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0G
# CSqGSIb3DQEBCwUAA4ICAQA9rR4fdplb4ziEEkfZQ5H2EdubTggd0ShPz9Pce4FL
# Jl6reNKLkZd5Y/vEIqFWKt4oKcKz7wZmXa5VgW9B76k9NJxUl4JlKwyjUkKhk3aY
# x7D8vi2mpU1tKlY71AYXB8wTLrQeh83pXnWwwsxc1Mt+FWqz57yFq6laICtKjPIC
# YYf/qgxACHTvypGHrC8k1TqCeHk6u4I/VBQC9VK7iSpU5wlWjNlHlFFv/M93748Y
# TeoXU/fFa9hWJQkuzG2+B7+bMDvmgF8VlJt1qQcl7YFUMYgZU1WM6nyw23vT6QSg
# wX5Pq2m0xQ2V6FJHu8z4LXe/371k5QrN9FQBhLLISZi2yemW0P8ZZfx4zvSWzVXp
# Ab9k4Hpvpi6bUe8iK6WonUSV6yPlMwerwJZP/Gtbu3CKldMnn+LmmRTkTXpFIEB0
# 6nXZrDwhCGED+8RsWQSIXZpuG4WLFQOhtloDRWGoCwwc6ZpPddOFkM2LlTbMcqFS
# zm4cd0boGhBq7vkqI1uHRz6Fq1IX7TaRQuR+0BGOzISkcqwXu7nMpFu3mgrlgbAW
# +BzikRVQ3K2YHcGkiKjA4gi4OA/kz1YCsdhIBHXqBzR0/Zd2QwQ/l4Gxftt/8wY3
# grcc/nS//TVkej9nmUYu83BDtccHHXKibMs/yXHhDXNkoPIdynhVAku7aRZOwqw6
# pDGCBO8wggTrAgEBMCowFjEUMBIGA1UEAwwLc3FsZGVlcC5jb20CEBPZz1LhT3yM
# SHZ6qu04YqIwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAw
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFHXKPd61BeBwKvn6VJqQel/V2ckQMA0G
# CSqGSIb3DQEBAQUABIIBAEBVsm3TumSotmKLoMNzbMAbMiQqF1ubJ9KZ98M4DYPR
# 283U5CWS44/GE0lH3tyWJpo4qFP+0N8KmGTHlZhLik+rA7EoVf9COy+qs6+r65KO
# CrskYsUwhAI/Y7nDSYpuSU3VK/+3fBuOrjYxxqNAPmgHxW4GtsBgk3JIPwypH2et
# JhRzmxUJO9pKYEbdaFVDThfJChd65jX03bFZYCUjErM9fjfAZeVxXL+QFvgLaz3V
# 7r+Xrq6Ilfg0yHtUrNLdGTsYX0+bfEJ+9wli7RVYFhvq9lH0Cf6yGVYgmiECmWh9
# 82WbrKdBSa561RYwXaDJlHBtdyPECxS4XA3wsOUZnnyhggMgMIIDHAYJKoZIhvcN
# AQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBT
# SEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/lYfG+ekE4zMEMA0GCWCGSAFl
# AwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjUwNzAxMTEzNDA4WjAvBgkqhkiG9w0BCQQxIgQgvn0leEQQrQN7tIyKCJ2o
# kbCnSR+VabNLl/BSSCmGCa4wDQYJKoZIhvcNAQEBBQAEggIAITYpo2f6A38JE8Yd
# hE34CFqRO7qie9KKaNe6m4p4Z6I4/eg6FYNTQGaS+ZFISoNHiYadyUWI/knfL8Pt
# Z9lKDii2RE8bJMrYX15PvjW3URz349OI4EheDTnnXYXWW19c16BCdcxr3JtfK7Bp
# eJnl+h6RqDzDY7NEsTAerzWr0rFPaEOBEMkmR8X3QTuoi8LPko0iOea6A81sejYW
# Qugn9fwVNvQpufsmtH3vt4SenvWnqx9LPRRttfE3JLS3lKG0tdaq0qBP2cEoWLlQ
# 7wwUEnaGDKEL3N5OQc95NYf/hdJcqP1Lti/5FJbUv1+8QTFaScY0u3A+IjOQlg2a
# XjdjKeEG4wC9CBemi6FhkhjIYo3r2988R/UQ3eNA34E6LAM78D3HHjZ8X8pt+v63
# s7KUWAQsv55go63ZSmRNuHfTypyvYKRpBpC79B5dAYWbUq86JJtPyNdYNTV7/o0M
# gMqKftts+E8GYPhnV+WSd8bpuklilFshdcavDdgoqq8wyHneGrBVmZcq4y/xDQN6
# YlXJV0ABdZazbl/+Vo++33R1cVyR4ODHrXEcb/v9EckKHGgpx0ZtP/GEiFRbrIW7
# pRX68fadG1K9sXhJnjLZCzuUwZTQhqkW5QX8NpOtcGcq71Conq4VQJi3v38I6MLd
# j9sMa54GpkT2kiErvrJqRIg7Sx4=
# SIG # End signature block
