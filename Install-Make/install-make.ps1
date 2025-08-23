#region Core Data Types
$Script:Config = @{
    CommonPaths = @(
        "C:\Program Files (x86)\GnuWin32\bin",
        "C:\Program Files\GnuWin32\bin",
        "C:\GnuWin32\bin"
    )
    PackageId = "GnuWin32.Make"
    ExecutableName = "make.exe"
}

$Script:Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Primary = "White"
    Secondary = "Gray"
    Accent = "Magenta"
    Log = "DarkGray"
}

$Script:Messages = @{
    AdminRequired = "ERROR: Este script necesita ejecutarse como Administrador."
    AdminHelp = "Haz clic derecho en PowerShell y selecciona 'Ejecutar como administrador'"
    InstallSuccess = "Instalacion completada exitosamente."
    InstallFailed = "ERROR: La instalacion fallo."
    PathExists = "La ruta ya esta en el PATH del sistema."
    PathAdded = "Exito: Se agrego la ruta al PATH del sistema."
    PathFailed = "ERROR: No se pudo agregar la ruta al PATH."
    NotFound = "No se encontro make.exe"
    InvalidPath = "ERROR: Ruta invalida o make.exe no encontrado"
}
#endregion

#region Logging Functions
function Write-Log {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logColor = switch ($Level.ToUpper()) {
        "ERROR" { $Script:Colors.Error }
        "WARN" { $Script:Colors.Warning }
        "SUCCESS" { $Script:Colors.Success }
        default { $Script:Colors.Log }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $logColor
}

function Write-StepBegin {
    [CmdletBinding()]
    param([string]$Step)

    Write-Host ""
    Write-Log "=== INICIANDO: $Step ===" "INFO"
}

function Write-StepEnd {
    [CmdletBinding()]
    param(
        [string]$Step,
        $Success = $true
    )

    # Convertir a boolean de manera explícita para evitar problemas de tipo
    $isSuccess = if ($Success -eq $true -or $Success -eq "True" -or $Success -eq 1) { $true } else { $false }

    $status = if ($isSuccess) { "COMPLETADO" } else { "FALLIDO" }
    $level = if ($isSuccess) { "SUCCESS" } else { "ERROR" }
    Write-Log -Message "=== ${status}: ${Step} ===" -Level $level
}

function Write-Progress {
    [CmdletBinding()]
    param([string]$Action)

    Write-Log "-> $Action" "INFO"
}
#endregion

#region Validation Functions
function Test-AdminPrivileges {
    [CmdletBinding()]
    param()

    Write-Log "Verificando privilegios de administrador..." "INFO"
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if ($isAdmin) {
        Write-Log "Privilegios de administrador confirmados" "SUCCESS"
    } else {
        Write-Log "Se requieren privilegios de administrador" "ERROR"
    }

    return $isAdmin
}

function Test-ExecutionPolicy {
    [CmdletBinding()]
    param()

    Write-Log "Verificando politica de ejecucion de PowerShell..." "INFO"

    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        $machinePolicy = Get-ExecutionPolicy -Scope LocalMachine

        Write-Log "Politica CurrentUser: $currentPolicy" "INFO"
        Write-Log "Politica LocalMachine: $machinePolicy" "INFO"

        # Verificar si las políticas permiten ejecutar scripts
        $restrictivePolicies = @("Restricted", "AllSigned")

        if ($restrictivePolicies -contains $currentPolicy -and $restrictivePolicies -contains $machinePolicy) {
            Write-Log "Politica de ejecucion restrictiva detectada" "ERROR"
            return $false
        }

        Write-Log "Politica de ejecucion permite ejecucion de scripts" "SUCCESS"
        return $true
    } catch {
        Write-Log "Error al verificar politica de ejecucion: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-ExecutionPolicyGuidance {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "PROBLEMA: Politica de Ejecucion Restrictiva Detectada" -ForegroundColor $Script:Colors.Error
    Write-Host "=" * 55 -ForegroundColor $Script:Colors.Error
    Write-Host ""

    Write-Host "SOLUCION RECOMENDADA:" -ForegroundColor $Script:Colors.Warning
    Write-Host "Ejecuta el siguiente comando en PowerShell como Administrador:" -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor $Script:Colors.Success
    Write-Host ""

    Write-Host "ALTERNATIVA (MAS PERMISIVA):" -ForegroundColor $Script:Colors.Warning
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process" -ForegroundColor $Script:Colors.Success
    Write-Host ""

    Write-Host "RIESGOS Y CONSIDERACIONES:" -ForegroundColor $Script:Colors.Error
    Write-Host "- RemoteSigned: Permite scripts locales, requiere firma digital para scripts remotos" -ForegroundColor $Script:Colors.Warning
    Write-Host "  * RIESGO BAJO: Recomendado para desarrollo y uso corporativo" -ForegroundColor $Script:Colors.Info
    Write-Host "  * Protege contra scripts maliciosos de internet" -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "- Bypass: Permite cualquier script sin restricciones (solo para sesion actual)" -ForegroundColor $Script:Colors.Warning
    Write-Host "  * RIESGO MEDIO: Uso temporal, no persiste al reiniciar PowerShell" -ForegroundColor $Script:Colors.Warning
    Write-Host "  * NO recomendado para uso permanente" -ForegroundColor $Script:Colors.Error
    Write-Host ""

    Write-Host "PASOS DETALLADOS:" -ForegroundColor $Script:Colors.Info
    Write-Host "1. Abre PowerShell como Administrador" -ForegroundColor $Script:Colors.Primary
    Write-Host "2. Ejecuta uno de los comandos mencionados arriba" -ForegroundColor $Script:Colors.Primary
    Write-Host "3. Confirma con 'Y' cuando se te solicite" -ForegroundColor $Script:Colors.Primary
    Write-Host "4. Vuelve a ejecutar este script" -ForegroundColor $Script:Colors.Primary
    Write-Host ""

    Write-Host "MAS INFORMACION:" -ForegroundColor $Script:Colors.Info
    Write-Host "https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy" -ForegroundColor $Script:Colors.Secondary
}

function Test-MakeExecutable {
    [CmdletBinding()]
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        Write-Log "Ruta vacia proporcionada para verificacion" "WARN"
        return $false
    }

    $fullPath = Join-Path $Path $Script:Config.ExecutableName
    $exists = Test-Path $fullPath

    Write-Log "Verificando $fullPath - Existe: $exists" "INFO"
    return $exists
}

