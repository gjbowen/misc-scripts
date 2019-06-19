Set objNetwork = WScript.CreateObject("WScript.Network")
 Set objFSO = WScript.CreateObject("Scripting.FileSystemObject")
Set wshShell = WScript.CreateObject( "WScript.Shell" )
strUserName = wshShell.ExpandEnvironmentStrings( "gjbowen" )


 If objFSO.DriveExists("G:") Then
 objNetwork.RemoveNetworkDrive "G:", True, False
 End If
 objNetwork.MapNetworkDrive "G:", "\\UAFS1.UA-NET.UA.EDU\APPS", false
'WshShell.Popup "          The G drive has been restored!",1,"Script Message"


 If objFSO.DriveExists("S:") Then
 objNetwork.RemoveNetworkDrive "S:", True, False
 End If
 objNetwork.MapNetworkDrive "S:", "\\UAFS1.UA-NET.UA.EDU\SHARE\OIT", false
'WshShell.Popup "          The S drive has been restored!",1,"Script Message"


 If objFSO.DriveExists("H:") Then
 objNetwork.RemoveNetworkDrive "H:", True, False
 End If
 objNetwork.MapNetworkDrive "H:", "\\home.ua-net.ua.edu\g\" & strUserName, false
'WshShell.Popup "          The H drive has been restored!",1,"Script Message"

'WshShell.Popup "Your network drives have been restored. - Greg",3,"Script Message"