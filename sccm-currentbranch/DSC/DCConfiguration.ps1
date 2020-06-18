configuration Configuration
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [String]$DCName,
        [Parameter(Mandatory)]
        [String]$ClientName,
        [Parameter(Mandatory)]
        [String]$Win7ClientName,
        [Parameter(Mandatory)]
        [String]$AADClientName,
        [Parameter(Mandatory)]
        [String]$PSName,
        [Parameter(Mandatory)]
        [String]$DNSIPAddress,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds
    )

    Import-DscResource -ModuleName TemplateHelpDSC

    $LogFolder = "TempLog"
    $LogPath = "c:\$LogFolder"
    $CM = "CMCB"
    $DName = $DomainName.Split(".")[0]
    $PSComputerAccount = "$DName\$PSName$"
   # $DPMPComputerAccount = "$DName\$DPMPName$"
    $ClientComputerAccount = "$DName\$ClientName$"
    $Win7ClientComputerAccount = "$DName\$Win7ClientName$"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node LOCALHOST
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        SetCustomPagingFile PagingSettings
        {
            Drive       = 'C:'
            InitialSize = '8192'
            MaximumSize = '8192'
        }
        
        InstallFeatureForSCCM InstallFeature
        {
            Name = 'DC'
            Role = 'DC'
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        SetupDomain FirstDS
        {
            DomainFullName = $DomainName
            SafemodeAdministratorPassword = $DomainCreds
            DependsOn = "[InstallFeatureForSCCM]InstallFeature"
        }

        InstallCA InstallCA
        {
            HashAlgorithm = "SHA256"
            DependsOn = "[SetupDomain]FirstDS"
        }

        VerifyComputerJoinDomain WaitForPS
        {
            ComputerName = $PSName
            Ensure = "Present"
            DependsOn = "[InstallCA]InstallCA"
        }

     #   VerifyComputerJoinDomain WaitForDPMP
     #   {
     #       ComputerName = $DPMPName
     #       Ensure = "Present"
     #       DependsOn = "[InstallCA]InstallCA"
     #   }

        VerifyComputerJoinDomain WaitForClient
        {
            ComputerName = $ClientName
            Ensure = "Present"
            DependsOn = "[InstallCA]InstallCA"
        }


        VerifyComputerJoinDomain WaitForWin7Client
        {
            ComputerName = $Win7ClientName
            Ensure = "Present"
            DependsOn = "[InstallCA]InstallCA"
        }


        File ShareFolder
        {            
            DestinationPath = $LogPath     
            Type = 'Directory'            
            Ensure = 'Present'
            DependsOn = @("[VerifyComputerJoinDomain]WaitForPS","[VerifyComputerJoinDomain]WaitForClient","[VerifyComputerJoinDomain]WaitForWin7Client")
        }

        FileReadAccessShare DomainSMBShare
        {
            Name   = $LogFolder
            Path =  $LogPath
            Account = $PSComputerAccount,$ClientComputerAccount,$Win7ClientComputerAccount
            DependsOn = "[File]ShareFolder"
        }

        WriteConfigurationFile WritePSJoinDomain
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "PSJoinDomain"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

     #   WriteConfigurationFile WriteDPMPJoinDomain
      #  {
       #     Role = "DC"
        #    LogPath = $LogPath
         #   WriteNode = "DPMPJoinDomain"
          #  Status = "Passed"
           # Ensure = "Present"
            #DependsOn = "[FileReadAccessShare]DomainSMBShare"
        #}

        WriteConfigurationFile WriteClientJoinDomain
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "ClientJoinDomain"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[FileReadAccessShare]DomainSMBShare"
        }

        DelegateControl AddPS
        {
            Machine = $PSName
            DomainFullName = $DomainName
            Ensure = "Present"
            DependsOn = "[WriteConfigurationFile]WritePSJoinDomain"
        }

   #     DelegateControl AddDPMP
   #    {
   #         Machine = $DPMPName
   #         DomainFullName = $DomainName
   #         Ensure = "Present"
   #         DependsOn = "[WriteConfigurationFile]WriteDPMPJoinDomain"
   #    }

        WriteConfigurationFile WriteDelegateControlfinished
        {
            Role = "DC"
            LogPath = $LogPath
            WriteNode = "DelegateControl"
            Status = "Passed"
            Ensure = "Present"
            DependsOn = "[DelegateControl]AddPS"
        }

        WaitForExtendSchemaFile WaitForExtendSchemaFile
        {
            MachineName = $PSName
            ExtFolder = $CM
            Ensure = "Present"
            DependsOn = "[WriteConfigurationFile]WriteDelegateControlfinished"
        }
    }
}