function Test-PathInEnvironment {
    [CmdletBinding()]
    param([string]$Path)

    Write-Log "Verificando si '$Path' esta en PATH del sistema..." "INFO"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $inPath = $currentPath -like "*$Path*"

    Write-Log "Resultado verificacion PATH: $inPath" "INFO"
    return $inPath
}
#endregion

#region Pure Functions - Data Transformation
function ConvertTo-InstallationStatus {
    [CmdletBinding()]
    param([string]$Path)

    Write-Log "Generando estado de instalacion para: $Path" "INFO"

    @{
        Path = $Path
        IsValid = Test-MakeExecutable $Path
        InPath = if ($Path) { Test-PathInEnvironment $Path } else { $false }
        Exists = [bool]$Path
    }
}

function ConvertTo-SearchResult {
    [CmdletBinding()]
    param([string[]]$Paths)

    $pathCount = if ($Paths) { $Paths.Count } else { 0 }
    Write-Log "Procesando resultados de busqueda de $pathCount rutas" "INFO"

    $result = $Paths | ForEach-Object {
        @{
            Path = $_
            IsValid = Test-MakeExecutable $_
        }
    } | Where-Object { $_.IsValid } | Select-Object -First 1

    if ($result) {
        Write-Log "Resultado de busqueda exitoso: $($result.Path)" "SUCCESS"
    } else {
        Write-Log "No se encontraron rutas validas en la busqueda" "WARN"
    }

    return $result
}
#endregion

