<#
    .SYNOPSIS
		Password expiration dialog.
	.DESCRIPTION
    	Password expiration notice dialog. When the users password expiration is less than 5
		days the dialog appears notifying them their password is about to expire. Create a GPO
		and set this as the logon script.
		
		The background color changes based on the remaining days before the password expires.
		Expires <= 5 days background: Blue
		Expires <= 2 days background: Gold
		Expires <= 1 days background: Red 
    .NOTES
		Created by: 	Rick Bankers
		Date created:	08/11/15
	.LINK
	
#>
Clear-Host

#===========================================================================
# XAML Code. Create any XAML code you wish and place it here.
# REQUIREMENT: Label called "expireDays" which will display the remaining days
# before the password expires.
#===========================================================================
$inputXML = @"
<Window x:Class="PasswordExpires_v200.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="1CUNA Information" Height="225" Width="565" WindowStyle="None" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Topmost="True" HorizontalAlignment="Center" Background="#FF2AA0F1">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="15" />
            <ColumnDefinition Width="15" />
            <ColumnDefinition Width="9*" />
            <ColumnDefinition Width="15" />
            <ColumnDefinition Width="15" />
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="*" />
            <RowDefinition Height="2*" />
            <RowDefinition Height="*" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>
        <Rectangle Grid.Row="1" Grid.Column="1" Fill="White" Height="Auto"/>
        <Rectangle Grid.Row="1" Grid.Column="2" Fill="White" Height="Auto"/>
        <Grid Grid.Row="1" Grid.Column="2" HorizontalAlignment="Center">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="Your password will expire in " HorizontalAlignment="Right" VerticalAlignment="Bottom" FontSize="13.333" FontWeight="Bold"/>
            <TextBlock Grid.Column="1" x:Name="expireDays" Text=" ## " HorizontalAlignment="Center" VerticalAlignment="Bottom" FontSize="13.333" FontWeight="Bold" Foreground="#FFFF0303"/>
            <TextBlock Grid.Column="2" Text=" days!" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="13.333" FontWeight="Bold"/>
        </Grid>
        <Rectangle Grid.Row="1" Grid.Column="3" Fill="White" Height="Auto"/>
        <Rectangle Grid.Row="2" Grid.Column="1" Fill="White" Height="Auto"/>
        <Rectangle Grid.Row="2" Grid.Column="2" Fill="White" Height="Auto" Stroke="Black" StrokeThickness="2"/>
        <TextBlock Grid.Row="2" Grid.Column="2" Padding="5,5" TextWrapping="Wrap" Text="Please change your password by pressing CTRL+ALT+DEL and clicking change password. If you have any questions or problems please contact the help desk. (Ext. 4900)." HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="13.333"/>
        <Rectangle Grid.Row="2" Grid.Column="3" Fill="White" Height="Auto"/>
        <Rectangle Grid.Row="3" Grid.Column="1" Fill="White" Height="Auto"/>
        <Rectangle Grid.Row="3" Grid.Column="2" Fill="White" Height="Auto"/>
        <TextBlock Grid.Row="3" Grid.Column="2" Text="(Click here to close this window.)" HorizontalAlignment="Center" VerticalAlignment="Top" FontSize="13.333" FontWeight="Bold"/>
        <Rectangle Grid.Row="3" Grid.Column="3" Fill="White" Height="Auto"/>
    </Grid>
</Window>
"@       
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'
 
 
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
$reader=(New-Object System.Xml.XmlNodeReader $xaml) 

try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}
 
#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

#===========================================================================
# List XAML Form Variables
#===========================================================================
Function Get-FormVariables{
if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Blue;$global:ReadmeDisplay=$true}
write-host "Found the following interactable elements from our form" -ForegroundColor Blue
get-variable WPF*
}
#Get-FormVariables

#===========================================================================
# Add leftclick close function to form.
#===========================================================================
$Form.Add_MouseLeftButtonUp({ $Form.close() })

