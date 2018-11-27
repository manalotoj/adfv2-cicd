param
(
    [parameter(Mandatory = $false)] [String] $ResourceGroupName,
    [parameter(Mandatory = $false)] [String] $DataFactoryName,
    [parameter(Mandatory = $false)] [String] $ArmTemplate
)

function Stop-TriggersAndIntegrationRuntimes(
    [String] $ResourceGroupName,
    [String] $DataFactoryName,
    [String] $ArmTemplate) {

    $templateJson = Get-Content $ArmTemplate | ConvertFrom-Json
    $resources = $templateJson.resources

    #Triggers 
    Write-Host "Getting triggers"
    $triggersADF = Get-AzureRmDataFactoryV2Trigger -DataFactoryName $DataFactoryName -ResourceGroupName $ResourceGroupName
    $triggersTemplate = $resources | Where-Object { $_.type -eq "Microsoft.DataFactory/factories/triggers" }
    $triggerNames = $triggersTemplate | ForEach-Object {$_.name.Substring(37, $_.name.Length-40)}
    $triggerstostop = $triggerNames | Where-Object { ($triggersADF | Select-Object name).name -contains $_ }

    Write-Host "Getting integration runtimes"
    $integrationruntimesADF = Get-AzureRmDataFactoryV2IntegrationRuntime -DataFactoryName $DataFactoryName -ResourceGroupName $ResourceGroupName
    $integrationruntimesTemplate = $resources | Where-Object { $_.type -eq "Microsoft.DataFactory/factories/integrationruntimes" }
    $integrationruntimesNames = $integrationruntimesTemplate | ForEach-Object {$_.name.Substring(52, $_.name.Length-56)}
    $runtimestostop = $integrationruntimesNames | Where-Object {('integrationRuntime_' + ($integrationruntimesADF | Select-Object name).name) -contains $_ }

    #Stop all triggers
    Write-Host "Stopping deployed triggers"
    $triggerstostop | ForEach-Object { 
        Write-host "Disabling trigger " $_
        Stop-AzureRmDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $_ -Force 
    }

    #Stop all integration runtimes
    Write-Host "Stopping deployed integration runtimes"
    $runtimestostop | ForEach-Object {     
        Write-host "Disabling runtime " $_.Substring(19, $_.length-19)
        $runtime = Get-AzureRmDataFactoryV2IntegrationRuntime -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName
        if ($runtime.State -eq "Started") {
            Stop-AzureRmDataFactoryV2IntegrationRuntime -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $_.Substring(19, $_.length-19) -Force
        } 
        else {
            write-host("pipeline",$runtime.Name,"with status",$runtime.State,"was not stopped")
        }
    }
}

Stop-TriggersAndIntegrationRuntimes $ResourceGroupName $DataFactoryName $ArmTemplate