#region Pure Functions - Search Operations
function Find-InCommonPaths {
    [CmdletBinding()]
    param()

    Write-StepBegin "Busqueda en ubicaciones comunes"
    $pathCount = if ($Script:Config.CommonPaths) { $Script:Config.CommonPaths.Count } else { 0 }
    Write-Log "Buscando en $pathCount ubicaciones predefinidas" "INFO"

    foreach ($path in $Script:Config.CommonPaths) {
        Write-Progress "Verificando: $path"
        if (Test-MakeExecutable $path) {
            Write-Log "Encontrado en ubicacion comun: $path" "SUCCESS"
            Write-StepEnd "Busqueda en ubicaciones comunes" $true
            return $path
        }
    }

    Write-Log "No se encontro en ninguna ubicacion comun" "WARN"
    Write-StepEnd "Busqueda en ubicaciones comunes" $false
    return $null
}

function Find-InSystemWide {
    [CmdletBinding()]
    param()

    Write-StepBegin "Busqueda en todo el sistema"
    Write-Log "Iniciando busqueda exhaustiva en unidad C:" "INFO"

    try {
        $makeFiles = Get-ChildItem -Path "C:\" -Name $Script:Config.ExecutableName -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_ -like "*GnuWin32*" }

        $fileCount = if ($makeFiles) { $makeFiles.Count } else { 0 }
        Write-Log "Encontrados $fileCount archivos make.exe relacionados con GnuWin32" "INFO"

        if ($makeFiles) {
            $makePath = Split-Path $makeFiles[0] -Parent
            Write-Log "Verificando primera coincidencia: $makePath" "INFO"

            if (Test-MakeExecutable $makePath) {
                Write-Log "Busqueda en sistema completada exitosamente" "SUCCESS"
                Write-StepEnd "Busqueda en todo el sistema" $true
                return $makePath
            }
        }
    } catch {
        Write-Log "Error durante busqueda en sistema: $($_.Exception.Message)" "ERROR"
    }

    Write-Log "Busqueda en sistema no encontro resultados validos" "WARN"
    Write-StepEnd "Busqueda en todo el sistema" $false
    return $null
}

function Get-WingetInstallationStatus {
    [CmdletBinding()]
    param()

    Write-Log "Consultando estado de instalacion via winget..." "INFO"

    try {
        $result = winget list $Script:Config.PackageId 2>$null
        $isInstalled = [bool]($result -match $Script:Config.PackageId)

        Write-Log "Estado winget para $($Script:Config.PackageId): $isInstalled" "INFO"
        return $isInstalled
    } catch {
        Write-Log "Error al consultar winget: $($_.Exception.Message)" "WARN"
        return $false
    }
}
#endregion

#region Pure Functions - UI Components
function New-MenuHeader {
    [CmdletBinding()]
    param(
        [string]$Title,
        [string]$Color = $Script:Colors.Info
    )

    @{
        Separator = "=" * 40
        Title = "    $Title    "
        Color = $Color
    }
}

function New-MenuOption {
    [CmdletBinding()]
    param(
        [string]$Number,
        [string]$Text,
        [string]$Color = $Script:Colors.Primary
    )

    @{
        Number = $Number
        Text = $Text
        Color = $Color
        Display = "$Number. $Text"
    }
}

function New-StatusReport {
    [CmdletBinding()]
    param()

    Write-StepBegin "Generacion de reporte de estado"

    Write-Progress "Consultando estado winget"
    $wingetStatus = Get-WingetInstallationStatus

    Write-Progress "Buscando instalacion en ubicaciones comunes"
    $commonPath = Find-InCommonPaths

    Write-Progress "Verificando configuracion de PATH"
    $pathConfigured = if ($commonPath) { Test-PathInEnvironment $commonPath } else { $false }

    $report = @{
        WingetInstalled = $wingetStatus
        CommonPath = $commonPath
        PathConfigured = $pathConfigured
        IsOperational = $commonPath -and $pathConfigured
    }

    Write-Log "Reporte generado - Winget: $wingetStatus, Path: $commonPath, Configured: $pathConfigured" "INFO"
    Write-StepEnd "Generacion de reporte de estado" $true

    return $report
}
#endregion

