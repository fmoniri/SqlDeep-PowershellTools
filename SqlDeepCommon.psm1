Using module .\SqlDeepLogWriter.psm1
Class InstanceObject {  # Data structure for Instance Object
    [string]$MachineName
    [string]$DomainName
    [string]$InstanceName
    [string]$InstanceRegName
    [string]$InstancePort
    [bool]$ForceEncryption
    [string]$DefaultDataPath
    [string]$DefaultLogPath
    [string]$DefaultBackupPath
    [string]$Collation
    [string]$PatchLevel
	
	InstanceProperty([string]$MachineName,[string]$DomainName,[string]$InstanceName,[string]$InstanceRegName,[string]$InstancePort,[bool]$ForceEncryption,[string]$DefaultDataPath,[string]$DefaultLogPath,[string]$DefaultBackupPath,[string]$Collation,[string]$PatchLevel){
        $this.MachineName=$MachineName;
        $this.DomainName=$DomainName;
        $this.InstanceName=$InstanceName;
        $this.InstanceRegName=$InstanceRegName;
        $this.InstancePort=$InstancePort;
        $this.ForceEncryption=$ForceEncryption;
        $this.DefaultDataPath=$DefaultDataPath;
        $this.DefaultLogPath=$DefaultLogPath;
        $this.DefaultBackupPath=$DefaultBackupPath;
        $this.Collation=$Collation;
        $this.PatchLevel=$PatchLevel;
	}
}
Class Instance {    # Instance level common functions
    static [bool]Test_InstanceConnectivity([string]$ConnectionString) {  # Test Instance connectivity
        [bool]$myAnswer=$false;
        try{
            $myAnswer=Database.Test_DatabaseConnectivity($ConnectionString,"master");
        }Catch{
            $myAnswer=$false;
            Write-Error($_.ToString());
            throw;
        }
        return $myAnswer;
    }
    static [InstanceObject[]]Get_InstanceInfo() {  # Retrive current machine sql instance(s) and it's related info from windows registery
        [InstanceObject[]]$myAnswer=$null;
        [string]$myMachineName=$null;
        [string]$myDomainName=$null;
        [string]$myRegInstanceFilter=$null;

        try {
            [System.Collections.ArrayList]$myInstanceCollection=$null;
            $myInstanceCollection=[System.Collections.ArrayList]::new();
            $myMachineName=($env:computername);
            $myDomainName=(Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem).Domain;
            $myRegInstanceFilter='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL';
            $myRegKey=Get-ItemProperty -Path $myRegInstanceFilter;
            $myRegKey.psobject.Properties | Where-Object -Property Name -NotIn ("PSPath","PSParentPath","SQL","PSChildName","PSDRIVE","PSProvider") | ForEach-Object{Write-Host ($myMachineName+","+$myDomainName+","+$_.Name+","+$_.Value);$myInstanceCollection.Add([InstanceObject]::New($myMachineName,$myDomainName,$_.Name,$_.Value,'1433',$false,"","","","",""))};
            $myInstanceCollection | ForEach-Object{$myRegInstanceFilter='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\'+$myInstance.InstanceRegName+'\MSSQLServer\SuperSocketNetLib\Tcp\IPAll';$_.InstancePort=(Get-ItemProperty -Path $myRegInstanceFilter).TcpPort};
            $myInstanceCollection | ForEach-Object{$myRegInstanceFilter='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\'+$myInstance.InstanceRegName+'\MSSQLServer\SuperSocketNetLib';$_.ForceEncryption=(Get-ItemProperty -Path $myRegInstanceFilter).ForceEncryption};
            $myInstanceCollection | ForEach-Object{$myRegInstanceFilter='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\'+$myInstance.InstanceRegName+'\MSSQLServer';$_.DefaultDataPath=(Get-ItemProperty -Path $myRegInstanceFilter).DefaultData;$_.DefaultLogPath=(Get-ItemProperty -Path $myRegInstanceFilter).DefaultLog;$_.DefaultBackupPath=(Get-ItemProperty -Path $myRegInstanceFilter).BackupDirectory};
            $myInstanceCollection | ForEach-Object{$myRegInstanceFilter='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\'+$myInstance.InstanceRegName+'\Setup';$_.Collation=(Get-ItemProperty -Path $myRegInstanceFilter).Collation;$_.PatchLevel=(Get-ItemProperty -Path $myRegInstanceFilter).PatchLevel};
            $myAnswer=$myInstanceCollection.ToArray([InstanceObject]);
        }
        catch
        {
            $myAnswer=$null;
            Write-Error($_.ToString());
            throw;
        }
        return $myAnswer;
    }
}
Class Database {    # Database level common functions
    static [bool]Test_DatabaseConnectivity([string]$ConnectionString,[string]$DatabaseName) {  # Test Database connectivity
        [bool]$myAnswer=$false;
        [string]$myCommand=$null;
        
        $DatabaseName=Data.Clean_Parameters($DatabaseName);
        $myCommand="
            USE ["+$DatabaseName+"];
            SELECT [name] AS Result FROM [master].[sys].[databases] WHERE name = '" + $DatabaseName + "';
            ";
        try{
            $myRecord=Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop;
            if ($null -ne $myRecord) {$myAnswer=$true} else {$myAnswer=$false}
        }Catch{
            $myAnswer=$false;
            Write-Error($_.ToString());
            throw;
        }
        return $myAnswer
    }
    static [bool]Execute_SqlCommand([string]$ConnectionString,[string]$CommandText) {    # Execute SQL Command via ADO.NET
        [bool]$myAnswer=$false;

        try
        {
            $mySqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
            $mySqlCommand = $mySqlConnection.CreateCommand();
            $mySqlConnection.Open(); 
            $mySqlCommand.CommandText = $CommandText;                      
            $mySqlCommand.ExecuteNonQuery();
            $myAnswer=$true;
        }
        catch
        {       
            $myAnswer=$false;
            Write-Error($_.ToString());
            Throw;
        }
        finally
        {
            $mySqlCommand.Dispose();
            $mySqlConnection.Close();
            $mySqlConnection.Dispose();
            #[System.Data.SqlClient.SqlConnection]::ClearAllPools();  
        }
        return $myAnswer;
    }
    static [System.Data.DataSet]Execute_SqlQuery([string]$ConnectionString,[string]$CommandText) {    # Execute SQL Query via ADO.NET
        [System.Data.DataSet]$myAnswer=$null;
        try
        {
            $mySqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
            $mySqlCommand = $mySqlConnection.CreateCommand();
            $mySqlConnection.Open(); 
            $mySqlCommand.CommandText = $CommandText;                      
            $myDataSet = New-Object System.Data.DataSet;
            $mySqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter;
            $mySqlDataAdapter.SelectCommand = $mySqlCommand;
            $mySqlDataAdapter.Fill($myDataSet);
            $myAnswer=$myDataSet;
        }
        catch
        {       
            $myAnswer=$null;
            Write-Error($_.ToString());
            Throw;
        }
        finally
        {
            $mySqlCommand.Dispose();
            $mySqlConnection.Close();
            $mySqlConnection.Dispose();
            #[System.Data.SqlClient.SqlConnection]::ClearAllPools();  
        }
        return $myAnswer;
    }
    static [bool]Download_BLOB([string]$ConnectionString,[string]$CommandText,[string]$DestinationFilePath) {    # Download blobs from database to a file via ADO.NET
        [bool]$myAnswer=$false;
        try
        {
            $mySqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
            $mySqlCommand = $mySqlConnection.CreateCommand();
            $mySqlConnection.Open(); 
            $mySqlCommand.CommandText = $CommandText;                      
            # New Command and Reader
            $myReader = $mySqlCommand.ExecuteReader();
    
            # Create a byte array for the stream.
            $myBufferSize = 8192*8;
            $myOut = [array]::CreateInstance('Byte', $myBufferSize)

            # Looping through records
            While ($myReader.Read())
            {
                #Create Directory if not exists and remove any Existing item
                $myFolderPath=Split-Path $DestinationFilePath
                IF (-not (Test-Path -Path $myFolderPath -PathType Container)) {
                    New-Item -Path $myFolderPath -ItemType Directory -Force
                    #$myDestinationFolderPath=$DestinationFilePath.Substring(0,($DestinationFilePath.Length-$DestinationFilePath.Split("\")[-1].Length))
                    #New-Item -ItemType Directory -Path $myDestinationFolderPath -Force
                }
                IF (Test-Path -Path $DestinationFilePath -PathType Leaf) {Move-Item -Path $DestinationFilePath -Force}
        
                # New BinaryWriter, write content to specified file on (zero based) first column (FileContent)
                $myFileStream = New-Object System.IO.FileStream $DestinationFilePath, Create, Write;
                $myBinaryWriter = New-Object System.IO.BinaryWriter $myFileStream;

                $myStart = 0;
                # Read first byte stream from (zero based) first column (FileContent)
                $myReceived = $myReader.GetBytes(0, $myStart, $myOut, 0, $myBufferSize - 1);
                While ($myReceived -gt 0)
                {
                    $myBinaryWriter.Write($myOut, 0, $myReceived);
                    $myBinaryWriter.Flush();
                    $myStart += $myReceived;
                    # Read next byte stream from (zero based) first column (FileContent)
                    $myReceived = $myReader.GetBytes(0, $myStart, $myOut, 0, $myBufferSize - 1);
                }

                $myBinaryWriter.Close();
                $myFileStream.Close();
                
                if (-not (Test-Path -Path $DestinationFilePath) -or -not ($myFileStream)) {
                    $myAnswer=$false;
                } else {
                    $myAnswer=$true;
                }
                
                # Closing & Disposing all objects
                if ($myFileStream) {$myFileStream.Dispose()};
            }
            $myReader.Close();
            return $myAnswer
        }
        catch
        {       
            $myAnswer=$false;
            Write-Error($_.ToString());
            Throw;
        }
        finally
        {
            $mySqlCommand.Dispose();
            $mySqlConnection.Close();
            $mySqlConnection.Dispose();
            #[System.Data.SqlClient.SqlConnection]::ClearAllPools();  
        }
        return $myAnswer;
    }
    static [bool]Download_BLOB([string]$ConnectionString,[hashtable]$FileQueryList,[string]$DestinationFolderPath) {    # Download multiple blobs from database to a folder via ADO.NET
        [bool]$myAnswer=$false;
        try{
            [int]$myRequestCount=$FileQueryList.Count;
            [int]$myDownloadedCount=0;
            [bool]$myDownloadResult=$false;
            if ($DestinationFolderPath[-1] -ne "\") {$DestinationFolderPath+="\"}
            foreach ($myItem in $FileQueryList.GetEnumerator()) {
                [string]$myFile=$myItem.Key.ToString().Trim();
                [string]$myBlobQuery=$myItem.Value.ToString().Trim();
                $myFilePath=$DestinationFolderPath + $myFile;
                If ($myFile.Length -gt 0 -and $DestinationFolderPath.Length -gt 0) {
                    Write-Output ("Multiple file downloader: Downloading " + $myFilePath + " ...");
                    $myDownloadResult=Database.Download_BLOB($ConnectionString,$myBlobQuery,$myFilePath);
                } else {
                    $myDownloadResult=$false;
                }
                if ($myDownloadResult) {$myDownloadedCount+=1}
            }
            if ($myDownloadedCount -eq $myRequestCount) {$myAnswer=$true}
        }catch{
            $myAnswer=$false
            Write-Error($_.ToString())
            Throw;
        }
        return $myAnswer;
    }
}
Class Data {    # Data level common functions
    static [string]Clean_Parameters([string]$ParameterValue,[bool]$RemoveWildcard){  # Remove injection like characters
        [string]$myAnswer=$null;
        [string[]]$myProhibitedPhrases=$null;

        try{
            $myProhibitedPhrases.Add(";");
            if ($RemoveWildcard)    {$myProhibitedPhrases.Add("%")};
            $myAnswer = Data.Clean_String($ParameterValue,$myProhibitedPhrases);
        }catch{
            $myAnswer=$null;
            Write-Error($_.ToString());
            throw;
        }
        return $myAnswer;
    }
    static [string]Clean_String([string]$InputString,[string[]]$ProhibitedPhrases){  # Remove Prohibited Phrases from InputString
        [string]$myAnswer=$null;

        try{
            $myAnswer=$InputString;
            foreach ($ProhibitedPhrase in $ProhibitedPhrases){
                $myAnswer=$myAnswer.Replace($ProhibitedPhrase,"");
            }
        }catch{
            $myAnswer=$null;
            Write-Error($_.ToString());
            throw;
        }
        return $myAnswer;
    }
}