#===========================================================================
# Active Directory Searcher Function
#===========================================================================
Function Search-AD {            
param (            
    [string[]]$Filter,            
    [string[]]$Properties,            
    [string]$SearchRoot            
)            
            
    if ($SearchRoot) {            
        $Root = [ADSI]$SearchRoot  
		$Root.RefreshCache(@($Properties)) # Refresh ADSI properties cache 
    } else {            
        $Root = [ADSI]''
		$Root.RefreshCache(@($Properties)) # Refresh ADSI properties cache 
    }            
            
    if ($Filter) {            
        $LDAP = "(&({0}))" -f ($Filter -join ')(')            
    } else {            
        $LDAP = "(name=*)"            
    }            
            
    if (!$Properties) {            
        $Properties = 'Name','ADSPath'            
    }            
            
    (New-Object ADSISearcher -ArgumentList @(            
        $Root,            
        $LDAP,            
        $Properties            
    ) -Property @{            
        PageSize = 1000            
    }).FindAll() | ForEach-Object { 
        $ObjectProps = @{}            
        $_.Properties.GetEnumerator() |             
            Foreach-Object {
			
                $ObjectProps.Add(            
                    $_.Name,             
                    (-join $_.Value)            
                )            
        }            
        New-Object PSObject -Property $ObjectProps |             
            select $Properties            
    }            
}

#===========================================================================
# Check user's UserAccountControl and msDS-UserPasswordExpiryTimeComputed
# properties and display dialog.
#===========================================================================
$userRegInfo = Get-ItemProperty "HKCU:\Volatile Environment"
$adUser = $userRegInfo.Username
$adUserInfo = Search-AD -filter "samaccountname=$adUser" @("msDS-UserPasswordExpiryTimeComputed","UserAccountControl")
#$adUserInfo."useraccountcontrol"
#$adUserInfo."msds-userpasswordexpirytimecomputed"
#(([datetime]::FromFileTime($adUserInfo."msds-userpasswordexpirytimecomputed"))-(Get-Date)).Days

#===========================================================================
# Exit if password is set never to expire.
#===========================================================================
If ($adUserInfo."useraccountcontrol" -ge 65536) {
	Exit  # Password set to never expire.
}
$actualExpirationDays = (([datetime]::FromFileTime($adUserInfo."msds-userpasswordexpirytimecomputed"))-(Get-Date)).Days

$WPFexpireDays.Text = $actualExpirationDays

#===========================================================================
# Change dialog color based on remaining expiration days.
#===========================================================================
If ($actualExpirationDays -le 1)
	{
		$Form.Background = "Red"
		$errMsg = ("Password expiration notification: $UserName password expires in $actualExpirationDays days" )
		Write-EventLog –LogName 'Application' –Source "Microsoft-Windows-User Profiles Service" –EntryType Warning –EventID 3001 –Message $errMsg
		[Void]$Form.ShowDialog()
		Exit
	}
If ($actualExpirationDays -le 2)
	{
		$Form.Background = "Gold"
		$errMsg = ("Password expiration notification: $UserName password expires in $actualExpirationDays days" )
		Write-EventLog –LogName 'Application' –Source "Microsoft-Windows-User Profiles Service" –EntryType Warning –EventID 3001 –Message $errMsg
		[Void]$Form.ShowDialog()
		Exit
	}
If ($actualExpirationDays -le 5)
	{
		$Form.Background = "DodgerBlue" 
		$errMsg = ("Password expiration notification: $UserName password expires in $actualExpirationDays days" )
		Write-EventLog –LogName 'Application' –Source "Microsoft-Windows-User Profiles Service" –EntryType Warning –EventID 3001 –Message $errMsg
		[Void]$Form.ShowDialog()
		Exit
	}
	
#===========================================================================
# Set to $true to always display dialog for debugging.
#===========================================================================

If ($true)
	{
		$Form.Background = "DodgerBlue" 
		$errMsg = ("Password expiration notification: $UserName password expires in $actualExpirationDays days" )
		Write-EventLog –LogName 'Application' –Source "Microsoft-Windows-User Profiles Service" –EntryType Warning –EventID 3001 –Message $errMsg
		[Void]$Form.ShowDialog()
		Exit
	}