#region IO Operations (Side Effects)
function Invoke-AdminCheck {
    [CmdletBinding()]
    param()

    Write-StepBegin "Verificacion de privilegios de administrador"

    if (-not (Test-AdminPrivileges)) {
        Write-Log "FALLO CRITICO: Script requiere privilegios de administrador" "ERROR"
        Write-Log "Usuario actual: $env:USERNAME" "INFO"
        Write-Log "Dominio/Equipo: $env:USERDOMAIN" "INFO"
        Write-Host ""
        Write-Host "ERROR CRITICO: Privilegios Insuficientes" -ForegroundColor $Script:Colors.Error
        Write-Host "=" * 45 -ForegroundColor $Script:Colors.Error
        Write-Host ""
        Write-Host $Script:Messages.AdminRequired -ForegroundColor $Script:Colors.Error
        Write-Host ""
        Write-Host "SOLUCION:" -ForegroundColor $Script:Colors.Warning
        Write-Host "1. Cierra esta ventana de PowerShell" -ForegroundColor $Script:Colors.Primary
        Write-Host "2. Presiona Win + X" -ForegroundColor $Script:Colors.Primary
        Write-Host "3. Selecciona 'Windows PowerShell (Administrador)'" -ForegroundColor $Script:Colors.Primary
        Write-Host "4. Navega a la carpeta del script y ejecutalo nuevamente" -ForegroundColor $Script:Colors.Primary
        Write-Host ""
        Write-Host "RAZON:" -ForegroundColor $Script:Colors.Info
        Write-Host "Este script modifica variables de entorno del sistema y" -ForegroundColor $Script:Colors.Secondary
        Write-Host "ejecuta instalaciones que requieren privilegios elevados." -ForegroundColor $Script:Colors.Secondary
        Write-Host ""
        Write-Log "Terminando ejecucion por falta de privilegios" "ERROR"
        Write-Host "Presiona cualquier tecla para salir..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-StepEnd "Verificacion de privilegios de administrador" $false
        exit 1
    }

    Write-StepEnd "Verificacion de privilegios de administrador" $true
}

function Invoke-ExecutionPolicyCheck {
    [CmdletBinding()]
    param()

    Write-StepBegin "Verificacion de politica de ejecucion"

    if (-not (Test-ExecutionPolicy)) {
        Write-Log "FALLO CRITICO: Politica de ejecucion restrictiva detectada" "ERROR"
        Write-Log "Se requiere cambiar la politica para continuar" "ERROR"

        Show-ExecutionPolicyGuidance

        Write-Log "Terminando ejecucion por politica de ejecucion restrictiva" "ERROR"
        Write-Host "Presiona cualquier tecla para salir..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-StepEnd "Verificacion de politica de ejecucion" $false
        exit 1
    }

    Write-StepEnd "Verificacion de politica de ejecucion" $true
}

function Write-MenuHeader {
    [CmdletBinding()]
    param([hashtable]$Header)

    Clear-Host
    Write-Host $Header.Separator -ForegroundColor $Header.Color
    Write-Host $Header.Title -ForegroundColor $Header.Color
    Write-Host $Header.Separator -ForegroundColor $Header.Color
    Write-Host ""
}

function Write-MenuOptions {
    [CmdletBinding()]
    param([hashtable[]]$Options)

    Write-Host "Selecciona una opcion:" -ForegroundColor $Script:Colors.Primary
    Write-Host ""

    $Options | ForEach-Object {
        Write-Host $_.Display -ForegroundColor $_.Color
    }

    Write-Host ""
    Write-Host "Opcion: " -ForegroundColor $Script:Colors.Primary -NoNewline
}

function Write-StatusReport {
    [CmdletBinding()]
    param([hashtable]$Status)

    Write-Host "Verificando instalacion actual..." -ForegroundColor $Script:Colors.Info
    Write-Host ""

    $wingetColor = if ($Status.WingetInstalled) { $Script:Colors.Success } else { $Script:Colors.Error }
    $wingetText = if ($Status.WingetInstalled) { "Instalado" } else { "No encontrado" }
    Write-Host "Estado winget: $wingetText" -ForegroundColor $wingetColor

    $pathColor = if ($Status.CommonPath) { $Script:Colors.Success } else { $Script:Colors.Error }
    $pathText = if ($Status.CommonPath) { $Status.CommonPath } else { "No encontrado" }
    Write-Host "Ubicacion comun: $pathText" -ForegroundColor $pathColor

    $configColor = if ($Status.PathConfigured) { $Script:Colors.Success } else { $Script:Colors.Error }
    $configText = if ($Status.PathConfigured) { "Si ($($Status.CommonPath))" } else { "No" }
    Write-Host "PATH configurado: $configText" -ForegroundColor $configColor

    Write-Progress "Verificando funcionamiento de make"
    try {
        $makeVersion = & make --version 2>$null
        if ($makeVersion) {
            Write-Host "Funcionamiento: Operativo" -ForegroundColor $Script:Colors.Success
            Write-Host "Version: $($makeVersion[0])" -ForegroundColor $Script:Colors.Primary
        } else {
            Write-Host "Funcionamiento: No operativo" -ForegroundColor $Script:Colors.Error
        }
    } catch {
        Write-Host "Funcionamiento: No operativo" -ForegroundColor $Script:Colors.Error
    }
}

