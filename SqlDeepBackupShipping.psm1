Using module .\SqlDeepLogWriter.psm1
Using module .\SqlDeepCommon.psm1

enum DatabaseGroup {
    ALL_DATABASES
    SYSTEM_DATABASES
    USER_DATABASES
}
enum BackupType {
    FULL
    DIFF
    LOG
}
enum DestinationType {
    UNC
    FTP
    SFTP
    SCP
    LOCAL
}
enum ActionType {
    Copy
    Move
}
enum HostOperation {
    UPLOAD
    DOWNLOAD
    DELETE
    MKDIR
    DIR
    ISALIVE
}
Class BackupCatalogItem {
    [int]$Id
    [string]$BatchUid
    [datetime]$EventTimeStamp
    [string]$Destination
    [string]$DestinationFolder
    [string]$UncBackupFilePath
    [int]$MediaSetId
    [int]$FamilySequenceNumber
    [string]$ServerName
    [string]$InstanceName
    [string]$DatabaseName
    [datetime]$BackupStartTime
    [datetime]$BackupFinishTime
    [datetime]$ExpirationDate
    [string]$BackupType
    [decimal]$FirstLsn
    [decimal]$LastLsn
    [string]$FileName
    [string]$FilePath
    [int]$MaxFamilySequenceNumber
    [datetime]$DeleteDate
    [bool]$IsDeleted
    [string]$TransferStatus
   
    BackupCatalogItem([int]$Id,[string]$BatchUid,[datetime]$EventTimeStamp,[string]$Destination,[string]$DestinationFolder,[string]$UncBackupFilePath,[int]$MediaSetId,[int]$FamilySequenceNumber,[string]$ServerName,[string]$InstanceName,[string]$DatabaseName,[datetime]$BackupStartTime,[datetime]$BackupFinishTime,[datetime]$ExpirationDate,[string]$BackupType,[decimal]$FirstLsn,[decimal]$LastLsn,[string]$FilePath,[string]$FileName,[int]$MaxFamilySequenceNumber,[datetime]$DeleteDate,[bool]$IsDeleted,[string]$TransferStatus){
        Write-Verbose 'BackupCatalogItem object initializing started'
        $this.Id=$Id
        $this.BatchUid=$BatchUid
        $this.EventTimeStamp=$EventTimeStamp
        $this.Destination=$Destination
        $this.DestinationFolder=$DestinationFolder
        $this.UncBackupFilePath=$UncBackupFilePath
        $this.MediaSetId=$MediaSetId
        $this.FamilySequenceNumber=$FamilySequenceNumber
        $this.ServerName=$ServerName
        $this.InstanceName=$InstanceName
        $this.DatabaseName=$DatabaseName
        $this.BackupStartTime=$BackupStartTime
        $this.BackupFinishTime=$BackupFinishTime
        $this.ExpirationDate=$ExpirationDate
        $this.BackupType=$BackupType
        $this.FirstLsn=$FirstLsn
        $this.LastLsn=$LastLsn
        $this.FilePath=$FilePath
        $this.FileName=$FileName
        $this.MaxFamilySequenceNumber=$MaxFamilySequenceNumber
        $this.DeleteDate=$DeleteDate
        $this.IsDeleted=$IsDeleted
        $this.TransferStatus=$TransferStatus
        Write-Verbose 'BackupCatalogItem object initialized'
    }
}
Class BackupFile {
    [int]$FamilySequenceNumber
    [int]$MaxFamilySequenceNumber
    [string]$ServerName
    [string]$InstanceName
    [string]$DatabaseName
    [datetime]$BackupStartTime
    [datetime]$BackupFinishTime
    [datetime]$ExpirationDate
    [string]$BackupType
    [decimal]$FirstLsn
    [decimal]$LastLsn
    [int]$MediaSetId
    [string]$FilePath
    [string]$FileName
    [string]$RemoteSourceFilePath
    [string]$RemoteRepositoryUncFilePath
    [string]$DestinationFolder
    
    BackupFile([string]$ServerName,[string]$InstanceName,[int]$FamilySequenceNumber,[int]$MaxFamilySequenceNumber,[string]$DatabaseName,[datetime]$BackupStartTime,[datetime]$BackupFinishTime,[datetime]$ExpirationDate,[string]$BackupType,[decimal]$FirstLsn,[decimal]$LastLsn,[int]$MediaSetId,[string]$FilePath,[string]$FileName,[string]$DestinationFolderTemplate){
        Write-Verbose 'BackupFile object initializing started'
        $this.FamilySequenceNumber=$FamilySequenceNumber
        $this.MaxFamilySequenceNumber=$MaxFamilySequenceNumber
        $this.ServerName=$ServerName
        $this.InstanceName=$InstanceName
        $this.DatabaseName=$DatabaseName
        $this.BackupStartTime=$BackupStartTime
        $this.BackupFinishTime=$BackupFinishTime
        $this.ExpirationDate=$ExpirationDate
        $this.BackupType=$BackupType
        $this.FirstLsn=$FirstLsn
        $this.LastLsn=$LastLsn
        $this.MediaSetId=$MediaSetId
        $this.FilePath=$FilePath
        $this.FileName=$FileName
        $this.RemoteSourceFilePath=$this.CalcRemoteSourceFilePath()
        $this.DestinationFolder=$this.CalcDestinationFolderPath($DestinationFolderTemplate)
        Write-Verbose 'BackupFile object initialized'
    }
    hidden [string]CalcRemoteSourceFilePath() {    #Converting local path to UNC path
        Write-Verbose 'Processing Started.'
        [string]$myAnswer=$null
        [string]$myUncPath=$null
        
        if ($this.FilePath.Contains('\\') -eq $false) {
            $myUncPath='\\' + $this.ServerName + '\' + ($this.FilePath.Split(':') -Join '$')
            $myAnswer=$myUncPath
        }else {
            $myAnswer=$this.FilePath
        }
        return $myAnswer
    }
    hidden [string]CalcDestinationFolderPath([string]$FolderTemplate){  #Replace Generic variables of Destination path by it's values
        Write-Verbose 'Processing Started.'
        [string]$myAnswer=$null;
        [System.Globalization.PersianCalendar]$myPersianCalendar=$null
        [hashtable]$myMapGregorianWeekDayToPersianWeekDay=$null
        [string]$myJalaliYear=''
        [string]$myJalaliMonth=''
        [string]$myJalaliDayOfMonth=''
        [string]$myJalaliDayOfWeek=''
        [string]$myGregorianYear=''
        [string]$myGregorianMonth=''
        [string]$myGregorianDayOfMonth=''
        [string]$myGregorianDayOfWeek=''
        [string]$myServerName=''
        [string]$myInstanceName=''
        [string]$myDatabaseName=''

        $myAnswer=$FolderTemplate
        $myPersianCalendar=New-Object system.globalization.persiancalendar
        $myMapGregorianWeekDayToPersianWeekDay=@{6='1';0='2';1='3';2='4';3='5';4='6';5='7'}
        $myJalaliYear=$myPersianCalendar.GetYear($this.BackupStartTime).ToString()
        $myJalaliMonth=$myPersianCalendar.GetMonth($this.BackupStartTime).ToString()
        $myJalaliDayOfMonth=$myPersianCalendar.GetDayOfMonth($this.BackupStartTime).ToString()
        $myJalaliDayOfWeek=$myMapGregorianWeekDayToPersianWeekDay.Item($this.BackupStartTime.DayOfWeek.value__)
        $myGregorianYear=$this.BackupStartTime.ToString('yyyy')
        $myGregorianMonth=$this.BackupStartTime.ToString('MM')
        $myGregorianDayOfMonth=$this.BackupStartTime.ToString('dd')
        $myGregorianDayOfWeek=([int]$this.BackupStartTime.DayOfWeek).ToString()
        $myServerName=$this.ServerName.Replace(' ','_')
        $myInstanceName=$this.InstanceName.Replace(' ','_')
        $myDatabaseName=$this.DatabaseName.Replace(' ','_')
        if ($myJalaliMonth.Length -eq 1) {$myJalaliMonth='0'+$myJalaliMonth}
        if ($myJalaliDayOfMonth.Length -eq 1) {$myJalaliDayOfMonth='0'+$myJalaliDayOfMonth}

        $myAnswer=$myAnswer.
            Replace('{Year}',$myGregorianYear).
            Replace('{Month}',$myGregorianMonth).
            Replace('{Day}',$myGregorianDayOfMonth).
            Replace('{DayOfWeek}',$myGregorianDayOfWeek).
            Replace('{JYear}',$myJalaliYear).
            Replace('{JMonth}',$myJalaliMonth).
            Replace('{JDay}',$myJalaliDayOfMonth).
            Replace('{JDayOfWeek}',$myJalaliDayOfWeek).
            Replace('{ServerName}',$myServerName).
            Replace('{InstanceName}',$myInstanceName).
            Replace('{DatabaseName}',$myDatabaseName)
        if ($myAnswer.ToUpper() -like "*{CustomRule01}*".ToUpper()) {$myAnswer=$this.CalcDestinationFolderPath_CustomRule01($myAnswer)}
        if ($myAnswer.ToUpper() -like "*{CustomRule02(G)}*".ToUpper()) {$myAnswer=$this.CalcDestinationFolderPath_CustomRule02($myAnswer,'Gregorian')}
        if ($myAnswer.ToUpper() -like "*{CustomRule02(J)}*".ToUpper()) {$myAnswer=$this.CalcDestinationFolderPath_CustomRule02($myAnswer,'Jalali')}
        return $myAnswer
    }
    hidden [string]CalcDestinationFolderPath_CustomRule01([string]$FolderTemplate){  #Put log backups in disk_only folder and other backup types in tape_only folder
        Write-Verbose 'Processing Started.'
        [string]$myAnswer=$null;
        [string]$myRuleName=$null;

        $myAnswer=$FolderTemplate
        $myRuleName='{CustomRule01}'
        if ($this.BackupType -eq 'L') {
            $myAnswer=$myAnswer.Replace($myRuleName, 'disk_only')
        }else{
            $myAnswer=$myAnswer.Replace($myRuleName, 'tape_only')
        }
        return $myAnswer
    }
    hidden [string]CalcDestinationFolderPath_CustomRule02([string]$FolderTemplate,[string]$CalendarType){  #Put backup files of first day of week in 'weekly' folder, first day of month in 'monthly' folder and first day of year in 'yearly' folder and other days in 'daily' folder according to gregorian(G) or Jalali(J) fashion calendar
        Write-Verbose 'Processing Started.'
        [string]$myAnswer=$null;
        [string]$myRuleName=$null;
        [System.Globalization.PersianCalendar]$myPersianCalendar=$null
        [hashtable]$myMapGregorianWeekDayToPersianWeekDay=$null
        [string]$myJalaliYear=''
        [string]$myJalaliMonth=''
        [string]$myJalaliDayOfMonth=''
        [string]$myJalaliDayOfWeek=''
        [string]$myGregorianYear=''
        [string]$myGregorianMonth=''
        [string]$myGregorianDayOfMonth=''
        [string]$myGregorianDayOfWeek=''

        $myAnswer=$FolderTemplate
        $CalendarType=$CalendarType.ToUpper()
        if ( $CalendarType -notin ('Gregorian'.ToUpper() , 'Jalali'.ToUpper()) ) {$CalendarType='Gregorian'.ToUpper()} 

        $myPersianCalendar=New-Object system.globalization.persiancalendar
        $myMapGregorianWeekDayToPersianWeekDay=@{6='1';0='2';1='3';2='4';3='5';4='6';5='7'}
        $myJalaliYear=$myPersianCalendar.GetYear($this.BackupStartTime).ToString()
        $myJalaliMonth=$myPersianCalendar.GetMonth($this.BackupStartTime).ToString()
        $myJalaliDayOfMonth=$myPersianCalendar.GetDayOfMonth($this.BackupStartTime).ToString()
        $myJalaliDayOfWeek=$myMapGregorianWeekDayToPersianWeekDay.Item($this.BackupStartTime.DayOfWeek.value__)
        $myGregorianYear=$this.BackupStartTime.ToString('yyyy')
        $myGregorianMonth=$this.BackupStartTime.ToString('MM')
        $myGregorianDayOfMonth=$this.BackupStartTime.ToString('dd')
        $myGregorianDayOfWeek=([int]$this.BackupStartTime.DayOfWeek).ToString()
        if ($myJalaliMonth.Length -eq 1) {$myJalaliMonth='0'+$myJalaliMonth}
        if ($myJalaliDayOfMonth.Length -eq 1) {$myJalaliDayOfMonth='0'+$myJalaliDayOfMonth}

        switch ($CalendarType) {
            'Gregorian'.ToUpper()   {
                    $myRuleName='{CustomRule02(G)}'
                    IF ($myGregorianMonth -eq '01' -and $myGregorianDayOfMonth -eq '01') {$myAnswer=$myAnswer.Replace($myRuleName, 'yearly')}
                    ELSEIF ($myGregorianDayOfMonth -eq '01') {$myAnswer=$myAnswer.Replace($myRuleName, 'monthly')}
                    ELSEIF ($myGregorianDayOfWeek -eq '1') {$myAnswer=$myAnswer.Replace($myRuleName, 'weekly')}
                    ELSE {$myAnswer=$myAnswer.Replace($myRuleName, 'daily')}
                }
            'Jalali'.ToUpper()      {
                    $myRuleName='{CustomRule02(J)}' 
                    IF ($myJalaliMonth -eq '01' -and $myJalaliDayOfMonth -eq '01') {$myAnswer=$myAnswer.Replace($myRuleName, 'yearly')}
                    ELSEIF ($myJalaliDayOfMonth -eq '01') {$myAnswer=$myAnswer.Replace($myRuleName, 'monthly')}
                    ELSEIF ($myJalaliDayOfWeek -eq '1') {$myAnswer=$myAnswer.Replace($myRuleName, 'weekly')}
                    ELSE {$myAnswer=$myAnswer.Replace($myRuleName, 'daily')}
                }
        }

        return $myAnswer
    }
    [void] Populate_DestinationFolder ([string]$FolderTemplate){
        Write-Verbose 'Processing Started.'
        $this.DestinationFolder=$this.CalcDestinationFolderPath($FolderTemplate)
    }
}
Class BackupShipping {
    [string]$SourceInstanceConnectionString;
    [string[]]$Databases;
    [BackupType[]]$BackupTypes;
    [int]$HoursToScanForUntransferredBackups;
    [DestinationType]$DestinationType;
    [string]$Destination;
    [string]$DestinationFolderStructure;
    [string]$SshHostKeyFingerprint;
    [ActionType]$ActionType;
    [string]$RetainDaysOnDestination;
    [string]$TransferedFileDescriptionSuffix;
    [string]$BackupShippingCatalogTableName;
    [string]$WinScpPath='C:\Program Files (x86)\WinSCP\WinSCPnet.dll';
    [System.Net.NetworkCredential]$DestinationCredential;
    hidden [LogWriter]$LogWriter;
    hidden [string]$BatchUid;
    hidden [string]$LogStaticMessage='';

    BackupShipping(){
    }
    BackupShipping([string]$SourceInstanceConnectionString,[BackupType[]]$BackupTypes,[int]$HoursToScanForUntransferredBackups,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[string]$RetainDaysOnDestination,[string]$TransferedFileDescriptionSuffix,[string]$BackupShippingCatalogTableName,[LogWriter]$LogWriter){
        [string[]]$myDatabases=$null;
        [ActionType]$myActionType=$null;
        [string]$myWinScpPath=$null;
        [System.Net.NetworkCredential]$myDestinationCredential=$null;
        [string]$mySshHostKeyFingerprint=$null;

        $this.Init($SourceInstanceConnectionString,$myDatabases,$BackupTypes,$HoursToScanForUntransferredBackups,$DestinationType,$Destination,$DestinationFolderStructure,$mySshHostKeyFingerprint,$myActionType,$RetainDaysOnDestination,$TransferedFileDescriptionSuffix,$BackupShippingCatalogTableName,$myWinScpPath,$myDestinationCredential,$LogWriter)
    }
    BackupShipping([string]$SourceInstanceConnectionString,[string[]]$Databases,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[LogWriter]$LogWriter){
        [BackupType[]]$myBackupTypes=$null;
        [ActionType]$myActionType=$null;
        [string]$myTransferedFileDescriptionSuffix=$null;
        [string]$myBackupShippingCatalogTableName=$null;
        [string]$myWinScpPath=$null;
        [System.Net.NetworkCredential]$myDestinationCredential=$null;
        [int]$myHoursToScanForUntransferredBackups=$null;
        [string]$myRetainDaysOnDestination=$null;
        [string]$mySshHostKeyFingerprint=$null;

        $this.Init($SourceInstanceConnectionString,$Databases,$myBackupTypes,$myHoursToScanForUntransferredBackups,$DestinationType,$Destination,$DestinationFolderStructure,$mySshHostKeyFingerprint,$myActionType,$myRetainDaysOnDestination,$myTransferedFileDescriptionSuffix,$myBackupShippingCatalogTableName,$myWinScpPath,$myDestinationCredential,$LogWriter)
    }
    BackupShipping([string]$SourceInstanceConnectionString,[string[]]$Databases,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[string]$SshHostKeyFingerprint,[LogWriter]$LogWriter){
        [BackupType[]]$myBackupTypes=$null;
        [ActionType]$myActionType=$null;
        [string]$myTransferedFileDescriptionSuffix=$null;
        [string]$myBackupShippingCatalogTableName=$null;
        [string]$myWinScpPath=$null;
        [System.Net.NetworkCredential]$myDestinationCredential=$null;
        [int]$myHoursToScanForUntransferredBackups=$null;
        [string]$myRetainDaysOnDestination=$null;

        $this.Init($SourceInstanceConnectionString,$Databases,$myBackupTypes,$myHoursToScanForUntransferredBackups,$DestinationType,$Destination,$DestinationFolderStructure,$SshHostKeyFingerprint,$myActionType,$myRetainDaysOnDestination,$myTransferedFileDescriptionSuffix,$myBackupShippingCatalogTableName,$myWinScpPath,$myDestinationCredential,$LogWriter)
    }
    BackupShipping([string]$SourceInstanceConnectionString,[string[]]$Databases,[int]$HoursToScanForUntransferredBackups,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[string]$SshHostKeyFingerprint,[string]$RetainDaysOnDestination,[LogWriter]$LogWriter){
        [BackupType[]]$myBackupTypes=$null;
        [ActionType]$myActionType=$null;
        [string]$myTransferedFileDescriptionSuffix=$null;
        [string]$myBackupShippingCatalogTableName=$null;
        [string]$myWinScpPath=$null;
        [System.Net.NetworkCredential]$myDestinationCredential=$null;

        $this.Init($SourceInstanceConnectionString,$Databases,$myBackupTypes,$HoursToScanForUntransferredBackups,$DestinationType,$Destination,$DestinationFolderStructure,$SshHostKeyFingerprint,$myActionType,$RetainDaysOnDestination,$myTransferedFileDescriptionSuffix,$myBackupShippingCatalogTableName,$myWinScpPath,$myDestinationCredential,$LogWriter)
    }
    BackupShipping([string]$SourceInstanceConnectionString,[string[]]$Databases,[int]$HoursToScanForUntransferredBackups,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[string]$SshHostKeyFingerprint,[string]$RetainDaysOnDestination,[string]$TransferedFileDescriptionSuffix,[string]$BackupShippingCatalogTableName,[string]$WinScpPath=$null,[System.Net.NetworkCredential]$DestinationCredential,[LogWriter]$LogWriter){
        [BackupType[]]$myBackupTypes=$null;
        [ActionType]$myActionType=$null;

        $this.Init($SourceInstanceConnectionString,$Databases,$myBackupTypes,$HoursToScanForUntransferredBackups,$DestinationType,$Destination,$DestinationFolderStructure,$SshHostKeyFingerprint,$myActionType,$RetainDaysOnDestination,$TransferedFileDescriptionSuffix,$BackupShippingCatalogTableName,$WinScpPath,$DestinationCredential,$LogWriter)
    }
    BackupShipping([string]$SourceInstanceConnectionString,[string[]]$Databases,[BackupType[]]$BackupTypes,[int]$HoursToScanForUntransferredBackups,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[string]$SshHostKeyFingerprint,[ActionType]$ActionType,[string]$RetainDaysOnDestination,[string]$TransferedFileDescriptionSuffix,[string]$BackupShippingCatalogTableName,[string]$WinScpPath,[System.Net.NetworkCredential]$DestinationCredential,[LogWriter]$LogWriter){
        $this.Init($SourceInstanceConnectionString,$Databases,$BackupTypes,$HoursToScanForUntransferredBackups,$DestinationType,$Destination,$DestinationFolderStructure,$SshHostKeyFingerprint,$ActionType,$RetainDaysOnDestination,$TransferedFileDescriptionSuffix,$BackupShippingCatalogTableName,$WinScpPath,$DestinationCredential,$LogWriter)
    }
    hidden Init([string]$SourceInstanceConnectionString,[string[]]$Databases,[BackupType[]]$BackupTypes,[int]$HoursToScanForUntransferredBackups,[DestinationType]$DestinationType,[string]$Destination,[string]$DestinationFolderStructure,[string]$SshHostKeyFingerprint,[ActionType]$ActionType,[string]$RetainDaysOnDestination,[string]$TransferedFileDescriptionSuffix,[string]$BackupShippingCatalogTableName,[string]$WinScpPath,[System.Net.NetworkCredential]$DestinationCredential,[LogWriter]$LogWriter){
        try
        {
            Write-Verbose 'Initialization started.'
            $this.SourceInstanceConnectionString=$SourceInstanceConnectionString;
            $this.Databases=$Databases;
            $this.BackupTypes=$BackupTypes;
            $this.HoursToScanForUntransferredBackups=$HoursToScanForUntransferredBackups;
            $this.DestinationType=$DestinationType;
            $this.Destination=$Destination;
            $this.DestinationFolderStructure=$DestinationFolderStructure;
            $this.SshHostKeyFingerprint=$SshHostKeyFingerprint;
            $this.ActionType=$ActionType;
            $this.RetainDaysOnDestination=$RetainDaysOnDestination;
            $this.TransferedFileDescriptionSuffix=$TransferedFileDescriptionSuffix;
            $this.BackupShippingCatalogTableName=$BackupShippingCatalogTableName;
            $this.WinScpPath=$WinScpPath;
            $this.DestinationCredential=$DestinationCredential;
            $this.LogWriter=$LogWriter;

            if($null -eq $this.BackupTypes){$this.BackupTypes=([BackupType]::FULL,[BackupType]::DIFF,[BackupType]::LOG)};
            if($null -eq $this.HoursToScanForUntransferredBackups){$this.HoursToScanForUntransferredBackups=72};
            if($null -eq $this.ActionType){$this.ActionType=[ActionType]::Copy};
            if($null -eq $this.TransferedFileDescriptionSuffix){$this.TransferedFileDescriptionSuffix='Transfered'};
            if($null -eq $this.WinScpPath){$this.WinScpPath='C:\Program Files (x86)\WinSCP\WinSCPnet.dll'};
            if($null -eq $this.RetainDaysOnDestination){$this.RetainDaysOnDestination='7'};
            if($null -eq $this.BackupShippingCatalogTableName){$this.BackupShippingCatalogTableName='TransferredFiles'}
            
            Write-Verbose 'Initialization finished.'
        }catch{
            Write-Verbose 'Initialization failed.'
            $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
            throw ('Initialization failed.')
        }
    }
#region Functions
hidden [string]Path_CorrectFolderPathFormat ([string]$FolderPath) {    #Correcting folder path format
    if ($this.LogWriter) {
        $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    } else {
        Write-Verbose 'Processing Started.'
    }
    [string]$myAnswer=$null
    $FolderPath=$FolderPath.Trim()
    if ($FolderPath.ToCharArray()[-1] -eq '\') {$FolderPath=$FolderPath.Substring(0,$FolderPath.Length)}    
    $myAnswer=$FolderPath
    return $myAnswer
}
hidden [bool]Create_ShippedBackupsCatalog() {   #Create Log Table to Write Logs of transfered files in a table, if not exists
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [bool]$myAnswer=[bool]$true
    [string]$myCommand=$null

    $this.BackupShippingCatalogTableName=Clear-SqlParameter -ParameterValue $this.BackupShippingCatalogTableName -RemoveSpace -RemoveWildcard -RemoveBraces -RemoveSingleQuote -RemoveDoubleQuote -RemoveDollerSign
    $myCommand="
    DECLARE @myTableName nvarchar(255)
    SET @myTableName=N'"+ $this.BackupShippingCatalogTableName +"'
    
    IF NOT EXISTS (
        SELECT 
            1
        FROM 
            [sys].[all_objects] AS myTable
            INNER JOIN [sys].[schemas] AS mySchema ON [myTable].[schema_id]=[mySchema].[schema_id]
        WHERE 
            [mySchema].[name] + '.' + [myTable].[name] = [mySchema].[name] + '.' + REPLACE(REPLACE(@myTableName,'[',''),']','')
    ) BEGIN
        CREATE TABLE [dbo].[" + $this.BackupShippingCatalogTableName + "](
            [Id] [bigint] IDENTITY(1,1) NOT NULL,
            [BatchId] [uniqueidentifier] NOT NULL,
            [EventTimeStamp] [datetime] NOT NULL DEFAULT (getdate()),
            [Destination] [nvarchar](128) NOT NULL,
            [DestinationFolder] [nvarchar](4000) NOT NULL,
            [UncBackupFilePath] [nvarchar](4000) NOT NULL,
            [media_set_id] [int] NOT NULL,
            [family_sequence_number] [int] NOT NULL,
            [MachineName] [nvarchar](255) NULL,
            [InstanceName] [nvarchar](255) NOT NULL,
            [DatabaseName] [nvarchar](255) NOT NULL,
            [backup_start_date] [datetime] NOT NULL,
            [backup_finish_date] [datetime] NOT NULL,
            [expiration_date] [datetime] NULL,
            [BackupType] [nvarchar](255) NOT NULL,
            [BackupFirstLSN] [decimal](28, 0) NULL,
            [BackupLastLSN] [decimal](28, 0) NULL,
            [BackupFilePath] [nvarchar](4000) NOT NULL,
            [BackupFileName] [nvarchar](4000) NOT NULL,
            [max_family_sequence_number] [int] NOT NULL,
            [DeleteDate] [datetime] NULL,
            [IsDeleted] [bit] NOT NULL DEFAULT ((0)),
            [TransferStatus] [nvarchar](50) NOT NULL DEFAULT (N'NONE'),
        PRIMARY KEY CLUSTERED  ([Id] ASC) WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF, DATA_COMPRESSION = PAGE) ON [PRIMARY]
        ) ON [PRIMARY];
        CREATE UNIQUE NONCLUSTERED INDEX UNQIX_dbo_"+$this.BackupShippingCatalogTableName+"_Rec ON [dbo].["+$this.BackupShippingCatalogTableName+"] (Destination,DestinationFolder,Media_set_id,Family_sequence_number,InstanceName,DatabaseName) WITH (FillFactor=85,PAD_INDEX=ON,SORT_IN_TEMPDB=ON,DATA_COMPRESSION=PAGE);
        CREATE NONCLUSTERED INDEX [NCIX_dbo_"+$this.BackupShippingCatalogTableName+"_TransferStatus] ON [dbo].["+$this.BackupShippingCatalogTableName+"] ([TransferStatus] ASC)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 85, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF, DATA_COMPRESSION = PAGE);
    END
    "
    try{
        Write-Verbose $myCommand
        Invoke-Sqlcmd -ConnectionString ($this.LogWriter.LogInstanceConnectionString) -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -ErrorAction Stop
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $myAnswer=[bool]$false
    }
    return $myAnswer
}
hidden [void]New_ShippedBackupsCatalogItem([BackupFile]$BackupFile,[string]$TransferStatus) {  #Create TransferredFiles Table to Write transferred backup files log to a database table if not exists
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$true
    [string]$myCommand=$null

    $myCommand="
        DECLARE @myBatchId [uniqueidentifier]
        DECLARE @myEventTimeStamp [datetime]
        DECLARE @myDestination [nvarchar](128)
        DECLARE @myDestinationFolder [nvarchar](4000)
        DECLARE @myUncBackupFilePath [nvarchar](4000)
        DECLARE @myMedia_set_id [int]
        DECLARE @myFamily_sequence_number [int]
        DECLARE @myMachineName [nvarchar](255) 
        DECLARE @myInstanceName [nvarchar](255)
        DECLARE @myDatabaseName [nvarchar](255)
        DECLARE @myBackup_start_date [datetime]
        DECLARE @myBackup_finish_date [datetime]
        DECLARE @myExpiration_date [datetime] 
        DECLARE @myBackupType [nvarchar](255)
        DECLARE @myBackupFirstLSN [decimal](28, 0) 
        DECLARE @myBackupLastLSN [decimal](28, 0) 
        DECLARE @myBackupFilePath [nvarchar](4000)
        DECLARE @myBackupFileName [nvarchar](4000)
        DECLARE @myMax_family_sequence_number [int]
        DECLARE @myDeleteDate [datetime] 
        DECLARE @myIsDeleted [bit]
        DECLARE @myTransferStatus [nvarchar](50)
        
        SET @myBatchId = '" + $this.BatchUid + "'
        SET @myDestination = N'" + $this.Destination + "'
        SET @myDestinationFolder = N'" + $BackupFile.DestinationFolder + "'
        SET @myUncBackupFilePath = N'" + $BackupFile.RemoteSourceFilePath + "'
        SET @myMedia_set_id = " + $BackupFile.MediaSetId.ToString() + "
        SET @myFamily_sequence_number = " + $BackupFile.FamilySequenceNumber.ToString() + "
        SET @myMachineName = CASE WHEN '" + $BackupFile.ServerName + "'='' THEN NULL ELSE CAST('" + $BackupFile.ServerName + "' AS nvarchar(255)) END
        SET @myInstanceName = '" + $BackupFile.InstanceName + "'
        SET @myDatabaseName = N'" + $BackupFile.DatabaseName + "'
        SET @myBackup_start_date = CAST('" + $BackupFile.BackupStartTime.ToString() + "' AS DATETIME)
        SET @myBackup_finish_date = CAST('" + $BackupFile.BackupFinishTime.ToString() + "' AS DATETIME)
        SET @myExpiration_date = CASE WHEN '" + $BackupFile.ExpirationDate.ToString() + "'='' THEN NULL ELSE CAST('" + $BackupFile.ExpirationDate.ToString() + "' AS DATETIME) END
        SET @myBackupType = N'" + $BackupFile.BackupType + "'
        SET @myBackupFirstLSN = CASE WHEN '" + $BackupFile.FirstLsn.ToString() + "'='' THEN NULL ELSE CAST('" + $BackupFile.FirstLsn.ToString() + "' AS decimal(28,0)) END
        SET @myBackupLastLSN = CASE WHEN '" + $BackupFile.LastLsn.ToString() + "'='' THEN NULL ELSE CAST('" + $BackupFile.LastLsn.ToString() + "' AS decimal(28,0)) END
        SET @myBackupFilePath = N'" + $BackupFile.FilePath + "'
        SET @myBackupFileName = N'" + $BackupFile.FileName + "'
        SET @myMax_family_sequence_number = " + $BackupFile.MaxFamilySequenceNumber.ToString() + "
        SET @myDeleteDate = NULL
        SET @myIsDeleted = 0
        SET @myTransferStatus = N'"+ $TransferStatus +"';
        
        MERGE [dbo].["+$this.BackupShippingCatalogTableName+"] AS myTarget
        USING (SELECT @myBatchId AS BatchId,@myDestination AS Destination,@myDestinationFolder AS DestinationFolder,@myUncBackupFilePath AS UncBackupFilePath,@myMedia_set_id AS Media_set_id,@myFamily_sequence_number AS Family_sequence_number,@myMachineName AS MachineName,@myInstanceName AS InstanceName,@myDatabaseName AS DatabaseName,@myBackup_start_date AS Backup_start_date,@myBackup_finish_date AS Backup_finish_date,@myExpiration_date AS Expiration_date,@myBackupType AS BackupType,@myBackupFirstLSN AS BackupFirstLSN,@myBackupLastLSN AS BackupLastLSN,@myBackupFilePath AS BackupFilePath,@myBackupFileName AS BackupFileName,@myMax_family_sequence_number AS Max_family_sequence_number,@myDeleteDate AS DeleteDate,@myIsDeleted AS IsDeleted,@myTransferStatus AS TransferStatus) AS mySource
            ON myTarget.Destination=mySource.Destination AND myTarget.DestinationFolder=mySource.DestinationFolder AND myTarget.Media_set_id=mySource.Media_set_id AND myTarget.Family_sequence_number=mySource.Family_sequence_number AND myTarget.InstanceName=mySource.InstanceName AND myTarget.DatabaseName=mySource.DatabaseName
        WHEN MATCHED THEN
                UPDATE SET
             [myTarget].[BatchId]=[mySource].[BatchId]
            ,[myTarget].[Destination]=[mySource].[Destination]
            ,[myTarget].[DestinationFolder]=[mySource].[DestinationFolder]
            ,[myTarget].[UncBackupFilePath]=[mySource].[UncBackupFilePath]
            ,[myTarget].[media_set_id]=[mySource].[media_set_id]
            ,[myTarget].[family_sequence_number]=[mySource].[family_sequence_number]
            ,[myTarget].[MachineName]=[mySource].[MachineName]
            ,[myTarget].[InstanceName]=[mySource].[InstanceName]
            ,[myTarget].[DatabaseName]=[mySource].[DatabaseName]
            ,[myTarget].[backup_start_date]=[mySource].[backup_start_date]
            ,[myTarget].[backup_finish_date]=[mySource].[backup_finish_date]
            ,[myTarget].[expiration_date]=[mySource].[expiration_date]
            ,[myTarget].[BackupType]=[mySource].[BackupType]
            ,[myTarget].[BackupFirstLSN]=[mySource].[BackupFirstLSN]
            ,[myTarget].[BackupLastLSN]=[mySource].[BackupLastLSN]
            ,[myTarget].[BackupFilePath]=[mySource].[BackupFilePath]
            ,[myTarget].[BackupFileName]=[mySource].[BackupFileName]
            ,[myTarget].[max_family_sequence_number]=[mySource].[max_family_sequence_number]
            ,[myTarget].[DeleteDate]=[mySource].[DeleteDate]
            ,[myTarget].[IsDeleted]=[mySource].[IsDeleted]
            ,[myTarget].[TransferStatus]=[mySource].[TransferStatus]
        WHEN NOT MATCHED THEN
            INSERT ([BatchId],[Destination],[DestinationFolder],[UncBackupFilePath],[media_set_id],[family_sequence_number],[MachineName],[InstanceName],[DatabaseName],[backup_start_date],[backup_finish_date],[expiration_date],[BackupType],[BackupFirstLSN],[BackupLastLSN],[BackupFilePath],[BackupFileName],[max_family_sequence_number],[DeleteDate],[IsDeleted],[TransferStatus])
            VALUES ([mySource].[BatchId],[mySource].[Destination],[mySource].[DestinationFolder],[mySource].[UncBackupFilePath],[mySource].[media_set_id],[mySource].[family_sequence_number],[mySource].[MachineName],[mySource].[InstanceName],[mySource].[DatabaseName],[mySource].[backup_start_date],[mySource].[backup_finish_date],[mySource].[expiration_date],[mySource].[BackupType],[mySource].[BackupFirstLSN],[mySource].[BackupLastLSN],[mySource].[BackupFilePath],[mySource].[BackupFileName],[mySource].[max_family_sequence_number],[mySource].[DeleteDate],[mySource].[IsDeleted],[mySource].[TransferStatus]);
    "
    try{
        Write-Verbose $myCommand
        Invoke-Sqlcmd -ConnectionString $this.LogWriter.LogInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -ErrorAction Stop
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $this.LogWriter.Write($this.LogStaticMessage+$myCommand, [LogType]::ERR)
        $myAnswer=$false
    }
    #return $myAnswer
}
hidden [void]Set_ShippedBackupsCatalogItemStatus([BackupFile]$BackupFile){
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$true
    [string]$myCommand=$null

    $myCommand="
    DECLARE @myBatchId [uniqueidentifier]
    DECLARE @myEventTimeStamp [datetime]
    DECLARE @myDestination [nvarchar](128)
    DECLARE @myDestinationFolder [nvarchar](4000)
    DECLARE @myUncBackupFilePath [nvarchar](4000)
    DECLARE @myMedia_set_id [int]
    DECLARE @myFamily_sequence_number [int]
    DECLARE @myMachineName [nvarchar](255) 
    DECLARE @myInstanceName [nvarchar](255)
    DECLARE @myDatabaseName [nvarchar](255)
    DECLARE @myBackup_start_date [datetime]
    DECLARE @myBackup_finish_date [datetime]
    DECLARE @myExpiration_date [datetime] 
    DECLARE @myBackupType [nvarchar](255)
    DECLARE @myBackupFirstLSN [decimal](28, 0) 
    DECLARE @myBackupLastLSN [decimal](28, 0) 
    DECLARE @myBackupFilePath [nvarchar](4000)
    DECLARE @myBackupFileName [nvarchar](4000)
    DECLARE @myMax_family_sequence_number [int]
    DECLARE @myDeleteDate [datetime] 
    DECLARE @myIsDeleted [bit]
    DECLARE @myTransferStatus [nvarchar](50)
    
    SET @myBatchId = '" + $this.BatchUid + "'
    SET @myDestination = N'" + $this.Destination + "'
    SET @myDestinationFolder = N'" + $BackupFile.DestinationFolder + "'
    SET @myUncBackupFilePath = N'" + $BackupFile.RemoteSourceFilePath + "'
    SET @myMedia_set_id = " + $BackupFile.MediaSetId.ToString() + "
    SET @myFamily_sequence_number = " + $BackupFile.FamilySequenceNumber.ToString() + "
    SET @myMachineName = CASE WHEN '" + $BackupFile.ServerName + "'='' THEN NULL ELSE CAST('" + $BackupFile.ServerName + "' AS nvarchar(255)) END
    SET @myInstanceName = '" + $BackupFile.InstanceName + "'
    SET @myDatabaseName = N'" + $BackupFile.DatabaseName + "'
    SET @myBackup_start_date = CAST('" + $BackupFile.BackupStartTime.ToString() + "' AS DATETIME)
    SET @myBackup_finish_date = CAST('" + $BackupFile.BackupFinishTime.ToString() + "' AS DATETIME)
    SET @myExpiration_date = CASE WHEN '" + $BackupFile.ExpirationDate.ToString() + "'='' THEN NULL ELSE CAST('" + $BackupFile.ExpirationDate.ToString() + "' AS DATETIME) END
    SET @myBackupType = N'" + $BackupFile.BackupType + "'
    SET @myBackupFirstLSN = CASE WHEN '" + $BackupFile.FirstLsn.ToString() + "'='' THEN NULL ELSE CAST('" + $BackupFile.FirstLsn.ToString() + "' AS decimal(28,0)) END
    SET @myBackupLastLSN = CASE WHEN '" + $BackupFile.LastLsn.ToString() + "'='' THEN NULL ELSE CAST('" + $BackupFile.LastLsn.ToString() + "' AS decimal(28,0)) END
    SET @myBackupFilePath = N'" + $BackupFile.FilePath + "'
    SET @myBackupFileName = N'" + $BackupFile.FileName + "'
    SET @myMax_family_sequence_number = " + $BackupFile.MaxFamilySequenceNumber.ToString() + "
    SET @myDeleteDate = NULL
    SET @myIsDeleted = 0
    SET @myTransferStatus = N'SUCCEED';
    
    MERGE [dbo].["+ $this.BackupShippingCatalogTableName+"] AS myTarget
    USING (SELECT @myBatchId AS BatchId,@myDestination AS Destination,@myDestinationFolder AS DestinationFolder,@myUncBackupFilePath AS UncBackupFilePath,@myMedia_set_id AS Media_set_id,@myFamily_sequence_number AS Family_sequence_number,@myMachineName AS MachineName,@myInstanceName AS InstanceName,@myDatabaseName AS DatabaseName,@myBackup_start_date AS Backup_start_date,@myBackup_finish_date AS Backup_finish_date,@myExpiration_date AS Expiration_date,@myBackupType AS BackupType,@myBackupFirstLSN AS BackupFirstLSN,@myBackupLastLSN AS BackupLastLSN,@myBackupFilePath AS BackupFilePath,@myBackupFileName AS BackupFileName,@myMax_family_sequence_number AS Max_family_sequence_number,@myDeleteDate AS DeleteDate,@myIsDeleted AS IsDeleted,@myTransferStatus AS TransferStatus) AS mySource
        ON myTarget.Destination=mySource.Destination AND myTarget.DestinationFolder=mySource.DestinationFolder AND myTarget.Media_set_id=mySource.Media_set_id AND myTarget.Family_sequence_number=mySource.Family_sequence_number AND myTarget.InstanceName=mySource.InstanceName AND myTarget.DatabaseName=mySource.DatabaseName
    WHEN MATCHED THEN
         UPDATE SET
         [myTarget].[BatchId]=[mySource].[BatchId]
        ,[myTarget].[Destination]=[mySource].[Destination]
        ,[myTarget].[DestinationFolder]=[mySource].[DestinationFolder]
        ,[myTarget].[UncBackupFilePath]=[mySource].[UncBackupFilePath]
        ,[myTarget].[media_set_id]=[mySource].[media_set_id]
        ,[myTarget].[family_sequence_number]=[mySource].[family_sequence_number]
        ,[myTarget].[MachineName]=[mySource].[MachineName]
        ,[myTarget].[InstanceName]=[mySource].[InstanceName]
        ,[myTarget].[DatabaseName]=[mySource].[DatabaseName]
        ,[myTarget].[backup_start_date]=[mySource].[backup_start_date]
        ,[myTarget].[backup_finish_date]=[mySource].[backup_finish_date]
        ,[myTarget].[expiration_date]=[mySource].[expiration_date]
        ,[myTarget].[BackupType]=[mySource].[BackupType]
        ,[myTarget].[BackupFirstLSN]=[mySource].[BackupFirstLSN]
        ,[myTarget].[BackupLastLSN]=[mySource].[BackupLastLSN]
        ,[myTarget].[BackupFilePath]=[mySource].[BackupFilePath]
        ,[myTarget].[BackupFileName]=[mySource].[BackupFileName]
        ,[myTarget].[max_family_sequence_number]=[mySource].[max_family_sequence_number]
        ,[myTarget].[DeleteDate]=[mySource].[DeleteDate]
        ,[myTarget].[IsDeleted]=[mySource].[IsDeleted]
        ,[myTarget].[TransferStatus]=[mySource].[TransferStatus]
    WHEN NOT MATCHED THEN
        INSERT ([BatchId],[Destination],[DestinationFolder],[UncBackupFilePath],[media_set_id],[family_sequence_number],[MachineName],[InstanceName],[DatabaseName],[backup_start_date],[backup_finish_date],[expiration_date],[BackupType],[BackupFirstLSN],[BackupLastLSN],[BackupFilePath],[BackupFileName],[max_family_sequence_number],[DeleteDate],[IsDeleted],[TransferStatus])
        VALUES ([mySource].[BatchId],[mySource].[Destination],[mySource].[DestinationFolder],[mySource].[UncBackupFilePath],[mySource].[media_set_id],[mySource].[family_sequence_number],[mySource].[MachineName],[mySource].[InstanceName],[mySource].[DatabaseName],[mySource].[backup_start_date],[mySource].[backup_finish_date],[mySource].[expiration_date],[mySource].[BackupType],[mySource].[BackupFirstLSN],[mySource].[BackupLastLSN],[mySource].[BackupFilePath],[mySource].[BackupFileName],[mySource].[max_family_sequence_number],[mySource].[DeleteDate],[mySource].[IsDeleted],[mySource].[TransferStatus]);
    "
    try{
        Write-Verbose $myCommand
        Invoke-Sqlcmd -ConnectionString $this.LogWriter.LogInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -ErrorAction Stop
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $this.LogWriter.Write($this.LogStaticMessage+$myCommand, [LogType]::ERR)
        $myAnswer=$false
    }
    #return $myAnswer
}
hidden [void]Set_ShippedBackupsCatalogItemDeleteDate(){
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$true
    [PSCustomObject]$mySourceInstanceInfo=$null
    [string]$mySourceServerName=$null
    [string]$mySourceInstanceName=$null
    [string]$myCommand=$null
    [string]$myCommandExtension=$null

    $this.LogWriter.Write($this.LogStaticMessage+'Get Source instance server name.',[LogType]::INF)
    $mySourceInstanceInfo=Get-InstanceInformation -ConnectionString $this.SourceInstanceConnectionString -ShowRelatedInstanceOnly
    if ($mySourceInstanceInfo.PsObject.Properties.Name -eq 'MachineNameInstanceName') {
        $mySourceServerName=$mySourceInstanceInfo.MachineName
        $mySourceInstanceName=$mySourceInstanceInfo.InstanceName
    } else {
        $this.LogWriter.Write($this.LogStaticMessage+'Get-InstanceInformation failure.', [LogType]::ERR) 
        throw ('Get-InstanceInformation failure.')
    }
    if ($null -eq $mySourceServerName -or $null -eq $mySourceInstanceName -or $mySourceServerName.Length -eq 0 -or $mySourceInstanceName.Length -eq 0) {
        $this.LogWriter.Write($this.LogStaticMessage+'Source server name and/or instance name is empty.',[LogType]::ERR)
        throw 'Source server name and/or instance name is empty.'
    }

    $myCommandExtension=''
    if ($this.RetainDaysOnDestination.ToUpper() -eq 'CustomRule01'.ToUpper()) {
        #CustomRule01: Keep log backup files for 2days, keep full backup and differential backup for 1 day on destination
        $myCommandExtension=$this.Get_ShippedBackupsCatalogItemDeleteDate_CustomeRule01(2,1,1,1)
    } elseif ((IsNumeric -Value $this.RetainDaysOnDestination) -eq $true) {
        #Keep files for (RetainDaysOnDestination) days on destination
        $myCommandExtension=$this.RetainDaysOnDestination
    }

    $myCommand="
    DECLARE @myToday Datetime
    DECLARE @myMachineName nvarchar(256)
    DECLARE @myInstanceName nvarchar(256)
    DECLARE @myRetainDaysOnDestination INT
    SET @myMachineName=N'"+$mySourceServerName+"'
    SET @myInstanceName=N'"+$mySourceInstanceName+"'
    SET @myToday=getdate()
    
    UPDATE [dbo].["+$this.BackupShippingCatalogTableName+"] SET 
        [DeleteDate] = DATEADD(Day,"+$myCommandExtension+",@myToday)
    WHERE
        [DeleteDate] IS NULL
        AND [IsDeleted] = 0
        AND [MachineName] = @myMachineName
        AND [InstanceName] = @myInstanceName
    "
    try{
        Write-Verbose $myCommand
        Invoke-Sqlcmd -ConnectionString $this.LogWriter.LogInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop
        $myAnswer=$true
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $this.LogWriter.Write($this.LogStaticMessage+$myCommand, [LogType]::ERR)
        $myAnswer=$false
    }
    #if ($null -ne $myRecord) {return $myAnswer=$true}
    #retrun $myAnswer
}
hidden [string]Get_ShippedBackupsCatalogItemDeleteDate_CustomeRule01 ([int]$LogBackupRetainDays,[int]$DifferentialBackupRetainDays,[int]$FullBackupRetainDays,[int]$DefaultBackupRetainDays){   #This rule set backup file retain days on destination according to backup file type, you can use any field of Catalog backup table ro create any other custom rulse
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [string]$myAnswer=$null

    $myAnswer="CASE BackupType WHEN 'L' THEN "+ $LogBackupRetainDays.ToString() +" WHEN 'D' THEN "+ $FullBackupRetainDays.ToString() +" WHEN 'I' THEN "+ $DifferentialBackupRetainDays.ToString() +" ELSE "+ $DefaultBackupRetainDays.ToString() +" END"
    Write-Verbose $myAnswer
    return $myAnswer
}
hidden [void]Set_ShippedBackupsCatalogItemDeleteFlag([BackupCatalogItem]$BackupCatalogItem) {
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$true
    [string]$myCommand=$null

    $myCommand="
        DECLARE @myId BIGINT
        SET @myId="+$BackupCatalogItem.Id.ToString()+"
        
        UPDATE [dbo].["+$this.BackupShippingCatalogTableName+"] SET 
            IsDeleted = 1
        WHERE
            Id = @myId
    "
    try{
        Write-Verbose $myCommand
        Invoke-Sqlcmd -ConnectionString $this.LogWriter.LogInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $this.LogWriter.Write($this.LogStaticMessage+$myCommand, [LogType]::ERR)
        $myAnswer=$false
    }
    #if ($null -ne $myRecord) {$myAnswer=$true}
    #return $myAnswer
}
hidden [void]Set_BackupsCatalogItemAsShippedOnMsdb([BackupFile]$BackupFile) {
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$true
    [string]$myCommand=$null

    $myCommand="
    DECLARE @MediaSetId INT;
    DECLARE @BackupFinishDate DATETIME;
    DECLARE @TransferedSuffix NVARCHAR(20);
 
    SET @MediaSetId = "+ $BackupFile.MediaSetId.ToString() +";
    SET @BackupFinishDate = CAST(N'"+ $BackupFile.BackupFinishTime.ToString() +"' AS DATETIME);
    SET @TransferedSuffix = N'"+ $this.TransferedFileDescriptionSuffix +"';
    
    --Update backup description
    UPDATE [msdb].[dbo].[backupset] SET 
        [description] = [description]+@TransferedSuffix 
    WHERE 
        media_set_id=@MediaSetId 
        AND [backup_finish_date] IS NOT NULL 
        AND [backup_finish_date] <= @BackupFinishDate 
        AND [description] NOT LIKE '%'+@TransferedSuffix + '%'
    "
    try{
        Write-Verbose $myCommand
        Invoke-Sqlcmd -ConnectionString $this.SourceInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $this.LogWriter.Write($this.LogStaticMessage+$myCommand, [LogType]::ERR)
        $myAnswer=$false
    }
    #if ($null -ne $myRecord) {$myAnswer=$true}
    #return $myAnswer
}
hidden [PSCustomObject]Get_InstanceInformation([string]$ConnectionString) {  #Get database server instance name
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [string]$myAnswer=$null
    try{
        $myInstanceInfo=Get-InstanceInformation -ConnectionString $ConnectionString -ShowRelatedInstanceOnly
        if ($null -ne $myInstanceInfo) {$myAnswer=$myInstanceInfo} else {$myAnswer=$null}
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
    }
    return $myAnswer
}
hidden [bool]Operate_OverFtp([HostOperation]$Operation,[string]$Server,[System.Net.NetworkCredential]$Credential,[string]$DestinationPath,[string]$SourceFilePath) {  #Upload file to FTP path by winscp
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [bool]$myAnswer=$false
    [string]$mySshKeyFingerprint=$null

    $myAnswer=$this.Operate_OverWinScp([DestinationType]::FTP,$Operation,$Server,$Credential,$DestinationPath,$SourceFilePath,$mySshKeyFingerprint)
    return $myAnswer
}
hidden [bool]Operate_OverSftp([HostOperation]$Operation,[string]$Server,[System.Net.NetworkCredential]$Credential,[string]$DestinationPath,[string]$SourceFilePath,[string]$SshKeyFingerprint) {  #Upload file to SFTP path by winscp
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [bool]$myAnswer=$false

    $myAnswer=$this.Operate_OverWinScp([DestinationType]::SFTP,$Operation,$Server,$Credential,$DestinationPath,$SourceFilePath,$SshKeyFingerprint)
    return $myAnswer
}
hidden [bool]Operate_OverScp([HostOperation]$Operation,[string]$Server,[System.Net.NetworkCredential]$Credential,[string]$DestinationPath,[string]$SourceFilePath,[string]$SshKeyFingerprint) {  #Upload file to SFTP path by winscp
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [bool]$myAnswer=$false

    $myAnswer=$this.Operate_OverWinScp([DestinationType]::SCP,$Operation,$Server,$Credential,$DestinationPath,$SourceFilePath,$SshKeyFingerprint)
    return $myAnswer
}
hidden [bool]Operate_OverUnc([HostOperation]$Operation,[string]$SharedFolderPath,[System.Net.NetworkCredential]$Credential,[char[]]$TemporalDriveLetters,[string]$DestinationPath,[string]$SourceFilePath) {
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [bool]$myAnswer=$false

    if($null -eq $TemporalDriveLetters){$TemporalDriveLetters=('A','B')}

    if($Operation -eq [HostOperation]::ISALIVE)
    {
        try
        {
            $this.LogWriter.Write($this.LogStaticMessage+'Connect to UNC path for IsAlive control.', [LogType]::INF)
            $myAnswer=$this.Operate_UNC_IsAlive($SharedFolderPath,$Credential,$TemporalDriveLetters[0])
        }catch{
            $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
            $myAnswer=$false

        }
    }
    elseif($Operation -eq [HostOperation]::MKDIR)
    {
        try
        {
            $this.LogWriter.Write($this.LogStaticMessage+'Create new directory on UNC address of ' + $DestinationPath, [LogType]::INF)
            $myAnswer=$this.Operate_UNC_MKDIR($SharedFolderPath,$Credential,$TemporalDriveLetters[0],$DestinationPath)
        }catch{
            $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
            $myAnswer=$false
        }
    }
    elseif($Operation -eq [HostOperation]::UPLOAD)
    {
        try
        {
            $this.LogWriter.Write($this.LogStaticMessage+'Upload file to UNC address of ' + $DestinationPath, [LogType]::INF)
            $myAnswer=$this.Operate_UNC_Upload($SharedFolderPath,$Credential,$TemporalDriveLetters,$DestinationPath,$SourceFilePath,$this.ActionType)
        }catch{
            $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
            $myAnswer=$false
        }
    }
    elseif($Operation -eq [HostOperation]::DELETE)
    {
        try
        {
            $this.LogWriter.Write($this.LogStaticMessage+'Delete file from UNC address of ' + $DestinationPath, [LogType]::INF)
            $myAnswer=$this.Operate_UNC_Delete($SharedFolderPath,$Credential,$TemporalDriveLetters[0],$DestinationPath)
        }catch{
            $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
            $myAnswer=$false
        }
    }
    return $myAnswer
}
hidden [bool]Operate_OverWinScp([DestinationType]$DestinationType,[HostOperation]$Operation,[string]$Server,[System.Net.NetworkCredential]$Credential,[string]$DestinationPath,[string]$SourceFilePath,[string]$SshKeyFingerprint) {  #Do file operation to via winscp
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [bool]$myAnswer=$false
    [string]$myDestinationPath=$null
    [string]$myDestinationUser=$null
    [string]$myDestinationPassword=$null
    [hashtable]$mySessionArguments=$null
    <#This block was commented because WinScp module does not required in all cases and these definisions generate error in case of non winscp scenarios
    [WinSCP.SessionOptions]$mySessionOptions=$null
    [WinSCP.Session]$mySession=$null
    [WinSCP.TransferOptions]$myTransferOptions=$null
    [WinSCP.TransferOperationResult]$myOperationResult=$null
    [WinSCP.RemoteDirectoryInfo]$myDirResult=$null
    #>

    try{
        $myDestinationPath = $DestinationPath.Replace('//','/')
        $myDestinationPassword = $Credential.Password
        # Setup credential domain name prefix
        if ($Credential.Domain.Trim().Length -eq 0){
            $myDestinationUser=$Credential.UserName.Trim()
        }else{
            $myDestinationUser=$Credential.Domain.Trim()+'\'+$Credential.UserName.Trim()
        }
        # Setup session options
        switch ($DestinationType) {
            FTP { $mySessionArguments= @{
                FtpMode = 'Passive'
                FtpSecure = 'None'
                Protocol = 'ftp'
                HostName = $Server
                UserName = $myDestinationUser
                Password = $myDestinationPassword
            }}
            SFTP { $mySessionArguments= @{
                Protocol = 'Sftp'
                HostName = $Server
                UserName = $myDestinationUser
                Password = $myDestinationPassword
                SshHostKeyFingerprint = $SshKeyFingerprint
            }}
            SCP { $mySessionArguments= @{
                Protocol = 'Scp'
                HostName = $Server
                UserName = $myDestinationUser
                Password = $myDestinationPassword
                SshHostKeyFingerprint = $SshKeyFingerprint
            }}
        }

        # Define Session and do operation
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create WinScp session.', [LogType]::INF)
        $mySessionOptions = New-Object WinSCP.SessionOptions -Property $mySessionArguments
        $mySession = New-Object WinSCP.Session
        $this.LogWriter.Write($this.LogStaticMessage+'Try to execute operation ' + $Operation + ' over ' + $DestinationType + ' protocl on ' + $Server, [LogType]::INF)
        if($Operation -eq [HostOperation]::ISALIVE)
        {
            try
            {
                $this.LogWriter.Write($this.LogStaticMessage+'Connect to session for IsAlive operation.', [LogType]::INF)
                $mySession.Open($mySessionOptions)      # Connect
                $myAnswer=$true
            }catch{
                $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
                $myAnswer=$false
            }
            finally
            {
                $mySession.Dispose()    # Disconnect, clean up
            }
        }
        elseif($Operation -eq [HostOperation]::UPLOAD)
        {
            try
            {
                $this.LogWriter.Write($this.LogStaticMessage+'Connect to session for Upload operation.', [LogType]::INF)
                $mySession.Open($mySessionOptions)      # Connect
    
                # Upload files
                $myTransferOptions = New-Object WinSCP.TransferOptions
                $myTransferOptions.TransferMode = 'Binary'
    
                $this.LogWriter.Write($this.LogStaticMessage+'Trying to transfer ' + $SourceFilePath + ' to ' + $DestinationPath, [LogType]::INF)
                $myOperationResult = $mySession.PutFiles($SourceFilePath,$DestinationPath, $False, $myTransferOptions)
            
                # Throw on any error
                #$myOperationResult.Check()
                #$mySession.Output
                $myAnswer=$myOperationResult.IsSuccess
            
                # Print results
                if ($myAnswer -eq $true) {
                    foreach ($myTransfer in $myOperationResult.Transfers)
                    {
                        if ($mySession.FileExists($DestinationPath) -eq $true) {
                            $this.LogWriter.Write($this.LogStaticMessage+'Upload of ' + ($myTransfer.FileName) + ' succeeded.', [LogType]::INF)
                            $myAnswer=$true
                        }else{
                            $this.LogWriter.Write($this.LogStaticMessage+'Upload of ' + $SourceFilePath + ' to ' + $DestinationPath + ' failed, because file does not exists.', [LogType]::ERR)
                            $myAnswer=$false
                        }
                    }
                }else{
                    $this.LogWriter.Write($this.LogStaticMessage+'Upload of ' + $SourceFilePath + ' to ' + $DestinationPath + ' failed.', [LogType]::ERR)
                }
            }catch{
                $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
                $myAnswer=$false
            }
            finally
            {
                # Disconnect, clean up
                $mySession.Dispose()
            }
        }
        elseif($Operation -eq [HostOperation]::DOWNLOAD)
        {
            try
            {
                # Connect
                $this.LogWriter.Write($this.LogStaticMessage+'Connect to session for Download operation.', [LogType]::INF)
                $mySession.Open($mySessionOptions)
        
                # Download the file and throw on any error
                $this.LogWriter.Write($this.LogStaticMessage+'Check file existence (' + $DestinationPath + ')', [LogType]::INF)
                if ($mySession.FileExists($DestinationPath) -eq $true) {
                    $this.LogWriter.Write($this.LogStaticMessage+'Trying to download ' + $DestinationPath + ' into ' + $SourceFilePath, [LogType]::INF)
                    $myOperationResult = $mySession.GetFiles($DestinationPath,$SourceFilePath)
                    # Throw error if found
                    #$myOperationResult.Check()
                    #$mySession.Output
                    $myAnswer=$myOperationResult.IsSuccess
                }else{
                    $this.LogWriter.Write($this.LogStaticMessage+'Trying to download ' + $DestinationPath + ' but file does not exists.', [LogType]::INF)
                    $myAnswer=$false
                }

            }catch{
                $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
                $myAnswer=$false
            }
            finally
            {
                # Disconnect, clean up
                $mySession.Dispose()
            }    
        }
        elseif($Operation -eq [HostOperation]::DIR)
        {
            try
            {
                # Connect
                $this.LogWriter.Write($this.LogStaticMessage+'Connect to session for Dir operation.', [LogType]::INF)
                $mySession.Open($mySessionOptions)
        
                # Download the file and throw on any error
                $this.LogWriter.Write($this.LogStaticMessage+'Get directory list of ' + $DestinationPath, [LogType]::INF)
                $myDirResult = $mySession.ListDirectory($DestinationPath)
                
                # Throw error if found
                $mySession.Output
    
                $myAnswer=$true
            }catch{
                $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
                $myAnswer=$false
            }
            finally
            {
                # Disconnect, clean up
                $mySession.Dispose()
            }  
        }
        elseif($Operation -eq [HostOperation]::MKDIR)
        {
            try
            {
                # Connect
                $this.LogWriter.Write($this.LogStaticMessage+'Connect to session for MkDir operation.', [LogType]::INF)
                $mySession.Open($mySessionOptions)
        
                # Create the directory and throw on any error
                $this.LogWriter.Write($this.LogStaticMessage+'Destination path is ' + $DestinationPath, [LogType]::INF)
                [string]$myPath=''
                [array]$myFolders = $DestinationPath.Split('/')
                foreach ($myFolder in $myFolders)
                {
                    if ($myFolder.ToString().Trim().Length -gt 0) 
                    {
                        $myPath += '/' + $myFolder
                        $this.LogWriter.Write($this.LogStaticMessage+'Check path existance ' + $myPath, [LogType]::INF)
                        if ($mySession.FileExists($myPath) -eq $false) 
                        {
                            $this.LogWriter.Write($this.LogStaticMessage+'Creating new directory as ' + $myPath, [LogType]::INF)
                            $mySession.CreateDirectory($myPath)
                            $this.LogWriter.Write($this.LogStaticMessage+'New directory created as ' + $myPath, [LogType]::INF)
                        }
                    }
                }
                
                $myAnswer=$mySession.FileExists($DestinationPath)
                # Throw error if found
                $mySession.Output
            }catch{
                $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
                $myAnswer=$false
            }
            finally
            {
                # Disconnect, clean up
                $mySession.Dispose()
            }  
        }
        elseif($Operation -eq [HostOperation]::DELETE)
        {
            try
            {
                # Connect
                $this.LogWriter.Write($this.LogStaticMessage+'Connect to session for Delete operation.', [LogType]::INF)
                $mySession.Open($mySessionOptions)
        
                # Remove the file and throw on any error
                $this.LogWriter.Write($this.LogStaticMessage+'Check file existence (' + $DestinationPath + ')', [LogType]::INF)
                if ($mySession.FileExists($DestinationPath) -eq $true) {
                    $this.LogWriter.Write($this.LogStaticMessage+'Trying to remove ' + $DestinationPath + ' file.', [LogType]::INF)
                    $mySessionResult = $mySession.RemoveFiles($DestinationPath)

                    $this.LogWriter.Write($this.LogStaticMessage+'Check file existence (' + $DestinationPath + ') after delete operation.', [LogType]::INF)
                    if ($mySession.FileExists($DestinationPath) -eq $true) {
                        $this.LogWriter.Write($this.LogStaticMessage+'File is exists and does not removed.', [LogType]::ERR)
                        $myAnswer=$false    #file already exists and does not removed
                    }else{
                        $this.LogWriter.Write($this.LogStaticMessage+'File is removed.', [LogType]::INF)
                        $myAnswer=$true     #file is removed
                    }
                    #$myAnswer=$mySessionResult.IsSuccess
                    # Throw error if found
                    #$mySession.Output
                }else{
                    $this.LogWriter.Write($this.LogStaticMessage+'Trying to remove ' + $DestinationPath + ' but file does not exists.', [LogType]::WRN)
                    $myAnswer=$true     #file already removed
                }
            }catch{
                $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
                $myAnswer=$false
            }
            finally
            {
                # Disconnect, clean up
                $mySession.Dispose()
            }    
        }
        else 
        {
            $this.LogWriter.Write($this.LogStaticMessage+'Operation not specified, it must be upload/download/list/dir/mkdir/delete', [LogType]::WRN)
        }
    }catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $myAnswer=$false
    }
    return $myAnswer
}
hidden [bool]Operate_UNC_IsAlive([string]$SharedFolderPath,[System.Net.NetworkCredential]$Credential,[char]$TemporalDriveLetter) {  #Check UNC path is alive
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$false
    [string]$myDestinationUser=$null
    [string]$myDestinationPassword=$null
    [securestring]$myDestinationSecurePassword=$null
    [string]$myLockFileName=$null
    [string]$myLockFilePath=$null

    try {
        $myDestinationPassword = $Credential.Password
        # Setup credential domain name prefix
        if ($Credential.Domain.Trim().Length -eq 0){
            $myDestinationUser=$Credential.UserName.Trim()
        }else{
            $myDestinationUser=$Credential.Domain.Trim()+'\'+$Credential.UserName.Trim()
        }
        $myDestinationSecurePassword = ConvertTo-SecureString $myDestinationPassword -AsPlainText -Force
        $myCredential = New-Object System.Management.Automation.PSCredential ($myDestinationUser, $myDestinationSecurePassword)
        if($null -eq $TemporalDriveLetter){$TemporalDriveLetter='A'}
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create Drive Letter of ' + $TemporalDriveLetter + ' on ' + $SharedFolderPath + ' with User ' + $myDestinationUser, [LogType]::INF)    
        New-PSDrive -Name $TemporalDriveLetter -PSProvider filesystem -Root $SharedFolderPath -Credential $myCredential

        $myLockFileName=([Environment]::MachineName + $this.BatchUid + '.lck')
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create temporary file ' + $myLockFileName + ' on ' + $TemporalDriveLetter + '('+$SharedFolderPath+')', [LogType]::INF)    
        New-Item -ItemType File -Path ($TemporalDriveLetter+':\') -Name $myLockFileName

        $myLockFilePath=$TemporalDriveLetter+':\'+$myLockFileName
        $myAnswer=Test-Path -PathType Leaf -Path $myLockFilePath
        if ($myAnswer -eq $false) {
            $this.LogWriter.Write($this.LogStaticMessage+'Lock file creation failed', [LogType]::ERR)
        }
        Remove-Item -Path $myLockFilePath -Force
        Remove-PSDrive -Name $TemporalDriveLetter
    }
    catch {
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $myAnswer=$false
    }
    finally{
        Remove-PSDrive -Name $TemporalDriveLetter -ErrorAction Ignore
    }
    return $myAnswer
}
hidden [bool]Operate_UNC_MKDIR([string]$SharedFolderPath,[System.Net.NetworkCredential]$Credential,[char]$TemporalDriveLetter,[string]$DestinationPath) {  #Create Directory on UNC path 
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$false
    [string]$myDestinationUser=$null
    [string]$myDestinationPassword=$null
    [securestring]$myDestinationSecurePassword=$null
    [string]$myPath=$null
    [array]$myFolders=$null
    [string]$myFolder=$null
    
    try {
        $myDestinationPassword = $Credential.Password
        # Setup credential domain name prefix
        if ($Credential.Domain.Trim().Length -eq 0){
            $myDestinationUser=$Credential.UserName.Trim()
        }else{
            $myDestinationUser=$Credential.Domain.Trim()+'\'+$Credential.UserName.Trim()
        }
        $myDestinationSecurePassword = ConvertTo-SecureString $myDestinationPassword -AsPlainText -Force
        $myCredential = New-Object System.Management.Automation.PSCredential ($myDestinationUser, $myDestinationSecurePassword)
        if($null -eq $TemporalDriveLetter){$TemporalDriveLetter='A'}
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create drive letter named ' + $TemporalDriveLetter + ' for ' + $SharedFolderPath + ' with User ' + $myDestinationUser, [LogType]::INF)    
        New-PSDrive -Name $TemporalDriveLetter -PSProvider filesystem -Root $SharedFolderPath -Credential $myCredential
        # Create the directory and throw on any error
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create required sub folders according to ' + $TemporalDriveLetter + ':' + $DestinationPath, [LogType]::INF)    
        $myPath=$TemporalDriveLetter+':'
        $myFolders = $DestinationPath.Split('\')
        foreach ($myFolder in $myFolders)
        {
            if ($myFolder.ToString().Trim().Length -gt 0) 
            {
                $myPath += '\' + $myFolder
                $this.LogWriter.Write($this.LogStaticMessage+'Try to create path ' + $myPath + ' if not exists.', [LogType]::INF)    
                if ((Test-Path -PathType Container -Path $myPath) -eq $false) {
                    New-Item -ItemType Directory -Path $myPath
                    $this.LogWriter.Write($this.LogStaticMessage+'New directory created on ' + $myPath, [LogType]::INF)    
                }
            }
        }

        $this.LogWriter.Write($this.LogStaticMessage+'Test path existence on ' + $TemporalDriveLetter + ':\' + $DestinationPath, [LogType]::INF)
        $myAnswer = Test-Path -PathType Container -Path ($TemporalDriveLetter + ':\' + $DestinationPath)
        Remove-PSDrive -Name $TemporalDriveLetter
    }
    catch {
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $myAnswer=$false
    }
    finally{
        Remove-PSDrive -Name $TemporalDriveLetter -ErrorAction Ignore
    }
    return $myAnswer
}
hidden [bool]Operate_UNC_Upload([string]$SharedFolderPath,[System.Net.NetworkCredential]$Credential,[char[]]$TemporalDriveLetters,[string]$DestinationPath,[string]$SourceFilePath,[ActionType]$ActionType) {
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$false
    [string]$myDestinationUser=$null
    [string]$myDestinationPassword=$null
    [securestring]$myDestinationSecurePassword=$null
    [string]$myDestinationDriveLetter=$null
    [string]$myDestinationPath=$null

    try {
        $myDestinationPassword = $Credential.Password
        # Setup credential domain name prefix
        if ($Credential.Domain.Trim().Length -eq 0){
            $myDestinationUser=$Credential.UserName.Trim()
        }else{
            $myDestinationUser=$Credential.Domain.Trim()+'\'+$Credential.UserName.Trim()
        }
        $myDestinationSecurePassword = ConvertTo-SecureString $myDestinationPassword -AsPlainText -Force
        $myCredential = New-Object System.Management.Automation.PSCredential ($myDestinationUser, $myDestinationSecurePassword)
         
        # Recalculate unc destination path
        if($null -eq $TemporalDriveLetters){$TemporalDriveLetters=('A','B')}
        $myDestinationDriveLetter = $TemporalDriveLetters[0]
        $myDestinationPath=($myDestinationDriveLetter + ':\' + $DestinationPath).Replace('\\','\')
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create Drive Letter of ' + $myDestinationDriveLetter + ' on ' + $SharedFolderPath + ' with User ' + $myDestinationUser, [LogType]::INF)    
        New-PSDrive -Name $myDestinationDriveLetter -PSProvider filesystem -Root $SharedFolderPath -Credential $myCredential
        
        if ((Test-Path -Path ($myDestinationDriveLetter+':') -PathType Container) -eq $false) {
            $this.LogWriter.Write($this.LogStaticMessage+'Create Destination Drive Letter Error for ' + $myDestinationDriveLetter + ' defined on ' + $SharedFolderPath + ' as user ' + $myDestinationUser, [LogType]::ERR)
            $myAnswer = $false
            return $myAnswer
        }
 
        # Recalculate unc source path
        if ($SourceFilePath.Substring(0,2) -eq '\\') {
            $mySourceDriveLetter = $TemporalDriveLetters[1]
            $mySourceFilePathSections=$SourceFilePath.Split('\')
            $mySourceDriveURI='\\' + $mySourceFilePathSections[2] + '\' + $mySourceFilePathSections[3]
            $this.LogWriter.Write($this.LogStaticMessage+'Comparing SourceDriveURI of ' + $mySourceDriveURI + ' with SharedFolderPath of ' + $SharedFolderPath, [LogType]::INF)
            if ($mySourceDriveURI.ToUpper() -ne $SharedFolderPath.ToUpper()) {
                New-PSDrive -Name $mySourceDriveLetter -PSProvider filesystem -Root $mySourceDriveURI -Credential $myCredential
                if ((Test-Path -Path ($mySourceDriveLetter+':') -PathType Container) -eq $false) {
                    $this.LogWriter.Write($this.LogStaticMessage+'Create Source Drive Letter Error for ' + $mySourceDriveLetter + ' defined on ' + $mySourceDriveURI + ' as user ' + $myDestinationUser, [LogType]::ERR)
                    $myAnswer = $false
                    return $myAnswer
                }
                $mySourceFilePath=($mySourceDriveLetter + ':\' + ([string]::Join('\',($mySourceFilePathSections|Select-Object -Skip 4)))).Replace('\\','\')
            } else {
                $mySourceDriveLetter=$myDestinationDriveLetter
                $mySourceFilePath=($mySourceDriveLetter + ':\' + ([string]::Join('\',($mySourceFilePathSections|Select-Object -Skip 4)))).Replace('\\','\')
            }
        }
        else{
            $mySourceFilePath=$SourceFilePath
        }
 
        # Copy\Move file to destination UNC directory and throw on any error
        $this.LogWriter.Write($this.LogStaticMessage+'Starting to uploaded (' + $ActionType + ') from ' + $SourceFilePath + ' (' + $mySourceFilePath +') to ' + $myDestinationPath, [LogType]::INF)
        switch ($ActionType) {
            COPY {Copy-Item -Path $mySourceFilePath -Destination $myDestinationPath -Force}
            MOVE {Move-Item -Path $mySourceFilePath -Destination $myDestinationPath -Force}
        }
 
        $this.LogWriter.Write($this.LogStaticMessage+'Testing file path ' + $myDestinationPath + ' ...', [LogType]::INF)
        $myResult = Test-Path -PathType Leaf -Path $myDestinationPath

        if ($myResult) {
            $this.LogWriter.Write($this.LogStaticMessage+'New file uploaded (' + $ActionType + ') from ' + $SourceFilePath + '(' + $mySourceFilePath +') to ' + $myDestinationPath, [LogType]::INF)
            $myAnswer=$true
        }else{
            $this.LogWriter.Write($this.LogStaticMessage+'Failed to upload (' + $ActionType + ') from ' + $SourceFilePath + '(' + $mySourceFilePath +') to ' + $myDestinationPath, [LogType]::ERR)
            $myAnswer=$false
        }
 
        Remove-PSDrive -Name ($TemporalDriveLetters[0])
        if ($SourceFilePath.Substring(0,2) -eq '\\') {Remove-PSDrive -Name ($TemporalDriveLetters[1])}
    }
    catch {
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
    }
    return $myAnswer
}
hidden [bool]Operate_UNC_Delete([string]$SharedFolderPath,[System.Net.NetworkCredential]$Credential,[char]$TemporalDriveLetter,[string]$DestinationPath) {
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [bool]$myAnswer=$false
    [string]$myDestinationUser=$null
    [string]$myDestinationPassword=$null
    [securestring]$myDestinationSecurePassword=$null
    [string]$myDestinationDriveLetter=$null
    [string]$myDestinationPath=$null

    try {
        $myDestinationPassword = $Credential.Password
        # Setup credential domain name prefix
        if ($Credential.Domain.Trim().Length -eq 0){
            $myDestinationUser=$Credential.UserName.Trim()
        }else{
            $myDestinationUser=$Credential.Domain.Trim()+'\'+$Credential.UserName.Trim()
        }
        $myDestinationSecurePassword = ConvertTo-SecureString $myDestinationPassword -AsPlainText -Force
        $myCredential = New-Object System.Management.Automation.PSCredential ($myDestinationUser, $myDestinationSecurePassword)
         
        # Recalculate unc destination path
        if($null -eq $TemporalDriveLetter){$TemporalDriveLetter='A'}
        $myDestinationDriveLetter = $TemporalDriveLetter
        $myDestinationPath=$myDestinationDriveLetter + ':\' + $DestinationPath
        $this.LogWriter.Write($this.LogStaticMessage+'Try to create Drive Letter of ' + $myDestinationDriveLetter + ' on ' + $SharedFolderPath + ' with User ' + $myDestinationUser, [LogType]::INF)    
        New-PSDrive -Name $myDestinationDriveLetter -PSProvider filesystem -Root $SharedFolderPath -Credential $myCredential
        
        if ((Test-Path -Path ($myDestinationDriveLetter+':') -PathType Container) -eq $false) {
            $this.LogWriter.Write($this.LogStaticMessage+'Create Destination Drive Letter Error for ' + $myDestinationDriveLetter + ' defined on ' + $SharedFolderPath + ' as user ' + $myDestinationUser, [LogType]::ERR)
            $myAnswer = $false
            return $myAnswer
        }
 
        # Remove file from destination
        $this.LogWriter.Write($this.LogStaticMessage+'Starting to delete ' + $myDestinationPath, [LogType]::INF)
        Remove-Item -Path $myDestinationPath -Force
 
        $this.LogWriter.Write($this.LogStaticMessage+'Testing file path ' + $myDestinationPath + ' ...', [LogType]::INF)
        $myResult = Test-Path -PathType Leaf -Path $myDestinationPath
        if ($myResult) {
            $this.LogWriter.Write($this.LogStaticMessage+'File ' + $myDestinationPath + ' does not removed.', [LogType]::ERR)
            $myAnswer=$false
        }else{
            $this.LogWriter.Write($this.LogStaticMessage+'File ' + $myDestinationPath + ' is removed.', [LogType]::INF)
            $myAnswer=$true
        }
 
        Remove-PSDrive -Name ($TemporalDriveLetter)
    }
    catch {
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
    }
    return $myAnswer
}
[void] Save_CredentialToStore([string]$StoreCredentialName,[System.Net.NetworkCredential]$Credential){  #Save credential to Windows Credential Manager
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    if(-not(Get-Module -ListAvailable -Name CredentialManager)) {
        Install-Module CredentialManager -force -Scope CurrentUser
    }
    if(-not(Get-Module CredentialManager)){
        Import-Module CredentialManager
    }
    if (Get-StoredCredential -Target $StoreCredentialName) { #Remove any existed credential
        Remove-StoredCredential -Target StoreCredentialName
    }
    New-StoredCredential -Target $StoreCredentialName -Type Generic -UserName $Credential.UserName -Password $Credential.Password -Persist LocalMachine
}
[void] Set_DestinationCredential([System.Net.NetworkCredential]$Credential){    #Retrive destination credential from input
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    $this.DestinationCredential=$Credential
}
[void] Set_DestinationCredential([string]$StoredCredentialName){    #Retrive destination credential from Windows Credential Manager
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    if(-not(Get-Module -ListAvailable -Name CredentialManager)) {
        Install-Module CredentialManager -force -Scope CurrentUser
    }
    if(-not(Get-Module CredentialManager)){
        Import-Module CredentialManager
    }
    $this.DestinationCredential=(Get-StoredCredential -Target $StoredCredentialName).GetNetworkCredential()
}
[void] Set_DestinationCredential([string]$UserName,[string]$CipheredPassword, [byte[]]$Key){    #Generate destination credential from plaintext username and cipheredtext password
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [SecureString]$myPassword = $null
    $myPassword = ConvertTo-SecureString -String $CipheredPassword -Key $Key 
    $this.Set_DestinationCredential($UserName, $myPassword)
}
[void] Set_DestinationCredential([string]$UserName,[SecureString]$Password){    #Generate destination credential from plain text username and securestring password
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    $this.DestinationCredential=(New-Object System.Management.Automation.PsCredential -ArgumentList $UserName,$Password).GetNetworkCredential()
}
[void] Set_DestinationCredential([string]$UserName,[string]$Password){  #Generate destination credential from plain text username and password
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    $this.DestinationCredential=New-Object System.Net.NetworkCredential($UserName, $Password)
}
hidden [BackupFile[]]Get_UntransferredBackups([string]$ConnectionString,[string[]]$Databases,[BackupType[]]$BackupTypes,[int]$HoursToScanForUntransferredBackups,[string]$TransferedSuffix,[string]$DestinationFolderStructure) {  #Get list of untransferred backup files list
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)
    [BackupFile[]]$myAnswer=$null
    [PSCustomObject]$mySourceInstanceInfo=$null
    [string]$mySourceServerName=$null
    [string]$mySourceInstanceName=$null
    [string]$myCommand=$null
    [string]$myDatabases=$null
    [string]$myBackupTypes=$null

    $this.LogWriter.Write($this.LogStaticMessage+'Get Source instance server name.',[LogType]::INF)
    $mySourceInstanceInfo=Get-InstanceInformation -ConnectionString $ConnectionString -ShowRelatedInstanceOnly
    if ($mySourceInstanceInfo.PsObject.Properties.Name -eq 'MachineName') {
        $mySourceServerName=$mySourceInstanceInfo.MachineName
        $mySourceInstanceName=$mySourceInstanceInfo.InstanceName
    } else {
        $this.LogWriter.Write($this.LogStaticMessage+'Get-InstanceInformation failure.', [LogType]::ERR) 
        throw ('Get-InstanceInformation failure.')
    }
    if ($null -eq $mySourceServerName -or $mySourceServerName.Length -eq 0) {
        $this.LogWriter.Write($this.LogStaticMessage+'Source server name is empty.',[LogType]::ERR)
        throw 'Source server name is empty.'
    }

    #$myDatabases=Join-String -InputObject $Databases -Separator ',' -SingleQuote
    #$myBackupTypes=(Join-String -InputObject $BackupTypes -Separator ',' -SingleQuote).Replace('FULL','D').Replace('DIFF','I').Replace('LOG','L')
    $myDatabases=($Databases | ForEach-Object{"'" + $_ + "'"}) -join ','
    $myBackupTypes=(($BackupTypes | ForEach-Object{"'" + $_ + "'"}) -join ',').Replace('FULL','D').Replace('DIFF','I').Replace('LOG','L')
    $myCommand="
    DECLARE @myCurrentDateTime DATETIME;
    DECLARE @HoursToScanForUntransferredBackups INT;
    DECLARE @TransferedSuffix NVARCHAR(50);
    
    SET @myCurrentDateTime = GETDATE();
    SET @HoursToScanForUntransferredBackups = -1*ABS("+ $HoursToScanForUntransferredBackups.ToString() +");
    SET @TransferedSuffix = N'"+ $TransferedSuffix +"';    
    
    SELECT
        [myMediaSet].[media_set_id]                                                                                  AS [MediaSetId],   --PK
        CAST([myMediaSet].[family_sequence_number] AS INT)															 AS [FamilySequenceNumber],	--PK
        [myUniqueBackupSet].[database_name]																			 AS [DatabaseName],
        [myUniqueBackupSet].[backup_start_date]																		 AS [BackupStartTime],
        [myUniqueBackupSet].[backup_finish_date]																	 AS [BackupFinishTime],
        [myUniqueBackupSet].[expiration_date]																		 AS [ExpirationDate],
        UPPER([myUniqueBackupSet].[type])																			 AS [BackupType],
        CAST([myUniqueBackupSet].[first_lsn] AS DECIMAL(25, 0))														 AS [FirstLSN],
        CAST([myUniqueBackupSet].[last_lsn] AS DECIMAL(25, 0))														 AS [LastLSN],
        [myMediaSet].[physical_device_name]																			 AS [FilePath],
        RIGHT([myMediaSet].[physical_device_name], CHARINDEX('\', REVERSE([myMediaSet].[physical_device_name])) - 1) AS [FileName],
        MAX(CAST([myMediaSet].[family_sequence_number] AS INT)) OVER (PARTITION BY [myMediaSet].[media_set_id])		 AS [MaxFamilySequenceNumber]
    FROM
        [msdb].[dbo].[backupmediafamily] AS [myMediaSet]
        INNER JOIN (
            SELECT
                [myBackupSet].[media_set_id],
                MAX([myBackupSet].[machine_name])		AS [machine_name],
                MAX([myBackupSet].[server_name])		AS [server_name],
                MAX([myBackupSet].[database_name])		AS [database_name],
                MAX([myBackupSet].[backup_start_date])	AS [backup_start_date],
                MAX([myBackupSet].[backup_finish_date]) AS [backup_finish_date],
                MAX([myBackupSet].[expiration_date])	AS [expiration_date],
                MAX([myBackupSet].[type])				AS [type],
                MIN([myBackupSet].[first_lsn])			AS [first_lsn],
                MAX([myBackupSet].[last_lsn])			AS [last_lsn]
            FROM
                [msdb].[dbo].[backupset]			AS [myBackupSet]
                INNER JOIN [sys].[databases] AS [myDatabases] ON [myBackupSet].[database_name] = [myDatabases].[name]
            WHERE
                [myBackupset].[is_copy_only] = 0
                AND [myDatabases].[name] IN ("+$myDatabases+")
                AND [myBackupSet].[type] IN ("+$myBackupTypes+")
                AND [myBackupSet].[backup_finish_date] IS NOT NULL
                AND [myBackupSet].[backup_start_date] >= DATEADD(
                                                                    HOUR,
                                                                    @HoursToScanForUntransferredBackups,
                                                                    @myCurrentDateTime
                                                                )
                AND [myBackupSet].[server_name] = @@ServerName
                AND [myBackupSet].[description] NOT LIKE '%' + @TransferedSuffix + '%'
            GROUP BY
                [myBackupSet].[media_set_id]
        ) AS [myUniqueBackupSet] ON [myUniqueBackupSet].[media_set_id] = [myMediaSet].[media_set_id]
    WHERE
        [myMediaSet].[mirror] = 0
    ORDER BY
        [myUniqueBackupSet].[backup_start_date] ASC,
        [myMediaSet].[media_set_id] ASC;
    "
    try{
        Write-Verbose $myCommand
        $this.LogWriter.Write($this.LogStaticMessage+'Retrive list of unsent backup files.',[LogType]::INF)
        [System.Data.DataRow[]]$myRecords=$null
        $myRecords=Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop
        if ($null -ne $myRecords){
            [System.Collections.ArrayList]$myBackupFileCollection=$null
            $myBackupFileCollection=[System.Collections.ArrayList]::new()
            $myRecords|ForEach-Object{$myBackupFileCollection.Add([BackupFile]::New($mySourceServerName,$mySourceInstanceName,$_.FamilySequenceNumber,$_.MaxFamilySequenceNumber,$_.DatabaseName,$_.BackupStartTime,$_.BackupFinishTime,$_.ExpirationDate,$_.BackupType,$_.FirstLsn,$_.LastLsn,$_.MediaSetId,$_.FilePath,$_.FileName,$DestinationFolderStructure))}
            $myAnswer=$myBackupFileCollection.ToArray([BackupFile])
        }
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $myAnswer.Clear()
    }
    return $myAnswer
}
hidden [BackupCatalogItem[]]Get_DepricatedCatalogItems (){   #Retrive list of deprecated  backup catalog items accordinf to DeleteDate
    $this.LogWriter.Write($this.LogStaticMessage+'Processing Started.', [LogType]::INF)    
    [BackupCatalogItem[]]$myAnswer=$null
    [string]$myCommand=$null

    $myCommand="
    DECLARE @myToday Datetime
    SET @myToday=getdate()
    
    SELECT
        [Id],
        [BatchId],
        [EventTimeStamp],
        [Destination],
        [DestinationFolder],
        [UncBackupFilePath],
        [media_set_id],
        [family_sequence_number],
        [MachineName],
        [InstanceName],
        [DatabaseName],
        [backup_start_date],
        [backup_finish_date],
        [expiration_date],
        [BackupType],
        [BackupFirstLSN],
        [BackupLastLSN],
        [BackupFilePath],
        [BackupFileName],
        [max_family_sequence_number],
        [DeleteDate],
        [IsDeleted],
        [TransferStatus]
    FROM 
        [dbo].["+$this.BackupShippingCatalogTableName+"] AS myTransferLog
    WHERE
        myTransferLog.DeleteDate <= @myToday
        AND myTransferLog.IsDeleted = 0
        AND myTransferLog.TransferStatus = 'SUCCEED'
    ORDER BY
        Id
"
    try{
        Write-Verbose $myCommand
        $this.LogWriter.Write($this.LogStaticMessage+'Retrive list of delete backup candidate files.',[LogType]::INF)
        [System.Data.DataRow[]]$myRecords=$null
        $myRecords=Invoke-Sqlcmd -ConnectionString $this.LogWriter.LogInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop
        if ($null -ne $myRecords){
            [System.Collections.ArrayList]$myBackupCatalogCollection=$null
            $myBackupCatalogCollection=[System.Collections.ArrayList]::new()
            $myRecords|ForEach-Object{$myBackupCatalogCollection.Add([BackupCatalogItem]::New($_.Id,$_.BatchId,$_.EventTimeStamp,$_.Destination,$_.DestinationFolder,$_.UncBackupFilePath,$_.media_set_id,$_.family_sequence_number,$_.MachineName,$_.InstanceName,$_.DatabaseName,$_.backup_start_date,$_.backup_finish_date,$_.expiration_date,$_.BackupType,$_.BackupFirstLSN,$_.BackupLastLSN,$_.BackupFilePath,$_.BackupFileName,$_.max_family_sequence_number,$_.DeleteDate,$_.IsDeleted,$_.TransferStatus))}
            $myAnswer=$myBackupCatalogCollection.ToArray([BackupCatalogItem])
        }
    }Catch{
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
        $myAnswer.Clear()
    }
    return $myAnswer
}
[void] Transfer_AllDatabasesBackup([string[]]$ExcludedList){  #Transfer Backup from source to destination
    Write-Verbose ('Transfer_AllDatabasesBackup')
    $this.LogWriter.Write($this.LogStaticMessage+('Transfer_AllDatabasesBackup'),[LogType]::INF)
    [string]$myExludedDB=''
    [string[]]$myDatabases=$null

    if ($null -ne $ExcludedList){
        foreach ($myExceptedDB in $ExcludedList){
            $myExludedDB+=",'" + $myExceptedDB.Trim() + "'"
        }
    }
    [string]$myCommand="
        SELECT [name] AS [DbName] FROM sys.databases WHERE [state]=0 AND [name] NOT IN ('master','msdb','model','tempdb','SSISDB','DWConfiguration','DWDiagnostics','DWQueue','SqlDeep','distribution'"+$myExludedDB+") ORDER BY [name]
        "
    
        try{
        [System.Data.DataRow[]]$myRecords=$null
        $myRecords=Invoke-Sqlcmd -ConnectionString $this.SourceInstanceConnectionString -Query $myCommand -OutputSqlErrors $true -QueryTimeout 0 -OutputAs DataRows -ErrorAction Stop
        if ($null -ne $myRecords) {
            $Null=$myRecords | ForEach-Object{$myDatabases += $_.DbName}
            $this.Databases=$myDatabases
            $this.Transfer_Backup()
        }
    }Catch{
        Write-Verbose(($_.ToString()).ToString())
    }
}
[void] Transfer_Backup(){  #Transfer Backup from source to destination
    try {
        #--=======================Initial ShipBackup Modules
        Write-Verbose ('===== Shipping backup file(s) started. =====')
        $this.BatchUid=(New-Guid).ToString()
        $this.LogStaticMessage= ''
        $this.LogWriter.Write($this.LogStaticMessage+'BackupShipping started.', [LogType]::INF) 
        
        #--=======================Set constants
        [bool]$myDestinationIsAlive=$false
        [BackupFile[]]$myUntransferredBackups=$null
        [System.Collections.ArrayList]$myFolderList = $null
        [string]$myCurrentMachineName=([Environment]::MachineName).ToUpper()
        $this.Databases=$this.Databases | Clear-SqlParameter -RemoveWildcard -RemoveBraces -RemoveSingleQuote -RemoveDoubleQuote -RemoveDollerSign  #Clear database names
        $this.TransferedFileDescriptionSuffix=Clear-SqlParameter -ParameterValue ($this.TransferedFileDescriptionSuffix) -RemoveWildcard -RemoveBraces -RemoveSingleQuote -RemoveDoubleQuote -RemoveDollerSign  #Clear TransferedFileDescriptionSuffix value
        $this.DestinationFolderStructure=(Clear-SqlParameter -ParameterValue $this.DestinationFolderStructure -RemoveWildcard -RemoveSingleQuote -RemoveDoubleQuote -RemoveDollerSign).Replace('\\','')
        if ($this.DestinationFolderStructure[0] -eq '\') {$this.DestinationFolderStructure.Remove(0,1)}

        #--=======================Check and load assemblies
        $this.LogWriter.Write($this.LogStaticMessage+'Check and load assemblies.', [LogType]::INF) 
        if ($this.DestinationType -in ([DestinationType]::FTP,[DestinationType]::SFTP,[DestinationType]::SCP)) {
            $this.LogWriter.Write($this.LogStaticMessage+'Try to load WinSCP .NET assembly.', [LogType]::INF) 
            if ((Test-Path -Path ($this.WinscpPath) -PathType Leaf) -eq $false){
                $this.LogWriter.Write($this.LogStaticMessage+'Winscp dll file does not exists on ' + $this.WinscpPath, [LogType]::ERR)
                throw ('Winscp dll file does not exists.')
            }
            try {
                Add-Type -Path $this.WinscpPath
            } catch {
                $this.LogWriter.Write($this.LogStaticMessage+'Winscp dll file could not be loaded.', [LogType]::ERR)
                throw ('Winscp dll file could not be loaded.')
            }
        }
        #--=======================Check source instance connectivity and it's specifications
        $this.LogWriter.Write($this.LogStaticMessage+'Test Source Instance Connectivity of ' + $this.SourceInstanceConnectionString, [LogType]::INF) 
        if ((Test-DatabaseConnection -ConnectionString ($this.SourceInstanceConnectionString) -DatabaseName 'msdb') -eq $false) {
            $this.LogWriter.Write($this.LogStaticMessage+'Source Instance Connection failure.', [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Source Instance Connection failure.')
        }
        #--=======================Check shipped files catalog table connectivity
        $this.LogWriter.Write($this.LogStaticMessage+'Test shipped files catalog table connectivity.', [LogType]::INF) 
        if ((Test-DatabaseConnection -ConnectionString ($this.LogWriter.LogInstanceConnectionString) -DatabaseName 'master') -eq $false) {
            $this.LogWriter.Write($this.LogStaticMessage+'Can not connect to shipped files log sql instance on ' + $this.LogWriter.LogInstanceConnectionString, [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Can not connect to shipped files log sql instance.')
        }
        $this.LogWriter.Write($this.LogStaticMessage+'Initializing Shipped files catalog table.', [LogType]::INF)
        if ($this.Create_ShippedBackupsCatalog() -eq $false)  {
            $this.LogWriter.Write($this.LogStaticMessage+'Can not initialize table to save shipped files catalog on ' + $this.LogWriter.LogInstanceConnectionString + ' to ' + $this.BackupShippingCatalogTableName + ' table.', [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Shipped files catalog initialization failed.')
        }
        #--=======================Check destination credential existence
        $this.LogWriter.Write($this.LogStaticMessage+'Check destination credential existence.', [LogType]::INF) 
        if (!($this.DestinationCredential)) {
            $this.LogWriter.Write($this.LogStaticMessage+'Destination Credential is not exists.', [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Destination Credential is not exists.')
        }
        #--=======================Check destination connectivity
        $this.LogWriter.Write($this.LogStaticMessage+'Check Destination Connectivity with DestinationType of ' + $this.DestinationType + ', Destionation location of ' + $this.Destination + ' and DestinationCredential Username of ' + $this.DestinationCredential.UserName, [LogType]::INF) 
        $myDestinationIsAlive = switch ($this.DestinationType) 
        {
            FTP    {$this.Operate_OverFtp([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,$null,$null)}
            SFTP   {$this.Operate_OverSftp([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,$null,$null,$this.SshHostKeyFingerprint)}
            SCP    {$this.Operate_OverScp([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,$null,$null,$this.SshHostKeyFingerprint)}
            UNC    {$this.Operate_OverUnc([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,'A',$null,$null)}
        }
        if ($myDestinationIsAlive -eq $false){
            $this.LogWriter.Write($this.LogStaticMessage+'Destination is not avilable.', [LogType]::ERR) 
            throw 'Destination is not avilable.'
        }
        #--=======================Get files to transfer
        $this.LogWriter.Write($this.LogStaticMessage+'Get list of untransferred backup files from ' + $this.SourceInstanceConnectionString + ' with HoursToScanForUntransferredBackups=' + $this.HoursToScanForUntransferredBackups.ToString() + ', TransferedFileDescriptionSuffix=' + $this.TransferedFileDescriptionSuffix, [LogType]::INF) 
        $myUntransferredBackups=$this.Get_UntransferredBackups($this.SourceInstanceConnectionString,$this.Databases,$this.BackupTypes,$this.HoursToScanForUntransferredBackups,$this.TransferedFileDescriptionSuffix,$this.DestinationFolderStructure)
        if ($null -eq $myUntransferredBackups) {
            $this.LogWriter.Write($this.LogStaticMessage+'There is no file(s) to transfer or maybe errors occured in retriving backup list, to ensure there is no error check previos log for any error occurance.', [LogType]::ERR) 
            throw 'There is no file(s) to transfer or maybe errors occured in retriving backup list, to ensure there is no error check previos log for any error occurance.'
        }
        #--=======================Create folder structure in destination
        $this.LogWriter.Write($this.LogStaticMessage+'Create folder structure on destination ' + $this.Destination + ' With path structure of ' + $this.DestinationFolderStructure,[LogType]::INF)
        $this.LogWriter.Write($this.LogStaticMessage+'Extract unique folder list.',[LogType]::INF)
        $myFolderList = @($myUntransferredBackups | Select-Object -Property DestinationFolder -Unique)

        $this.LogWriter.Write($this.LogStaticMessage+'Try to create folders.',[LogType]::INF)
        switch ($this.DestinationType) 
        {
            FTP   {$myFolderList | ForEach-Object {$this.Operate_OverFtp([HostOperation]::MKDIR,$this.Destination,$this.DestinationCredential,$_.DestinationFolder,$null)}}
            SFTP  {$myFolderList | ForEach-Object {$this.Operate_OverSFtp([HostOperation]::MKDIR,$this.Destination,$this.DestinationCredential,$_.DestinationFolder,$null,$this.SshHostKeyFingerprint)}}
            SCP   {$myFolderList | ForEach-Object {$this.Operate_OverScp([HostOperation]::MKDIR,$this.Destination,$this.DestinationCredential,$_.DestinationFolder,$null,$this.SshHostKeyFingerprint)}}
            UNC   {$myFolderList | ForEach-Object {$this.Operate_OverUnc([HostOperation]::MKDIR,$this.Destination,$this.DestinationCredential,'A',$_.DestinationFolder,$null)}}
            LOCAL {$myFolderList | ForEach-Object {$this.Operate_OverUnc([HostOperation]::MKDIR,$this.Destination,$this.DestinationCredential,'A',$_.DestinationFolder,$null)}}
        }
        #--=======================Transfer file(s) to destination
        $this.LogWriter.Write($this.LogStaticMessage+'Transfer file(s) from source to destination is started.',[LogType]::INF)
        switch ($this.DestinationType) 
        {
            FTP   {$myUntransferredBackups | ForEach-Object {
                                                                $mySourceFile=if($myCurrentMachineName -eq $_.ServerName.ToUpper()){$_.FilePath}else{$_.RemoteSourceFilePath}
                                                                $this.New_ShippedBackupsCatalogItem($_,'NONE')
                                                                ForEach ($myPath IN $_.DestinationFolder.Split(';'))
                                                                {
                                                                    $mySendResult=$this.Operate_OverFtp([HostOperation]::UPLOAD,$this.Destination,$this.DestinationCredential,($myPath+'/'+$_.FileName),$mySourceFile)
                                                                    if($mySendResult -eq $true) {
                                                                        $this.LogWriter.Write($this.LogStaticMessage+'Update BackupCatalogItem and MSDB.',[LogType]::INF)
                                                                        $this.Set_BackupsCatalogItemAsShippedOnMsdb($_)
                                                                        $this.Set_ShippedBackupsCatalogItemStatus($_)
                                                                    }
                                                                }
                                                            }
                    }
            SFTP  {$myUntransferredBackups | ForEach-Object {
                                                                $mySourceFile=if($myCurrentMachineName -eq $_.ServerName.ToUpper()){$_.FilePath}else{$_.RemoteSourceFilePath}
                                                                $this.New_ShippedBackupsCatalogItem($_,'NONE')
                                                                ForEach ($myPath IN $_.DestinationFolder.Split(';'))
                                                                {
                                                                    $mySendResult=$this.Operate_OverSftp([HostOperation]::UPLOAD,$this.Destination,$this.DestinationCredential,($myPath+'/'+$_.FileName),$mySourceFile,$this.SshHostKeyFingerprint)
                                                                    if($mySendResult -eq $true) {
                                                                        $this.LogWriter.Write($this.LogStaticMessage+'Update BackupCatalogItem and MSDB.',[LogType]::INF)
                                                                        $this.Set_BackupsCatalogItemAsShippedOnMsdb($_)
                                                                        $this.Set_ShippedBackupsCatalogItemStatus($_)
                                                                    }
                                                                }
                                                            }
                    }
            SCP   {$myUntransferredBackups | ForEach-Object {
                                                                $mySourceFile=if($myCurrentMachineName -eq $_.ServerName.ToUpper()){$_.FilePath}else{$_.RemoteSourceFilePath}
                                                                $this.New_ShippedBackupsCatalogItem($_,'NONE')
                                                                ForEach ($myPath IN $_.DestinationFolder.Split(';'))
                                                                {
                                                                    $mySendResult=$this.Operate_OverScp([HostOperation]::UPLOAD,$this.Destination,$this.DestinationCredential,($myPath+'/'+$_.FileName),$mySourceFile,$this.SshHostKeyFingerprint)
                                                                    if($mySendResult -eq $true) {
                                                                        $this.LogWriter.Write($this.LogStaticMessage+'Update BackupCatalogItem and MSDB.',[LogType]::INF)
                                                                        $this.Set_BackupsCatalogItemAsShippedOnMsdb($_)
                                                                        $this.Set_ShippedBackupsCatalogItemStatus($_)
                                                                    }
                                                                }
                                                            }
                    }
            UNC   {$myUntransferredBackups | ForEach-Object {
                                                                $mySourceFile=if($myCurrentMachineName -eq $_.ServerName.ToUpper()){$_.FilePath}else{$_.RemoteSourceFilePath}
                                                                $this.New_ShippedBackupsCatalogItem($_,'NONE')
                                                                ForEach ($myPath IN $_.DestinationFolder.Split(';')) 
                                                                {
                                                                    $mySendResult=$this.Operate_OverUnc([HostOperation]::UPLOAD,$this.Destination,$this.DestinationCredential,('A','B'),($myPath+'\'+$_.FileName),$mySourceFile)
                                                                    if($mySendResult -eq $true) {
                                                                        $this.LogWriter.Write($this.LogStaticMessage+'Update BackupCatalogItem and MSDB.',[LogType]::INF)
                                                                        $this.Set_BackupsCatalogItemAsShippedOnMsdb($_)
                                                                        $this.Set_ShippedBackupsCatalogItemStatus($_)
                                                                    }
                                                                } 
                                                            }
                    }
            LOCAL {$myUntransferredBackups | ForEach-Object {
                                                                $mySourceFile=if($myCurrentMachineName -eq $_.ServerName.ToUpper()){$_.FilePath}else{$_.RemoteSourceFilePath}
                                                                $this.New_ShippedBackupsCatalogItem($_,'NONE')
                                                                ForEach ($myPath IN $_.DestinationFolder.Split(';')) 
                                                                {
                                                                    $mySendResult=$this.Operate_OverUnc([HostOperation]::UPLOAD,$this.Destination,$this.DestinationCredential,'A',($myPath+'\'+$_.FileName),$mySourceFile)
                                                                    if($mySendResult -eq $true) {
                                                                        $this.LogWriter.Write($this.LogStaticMessage+'Update BackupCatalogItem and MSDB.',[LogType]::INF)
                                                                        $this.Set_BackupsCatalogItemAsShippedOnMsdb($_)
                                                                        $this.Set_ShippedBackupsCatalogItemStatus($_)
                                                                    }
                                                                } 
                                                            }
                    }
        }

        #--=======================Set Delete date for backups
        $this.LogWriter.Write($this.LogStaticMessage+'Set Delete date of backups to ' + $this.RetainDaysOnDestination,[LogType]::INF)
        $this.Set_ShippedBackupsCatalogItemDeleteDate()
    }
    catch {
        Write-Error ($_.ToString())
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
    }
    finally{
        Write-Verbose ('===== BackupShipping finished. =====')
        $this.LogWriter.Write($this.LogStaticMessage+('===== BackupShipping finished. ====='), [LogType]::INF) 

        if ($this.LogWriter.ErrCount -eq 0 -and $this.LogWriter.WrnCount -eq 0) {
            $this.LogWriter.Write($this.LogStaticMessage+'Finished.',[LogType]::INF)
        }elseif ($this.LogWriter.ErrCount -eq 0 -and $this.LogWriter.WrnCount -gt 0) {
            $this.LogWriter.Write($this.LogStaticMessage+('Finished with ' + $this.LogWriter.WrnCount.ToString() + ' Warning(s).'),[LogType]::WRN)
        }else{
            $this.LogWriter.Write($this.LogStaticMessage+('Finished with ' + $this.LogWriter.ErrCount.ToString() + ' Error(s) and ' + $this.LogWriter.WrnCount.ToString() + ' Warning(s).'),[LogType]::ERR)
        }
        $this.LogWriter.Write($this.LogStaticMessage+'===== Shipping backup process finished. ===== ', [LogType]::INF) 
    }
}
[void] Delete_DepricatedBackup(){  #Transfer Backup from source to destination
    try{
        #--=======================Initial Delete DepricatedBackup
        Write-Verbose ('===== Delete depricated backup file(s) started. =====')
        $this.LogStaticMessage= ''
        $this.LogWriter.Write($this.LogStaticMessage+'Delete_DepricatedBackup started.', [LogType]::INF) 

        #--=======================Set constants
        [bool]$myDestinationIsAlive=$false
        [BackupCatalogItem[]]$myBackupCatalogItems=$null
        [BackupCatalogItem]$myBackupCatalogItem=$null
        [string]$myFolder=$null
        [string]$myFile=$null
        [bool]$myResult=$true

        #--=======================Check and load assemblies
        $this.LogWriter.Write($this.LogStaticMessage+'Check and load assemblies.', [LogType]::INF) 
        if ($this.DestinationType -in ([DestinationType]::FTP,[DestinationType]::SFTP,[DestinationType]::SCP)) {
            $this.LogWriter.Write($this.LogStaticMessage+'Try to load WinSCP .NET assembly.', [LogType]::INF) 
            if ((Test-Path -Path ($this.WinscpPath) -PathType Leaf) -eq $false){
                $this.LogWriter.Write($this.LogStaticMessage+'Winscp dll file does not exists on ' + $this.WinscpPath, [LogType]::ERR)
                throw ('Winscp dll file does not exists.')
            }
            try {
                Add-Type -Path $this.WinscpPath
            } catch {
                $this.LogWriter.Write($this.LogStaticMessage+'Winscp dll file could not be loaded.', [LogType]::ERR)
                throw ('Winscp dll file could not be loaded.')
            }
        }
        #--=======================Check shipped files catalog table connectivity
        $this.LogWriter.Write($this.LogStaticMessage+'Test shipped files catalog table connectivity.', [LogType]::INF) 
        if ((Test-DatabaseConnection -ConnectionString ($this.LogWriter.LogInstanceConnectionString) -DatabaseName 'master') -eq $false) {
            $this.LogWriter.Write($this.LogStaticMessage+'Can not connect to shipped files log sql instance on ' + $this.LogWriter.LogInstanceConnectionString, [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Can not connect to shipped files log sql instance.')
        }
        $this.LogWriter.Write($this.LogStaticMessage+'Initializing Shipped files catalog table.', [LogType]::INF)
        if ($this.Create_ShippedBackupsCatalog() -eq $false)  {
            $this.LogWriter.Write($this.LogStaticMessage+'Can not initialize table to save shipped files catalog on ' + $this.LogWriter.LogInstanceConnectionString + ' to ' + $this.BackupShippingCatalogTableName + ' table.', [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Shipped files catalog initialization failed.')
        }
        #--=======================Check destination credential existence
        $this.LogWriter.Write($this.LogStaticMessage+'Check destination credential existence.', [LogType]::INF) 
        if (!($this.DestinationCredential)) {
            $this.LogWriter.Write($this.LogStaticMessage+'Destination Credential is not exists.', [LogType]::ERR) 
            throw ($this.LogStaticMessage+'Destination Credential is not exists.')
        }
        #--=======================Check destination connectivity
        $this.LogWriter.Write($this.LogStaticMessage+'Check Destination Connectivity with DestinationType of ' + $this.DestinationType + ', Destionation location of ' + $this.Destination + ' and DestinationCredential Username of ' + $this.DestinationCredential.UserName, [LogType]::INF) 
        $myDestinationIsAlive = switch ($this.DestinationType) 
        {
            FTP    {$this.Operate_OverFtp([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,$null,$null)}
            SFTP   {$this.Operate_OverSftp([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,$null,$null,$this.SshHostKeyFingerprint)}
            SCP    {$this.Operate_OverScp([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,$null,$null,$this.SshHostKeyFingerprint)}
            UNC    {$this.Operate_OverUnc([HostOperation]::ISALIVE,$this.Destination,$this.DestinationCredential,'A',$null,$null)}
        }
        if ($myDestinationIsAlive -eq $false){
            $this.LogWriter.Write($this.LogStaticMessage+'Destination is not avilable.', [LogType]::ERR) 
            throw 'Destination is not avilable.'
        }
        #--=======================Get files to delete
        $this.LogWriter.Write($this.LogStaticMessage+'Get list of deprecated catalog item file(s) to delete.', [LogType]::INF) 
        $myBackupCatalogItems=$this.Get_DepricatedCatalogItems()
        if ($null -eq $myBackupCatalogItems) {
            $this.LogWriter.Write($this.LogStaticMessage+'There is no catalog item(s) to delete.', [LogType]::ERR) 
            throw 'There is no catalog item(s) to delete.'
        }
        #--=======================Delete files
        ForEach ($myBackupCatalogItem IN $myBackupCatalogItems) {
            ForEach ($myFolder IN ($myBackupCatalogItem.DestinationFolder.Trim().Split(';')|Where-Object {$_.Length -gt 0})) {
                switch ($this.DestinationType) 
                {
                SCP {
                        $myFile = $myFolder + '/' + $myBackupCatalogItem.FileName
                        $this.LogWriter.Write($this.LogStaticMessage+'Start to delete ' + $myFile, [LogType]::INF) 
                        $myResult=$true
                        $myResult=$this.Operate_OverScp([HostOperation]::DELETE,$myBackupCatalogItem.Destination,$this.DestinationCredential,$myFile,$null,$this.SshHostKeyFingerprint)
                    }
                UNC {
                        $myFile = $this.Path_CorrectFolderPathFormat($myFolder) + '\' + $myBackupCatalogItem.FileName
                        $this.LogWriter.Write($this.LogStaticMessage+'Start to delete ' + $myFile, [LogType]::INF) 
                        $myResult=$true
                        $myResult=$this.Operate_OverUnc([HostOperation]::DELETE,$myBackupCatalogItem.Destination,$this.DestinationCredential,'A',$myFile,$null)
                    }
                }

                if ($myResult -eq $true) {
                    $this.LogWriter.Write($this.LogStaticMessage+$myFile+' is deleted.' + $myFile, [LogType]::INF) 
                    $this.Set_ShippedBackupsCatalogItemDeleteFlag($myBackupCatalogItem)
                    $this.LogWriter.Write($this.LogStaticMessage+$myFile+' with id ' + $myBackupCatalogItem.Id.ToString() + ' is flagged as deleted.' + $myFile, [LogType]::INF) 
                }else{
                    #$this.Set_ShippedBackupsCatalogItemDeleteFlag($myBackupCatalogItem)
                    $this.LogWriter.Write($this.LogStaticMessage+$myFile+' deletion is failed.' + $myFile, [LogType]::ERR) 
                }
            }
        }
    } 
    catch {
        Write-Error ($_.ToString())
        $this.LogWriter.Write($this.LogStaticMessage+($_.ToString()).ToString(), [LogType]::ERR)
    }
    finally {
        Write-Verbose ('===== Delete_DepricatedBackup finished. =====')
        $this.LogWriter.Write($this.LogStaticMessage+('===== Delete_DepricatedBackup finished. ====='), [LogType]::INF) 
    }
}
#endregion
}

#region Functions
Function New-BackupShipping {
    Param(
        [Parameter(Mandatory=$true)][string]$SourceInstanceConnectionString,
        [Parameter(Mandatory=$false)][BackupType[]]$BackupTypes=([BackupType]::FULL,[BackupType]::DIFF,[BackupType]::LOG),
        [Parameter(Mandatory=$false)][int]$HoursToScanForUntransferredBackups=72,
        [Parameter(Mandatory=$true)][DestinationType]$DestinationType,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][string]$DestinationFolderStructure,
        [Parameter(Mandatory=$false)][string]$RetainDaysOnDestination='7',
        [Parameter(Mandatory=$false)][string]$TransferedFileDescriptionSuffix='Transfered',
        [Parameter(Mandatory=$false)][string]$BackupShippingCatalogTableName='TransferredFiles',
        [Parameter(Mandatory=$true)][LogWriter]$LogWriter
    )
    Write-Verbose 'Creating New-BackupShipping'
    [string]$mySourceInstanceConnectionString=$SourceInstanceConnectionString;
    [BackupType[]]$myBackupTypes=$BackupTypes;
    [int]$myHoursToScanForUntransferredBackups=$HoursToScanForUntransferredBackups;
    [DestinationType]$myDestinationType=$DestinationType;
    [string]$myDestination=$Destination;
    [string]$myDestinationFolderStructure=$DestinationFolderStructure;
    [string]$myRetainDaysOnDestination=$RetainDaysOnDestination;
    [string]$myTransferedFileDescriptionSuffix=$TransferedFileDescriptionSuffix;
    [string]$myBackupShippingCatalogTableName=$BackupShippingCatalogTableName;
    [LogWriter]$myLogWriter=$LogWriter;
    [BackupShipping]::New($mySourceInstanceConnectionString,$myBackupTypes,$myHoursToScanForUntransferredBackups,$myDestinationType,$myDestination,$myDestinationFolderStructure,$myRetainDaysOnDestination,$myTransferedFileDescriptionSuffix,$myBackupShippingCatalogTableName,$myLogWriter)
    Write-Verbose 'New-BackupShipping Created'
}
#endregion

#region Export
Export-ModuleMember -Function New-BackupShipping
#endregion