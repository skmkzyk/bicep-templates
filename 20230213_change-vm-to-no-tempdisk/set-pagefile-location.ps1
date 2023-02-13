Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="C:\pagefile.sys"; InitialSize = 0; MaximumSize = 0} -EnableAllPrivileges | Out-Null

$pagefileset = Get-WmiObject Win32_PageFileSetting | where{$_.caption -like 'D:*'}
$pagefileset.Delete()