function Read-UserInput {
    [CmdletBinding()]
    param([string]$Prompt = "")

    if ($Prompt) {
        Write-Host $Prompt -ForegroundColor $Script:Colors.Info
    }
    Read-Host
}

function Wait-UserInput {
    [CmdletBinding()]
    param([string]$Message = "Presiona cualquier tecla para continuar...")

    Write-Host ""
    Write-Host $Message
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Write-SearchProgress {
    [CmdletBinding()]
    param([string]$Message)

    Write-Host $Message -ForegroundColor $Script:Colors.Warning
    Write-Host "Esto puede tomar varios minutos..." -ForegroundColor $Script:Colors.Warning
}
#endregion

#region Business Logic (Pure + IO)
function Update-CurrentEnvironment {
    [CmdletBinding()]
    param()

    Write-StepBegin "Actualizacion de variables de entorno"

    try {
        Write-Progress "Obteniendo PATH de Machine"
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

        Write-Progress "Obteniendo PATH de User"
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

        Write-Progress "Combinando y aplicando nuevo PATH"
        $env:PATH = $machinePath + ";" + $userPath

        Write-Host "Variables de entorno actualizadas en la sesion actual." -ForegroundColor $Script:Colors.Info
        Write-StepEnd "Actualizacion de variables de entorno" $true
        return $true
    } catch {
        Write-Log "Error al actualizar variables de entorno: $($_.Exception.Message)" "ERROR"
        Write-Host "WARNING: No se pudieron actualizar las variables de entorno en la sesion actual." -ForegroundColor $Script:Colors.Warning
        Write-StepEnd "Actualizacion de variables de entorno" $false
        return $false
    }
}

function Test-MakeCommand {
    [CmdletBinding()]
    param()

    Write-Progress "Verificando comando make"

    try {
        $makeVersion = & make --version 2>$null
        if ($makeVersion) {
            Write-Host "Verificacion exitosa: make esta funcionando" -ForegroundColor $Script:Colors.Success
            Write-Host "Version: $($makeVersion[0])" -ForegroundColor $Script:Colors.Primary
            Write-Log "Comando make verificado exitosamente: $($makeVersion[0])" "SUCCESS"
            return $true
        }
    } catch {
        Write-Log "Error al verificar comando make: $($_.Exception.Message)" "WARN"
    }

    Write-Log "Comando make no esta disponible o no funciona" "WARN"
    return $false
}

function Invoke-Installation {
    [CmdletBinding()]
    param()

    Write-StepBegin "Instalacion de GnuWin32 Make"
    Write-Host "Instalando GnuWin32 Make..." -ForegroundColor $Script:Colors.Info

    try {
        Write-Progress "Ejecutando winget install"
        winget install --id=$($Script:Config.PackageId) -e --silent | Out-Null

        Write-Log "Winget exit code: $LASTEXITCODE" "INFO"

        if ($LASTEXITCODE -eq 0) {
            Write-Host $Script:Messages.InstallSuccess -ForegroundColor $Script:Colors.Success
            Write-StepEnd "Instalacion de GnuWin32 Make" $true
            return $true
        } else {
            Write-Host "$($Script:Messages.InstallFailed) Codigo de salida: $LASTEXITCODE" -ForegroundColor $Script:Colors.Error
            Write-StepEnd "Instalacion de GnuWin32 Make" $false
            return $false
        }
    } catch {
        Write-Log "Excepcion durante instalacion: $($_.Exception.Message)" "ERROR"
        Write-Host $Script:Messages.InstallFailed -ForegroundColor $Script:Colors.Error
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor $Script:Colors.Error
        Write-StepEnd "Instalacion de GnuWin32 Make" $false
        return $false
    }
}

function Invoke-PathConfiguration {
    [CmdletBinding()]
    param([string]$InstallPath)

    Write-StepBegin "Configuracion de PATH del sistema"
    Write-Log "Configurando PATH para: $InstallPath" "INFO"

    if (-not (Test-MakeExecutable $InstallPath)) {
        Write-Host "$($Script:Messages.InvalidPath): $InstallPath" -ForegroundColor $Script:Colors.Error
        Write-StepEnd "Configuracion de PATH del sistema" $false
        return $false
    }

    if (Test-PathInEnvironment $InstallPath) {
        Write-Host "$($Script:Messages.PathExists) '$InstallPath'" -ForegroundColor $Script:Colors.Warning

        Write-Progress "PATH ya configurado, refrescando entorno"
        Update-CurrentEnvironment | Out-Null
        if (Test-MakeCommand) {
            Write-StepEnd "Configuracion de PATH del sistema" $true
            return $true
        } else {
            Write-Host "FALLBACK: Cierra y abre Git Bash para usar make" -ForegroundColor $Script:Colors.Warning
            Write-StepEnd "Configuracion de PATH del sistema" $true
            return $true
        }
    }

    try {
        Write-Progress "Obteniendo PATH actual del sistema"
        $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)

        Write-Progress "Agregando nueva ruta al PATH"
        $newPath = $currentPath + ";" + $InstallPath
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)

        Write-Host "$($Script:Messages.PathAdded) '$InstallPath'" -ForegroundColor $Script:Colors.Success

        Write-Progress "PATH configurado, refrescando variables de entorno"
        if (Update-CurrentEnvironment) {
            Write-Host "Verificando funcionamiento..." -ForegroundColor $Script:Colors.Info

            if (Test-MakeCommand) {
                Write-Host "Configuracion completada - make listo para usar!" -ForegroundColor $Script:Colors.Success
            } else {
                Write-Host "PATH configurado correctamente." -ForegroundColor $Script:Colors.Success
                Write-Host "FALLBACK: Si make no funciona, cierra y abre Git Bash" -ForegroundColor $Script:Colors.Warning
            }
        } else {
            Write-Host "PATH configurado correctamente." -ForegroundColor $Script:Colors.Success
            Write-Host "Para usar make:" -ForegroundColor $Script:Colors.Info
            Write-Host "1. Cierra Git Bash completamente"
            Write-Host "2. Abre Git Bash nuevamente"
            Write-Host "3. Ejecuta: make --version"
        }

        Write-StepEnd "Configuracion de PATH del sistema" $true
        return $true
    } catch {
        Write-Log "Error al configurar PATH: $($_.Exception.Message)" "ERROR"
        Write-Host $Script:Messages.PathFailed -ForegroundColor $Script:Colors.Error
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor $Script:Colors.Error
        Write-StepEnd "Configuracion de PATH del sistema" $false
        return $false
    }
}

