﻿@{
RootModule = './Adele.psm1'

ModuleVersion = '0.0.10'


GUID        = '1394e467-edd1-4cbe-a0fd-1f893fdb3366'
Author      = 'Thomas Jaekel'
Copyright   = '(c) 2017 Thomas Jaekel. All rights reserved.'
Description = 'Automated DEployment of Lab Environment (ADELE)'

# Minimum version of the Windows PowerShell engine required by this module
 PowerShellVersion = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('New-AdeleStandaloneServer',
                      'New-AdeleDomainController',
                      'New-AdeleMemberServer',
                      'New-AdeleNVHost')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

}