function Invoke-CommonSearch {
    [CmdletBinding()]
    param()

    Write-StepBegin "Busqueda y configuracion - Ubicaciones comunes"

    $installPath = Find-InCommonPaths

    if ($installPath) {
        Write-Host "Make encontrado en: $installPath" -ForegroundColor $Script:Colors.Success
        $result = Invoke-PathConfiguration $installPath
        Write-StepEnd "Busqueda y configuracion - Ubicaciones comunes" $result
        return $result
    } else {
        Write-Host "$($Script:Messages.NotFound) en ubicaciones comunes." -ForegroundColor $Script:Colors.Error
        Write-Host "Ubicaciones verificadas:" -ForegroundColor $Script:Colors.Warning
        $Script:Config.CommonPaths | ForEach-Object {
            Write-Host "- $_" -ForegroundColor $Script:Colors.Warning
        }
        Write-StepEnd "Busqueda y configuracion - Ubicaciones comunes" $false
        return $false
    }
}

function Invoke-SystemSearch {
    [CmdletBinding()]
    param()

    Write-StepBegin "Busqueda y configuracion - Sistema completo"

    $commonPath = Find-InCommonPaths

    if ($commonPath) {
        Write-Host "Make encontrado en ubicacion comun: $commonPath" -ForegroundColor $Script:Colors.Success
        $result = Invoke-PathConfiguration $commonPath
        Write-StepEnd "Busqueda y configuracion - Sistema completo" $result
        return $result
    }

    Write-SearchProgress "Buscando make.exe de GnuWin32 en todo el sistema..."
    $systemPath = Find-InSystemWide

    if ($systemPath) {
        Write-Host "Make encontrado en: $systemPath" -ForegroundColor $Script:Colors.Success
        $result = Invoke-PathConfiguration $systemPath
        Write-StepEnd "Busqueda y configuracion - Sistema completo" $result
        return $result
    } else {
        Write-Host "$($Script:Messages.NotFound) de GnuWin32 en el sistema." -ForegroundColor $Script:Colors.Error
        Write-StepEnd "Busqueda y configuracion - Sistema completo" $false
        return $false
    }
}

function Invoke-ManualConfiguration {
    [CmdletBinding()]
    param()

    Write-StepBegin "Configuracion manual de PATH"

    Write-Host "Introduce la ruta completa al directorio bin de GnuWin32:" -ForegroundColor $Script:Colors.Info
    Write-Host "Ejemplo: C:\Program Files (x86)\GnuWin32\bin" -ForegroundColor $Script:Colors.Secondary
    $manualPath = Read-Host "Ruta"

    if ($manualPath) {
        Write-Log "Usuario proporciono ruta manual: $manualPath" "INFO"
        $result = Invoke-PathConfiguration $manualPath
        Write-StepEnd "Configuracion manual de PATH" $result
        return $result
    }

    Write-Log "Usuario no proporciono ruta manual" "WARN"
    Write-StepEnd "Configuracion manual de PATH" $false
    return $false
}

function Invoke-CompleteProcess {
    [CmdletBinding()]
    param()

    Write-StepBegin "Proceso completo de instalacion y configuracion"
    Write-Host "Ejecutando proceso completo..." -ForegroundColor $Script:Colors.Accent

    if (-not (Invoke-Installation)) {
        Write-StepEnd "Proceso completo de instalacion y configuracion" $false
        return $false
    }

    Write-Progress "Esperando estabilizacion del sistema (2 segundos)"
    Start-Sleep -Seconds 2

    $installPath = Find-InCommonPaths
    if ($installPath) {
        Write-Host "Configurando PATH..." -ForegroundColor $Script:Colors.Info
        if (Invoke-PathConfiguration $installPath) {
            Write-Host ""
            Write-Host "Proceso completo finalizado exitosamente!" -ForegroundColor $Script:Colors.Success
            Write-StepEnd "Proceso completo de instalacion y configuracion" $true
            return $true
        }
    } else {
        Write-Host "WARNING: Instalacion completada pero make.exe no se encuentra en ubicaciones comunes." -ForegroundColor $Script:Colors.Warning
        Write-Host "Usa la opcion 2 para configurar el PATH manualmente." -ForegroundColor $Script:Colors.Warning
    }

    Write-StepEnd "Proceso completo de instalacion y configuracion" $false
    return $false
}
#endregion

#region Menu Systems
function Show-MainMenu {
    [CmdletBinding()]
    param()

    $header = New-MenuHeader "INSTALADOR GNUWIN32 MAKE v1.0"
    $options = @(
        New-MenuOption "1" "Instalar GnuWin32 Make" $Script:Colors.Success
        New-MenuOption "2" "Configurar PATH del sistema" $Script:Colors.Warning
        New-MenuOption "3" "Verificar instalacion actual" $Script:Colors.Info
        New-MenuOption "4" "Proceso completo (Instalar + Configurar PATH)" $Script:Colors.Accent
        New-MenuOption "5" "Salir" $Script:Colors.Error
    )

    Write-MenuHeader $header
    Write-MenuOptions $options
}

function Show-PathMenu {
    [CmdletBinding()]
    param()

    $header = New-MenuHeader "CONFIGURACION DE PATH" $Script:Colors.Warning
    $options = @(
        New-MenuOption "1" "Buscar en ubicaciones comunes solamente" $Script:Colors.Success
        New-MenuOption "2" "Buscar en ubicaciones comunes + todo el sistema" $Script:Colors.Warning
        New-MenuOption "3" "Especificar ruta manualmente" $Script:Colors.Info
        New-MenuOption "4" "Volver al menu principal" $Script:Colors.Error
    )

    Write-MenuHeader $header
    Write-MenuOptions $options
}

function Invoke-MainMenuChoice {
    [CmdletBinding()]
    param([string]$Choice)

    Write-Log "Usuario selecciono opcion principal: $Choice" "INFO"

    switch ($Choice) {
        "1" {
            Write-Host ""
            Invoke-Installation | Out-Null
            Wait-UserInput
        }

        "2" {
            do {
                Show-PathMenu
                $pathChoice = Read-Host
                $continue = Invoke-PathMenuChoice $pathChoice
            } while ($continue)
        }

        "3" {
            Write-Host ""
            $status = New-StatusReport
            Write-StatusReport $status
            Wait-UserInput
        }

        "4" {
            Write-Host ""
            Invoke-CompleteProcess | Out-Null
            Wait-UserInput
        }

        "5" {
            Write-Host ""
            Write-Log "Usuario solicito salir de la aplicacion" "INFO"
            Write-Host "Saliendo del instalador..." -ForegroundColor $Script:Colors.Success
            exit 0
        }

        default {
            Write-Log "Opcion invalida seleccionada: $Choice" "WARN"
            Write-Host "Opcion invalida. Presiona cualquier tecla para continuar..." -ForegroundColor $Script:Colors.Error
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

function Invoke-PathMenuChoice {
    [CmdletBinding()]
    param([string]$Choice)

    Write-Log "Usuario selecciono opcion PATH: $Choice" "INFO"

    switch ($Choice) {
        "1" {
            Write-Host ""
            Invoke-CommonSearch | Out-Null
            Wait-UserInput
            return $true
        }

        "2" {
            Write-Host ""
            Invoke-SystemSearch | Out-Null
            Wait-UserInput
            return $true
        }

        "3" {
            Write-Host ""
            Invoke-ManualConfiguration | Out-Null
            Wait-UserInput
            return $true
        }

        "4" {
            Write-Log "Usuario regresa al menu principal desde PATH menu" "INFO"
            return $false
        }

        default {
            Write-Log "Opcion PATH invalida seleccionada: $Choice" "WARN"
            Write-Host "Opcion invalida. Presiona cualquier tecla para continuar..." -ForegroundColor $Script:Colors.Error
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $true
        }
    }
}
#endregion

#region Main Application
function Start-Application {
    [CmdletBinding()]
    param()

    Write-Log "=== INICIANDO INSTALADOR GNUWIN32 MAKE ===" "INFO"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
    Write-Log "Sistema Operativo: $([System.Environment]::OSVersion.VersionString)" "INFO"
    Write-Log "Usuario: $env:USERNAME en $env:USERDOMAIN" "INFO"

    # Verificaciones críticas antes de continuar
    Invoke-ExecutionPolicyCheck
    Invoke-AdminCheck

    Write-Log "Todas las verificaciones preliminares completadas exitosamente" "SUCCESS"
    Write-Log "Iniciando bucle principal de la aplicacion" "INFO"

    do {
        Show-MainMenu
        $choice = Read-Host
        Invoke-MainMenuChoice $choice
    } while ($true)
}

# Entry Point - Verificaciones inmediatas
Write-Log "Script iniciado desde: $PSScriptRoot" "INFO"
Write-Log "Archivo de script: $MyInvocation.MyCommand.Name" "INFO"

# Verificación temprana de PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Log "ADVERTENCIA: PowerShell version antigua detectada" "WARN"
    Write-Host "WARNING: PowerShell $($PSVersionTable.PSVersion) detectado" -ForegroundColor Yellow
    Write-Host "Se recomienda PowerShell 5.1 o superior para mejor compatibilidad" -ForegroundColor Yellow
    Write-Host ""
}

Start-Application
#endregion