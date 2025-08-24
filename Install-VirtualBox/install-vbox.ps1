<#
.SYNOPSIS
    Instalador y configurador completo de VirtualBox con Extension Pack y requisitos.

.DESCRIPTION
    Este script instala Microsoft Visual C++ 2019, VirtualBox 7.1.8,
    Extension Pack y configura VBoxManage en el PATH del sistema.

.PARAMETER Install
    Instala todos los componentes necesarios.

.PARAMETER Configure
    Configura VBoxManage en el PATH del sistema.

.PARAMETER Verify
    Verifica la instalacion completa.

.PARAMETER All
    Ejecuta todos los pasos (Instalar, Configurar y Verificar).

.EXAMPLE
    .\install-vbox.ps1 -Install

.EXAMPLE
    .\install-vbox.ps1 -All
#>

[CmdletBinding()]
param (
    [switch]$Install,
    [switch]$Configure,
    [switch]$Verify,
    [switch]$All
)

#region Core Data Types
$Script:Config = @{
    VirtualBox = @{
        Version = "7.1.8"
        DownloadUrl = "https://download.virtualbox.org/virtualbox/7.1.8/VirtualBox-7.1.8-164202-Win.exe"
        ExtensionPackUrl = "https://download.virtualbox.org/virtualbox/7.1.8/Oracle_VirtualBox_Extension_Pack-7.1.8.vbox-extpack"
        InstallPath = "C:\Program Files\Oracle\VirtualBox"
        ExecutableName = "VBoxManage.exe"
    }
    VisualCpp = @{
        DownloadUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        ProductCode = "{F4220E7E-28F2-4026-92F7-80C2419AF6B5}"
        DisplayName = "Microsoft Visual C++ 2015-2022 Redistributable (x64)"
    }
    TempPath = $env:TEMP
    Logging = @{
        LogDirectory = Join-Path $PSScriptRoot "logs"
        LogFileName = "install-vbox-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        MaxLogFiles = 10
    }
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
    PathExists = "VBoxManage ya esta en el PATH del sistema."
    PathAdded = "VBoxManage agregado al PATH del sistema exitosamente."
    PathFailed = "ERROR: No se pudo agregar VBoxManage al PATH."
    NotFound = "VBoxManage no encontrado."
    AlreadyInstalled = "ya esta instalado."
}
#endregion

#region Logging Functions
function Initialize-LogDirectory {
    [CmdletBinding()]
    param()

    $logDir = $Script:Config.Logging.LogDirectory

    if (-not (Test-Path $logDir)) {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            Write-Host "Directorio de logs creado: $logDir" -ForegroundColor $Script:Colors.Info
        } catch {
            Write-Host "ERROR: No se pudo crear directorio de logs: $($_.Exception.Message)" -ForegroundColor $Script:Colors.Error
            return $false
        }
    }

    # Limpiar logs antiguos
    try {
        $existingLogs = Get-ChildItem -Path $logDir -Filter "install-vbox-*.log" | Sort-Object LastWriteTime -Descending
        if ($existingLogs.Count -gt $Script:Config.Logging.MaxLogFiles) {
            $logsToDelete = $existingLogs | Select-Object -Skip $Script:Config.Logging.MaxLogFiles
            foreach ($log in $logsToDelete) {
                Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Error en limpieza no es critico, continuar
    }

    return $true
}

function Write-Log {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logColor = switch ($Level.ToUpper()) {
        "ERROR" { $Script:Colors.Error }
        "WARN" { $Script:Colors.Warning }
        "SUCCESS" { $Script:Colors.Success }
        default { $Script:Colors.Log }
    }

    $logMessage = "[$timestamp] [$Level] $Message"

    # Mostrar en consola
    Write-Host $logMessage -ForegroundColor $logColor

    # Escribir a archivo de log
    if ($Script:Config.Logging.LogDirectory) {
        try {
            $logFilePath = Join-Path $Script:Config.Logging.LogDirectory $Script:Config.Logging.LogFileName
            $logMessage | Out-File -FilePath $logFilePath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {
            # Error en escritura de log no debe interrumpir el proceso
        }
    }
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

function Test-VisualCppInstalled {
    [CmdletBinding()]
    param()

    Write-Log "Verificando Microsoft Visual C++ 2019/2022..." "INFO"

    try {
        $installedPrograms = Get-WmiObject -Class Win32_Product | Where-Object {
            $_.Name -like "*Microsoft Visual C++*" -and
                    ($_.Name -like "*2015*" -or $_.Name -like "*2019*" -or $_.Name -like "*2022*")
        }

        if ($installedPrograms) {
            foreach ($program in $installedPrograms) {
                Write-Log "Encontrado: $($program.Name)" "SUCCESS"
            }
            return $true
        }

        Write-Log "Microsoft Visual C++ 2015-2022 no encontrado" "WARN"
        return $false
    } catch {
        Write-Log "Error al verificar Visual C++: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-VirtualBoxInstalled {
    [CmdletBinding()]
    param()

    Write-Log "Verificando instalacion de VirtualBox..." "INFO"
    $vboxPath = Join-Path $Script:Config.VirtualBox.InstallPath $Script:Config.VirtualBox.ExecutableName

    if (Test-Path $vboxPath) {
        try {
            $version = & $vboxPath --version 2>$null
            Write-Log "VirtualBox encontrado: $version" "SUCCESS"
            return $true
        } catch {
            Write-Log "VirtualBox encontrado pero no funcional" "WARN"
            return $false
        }
    }

    Write-Log "VirtualBox no encontrado en: $vboxPath" "WARN"
    return $false
}

function Test-ExtensionPackInstalled {
    [CmdletBinding()]
    param()

    Write-Log "Verificando Extension Pack..." "INFO"
    $vboxPath = Join-Path $Script:Config.VirtualBox.InstallPath $Script:Config.VirtualBox.ExecutableName

    if (-not (Test-Path $vboxPath)) {
        Write-Log "VBoxManage no disponible para verificar Extension Pack" "WARN"
        return $false
    }

    try {
        $extPacks = & $vboxPath list extpacks 2>$null
        if ($extPacks -like "*Oracle VirtualBox Extension Pack*") {
            Write-Log "Extension Pack instalado" "SUCCESS"
            return $true
        }

        Write-Log "Extension Pack no encontrado" "WARN"
        return $false
    } catch {
        Write-Log "Error al verificar Extension Pack: $($_.Exception.Message)" "ERROR"
        return $false
    }
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

#region IO Operations
function Invoke-AdminCheck {
    [CmdletBinding()]
    param()

    Write-StepBegin "Verificacion de privilegios de administrador"

    if (-not (Test-AdminPrivileges)) {
        Write-Log "FALLO CRITICO: Script requiere privilegios de administrador" "ERROR"
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
        Write-Host ""
        Write-Host "PROBLEMA: Politica de Ejecucion Restrictiva Detectada" -ForegroundColor $Script:Colors.Error
        Write-Host "=" * 55 -ForegroundColor $Script:Colors.Error
        Write-Host ""
        Write-Host "SOLUCION RECOMENDADA:" -ForegroundColor $Script:Colors.Warning
        Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor $Script:Colors.Success
        Write-Host ""
        Write-Log "Terminando ejecucion por politica de ejecucion restrictiva" "ERROR"
        Write-Host "Presiona cualquier tecla para salir..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-StepEnd "Verificacion de politica de ejecucion" $false
        exit 1
    }

    Write-StepEnd "Verificacion de politica de ejecucion" $true
}

function Wait-UserInput {
    [CmdletBinding()]
    param([string]$Message = "Presiona cualquier tecla para continuar...")

    Write-Host ""
    Write-Host $Message
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
#endregion

#region Download Functions
function Invoke-FileDownload {
    [CmdletBinding()]
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )

    Write-Progress "Descargando $Description..."
    Write-Log "URL: $Url" "INFO"
    Write-Log "Destino: $OutputPath" "INFO"

    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)

        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-Log "Descarga completada: $([math]::Round($fileSize, 2)) MB" "SUCCESS"
            return $true
        } else {
            Write-Log "Error: Archivo no encontrado despues de descarga" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error en descarga: $($_.Exception.Message)" "ERROR"
        return $false
    } finally {
        if ($webClient) { $webClient.Dispose() }
    }
}
#endregion

#region Installation Functions
function Install-VisualCppRedistributable {
    [CmdletBinding()]
    param()

    Write-StepBegin "Instalacion de Microsoft Visual C++ 2019/2022"

    if (Test-VisualCppInstalled) {
        Write-Host "Microsoft Visual C++ 2015-2022 $($Script:Messages.AlreadyInstalled)" -ForegroundColor $Script:Colors.Success
        Write-StepEnd "Instalacion de Microsoft Visual C++ 2019/2022" $true
        return $true
    }

    $installerPath = Join-Path $Script:Config.TempPath "vc_redist.x64.exe"

    if (-not (Invoke-FileDownload -Url $Script:Config.VisualCpp.DownloadUrl -OutputPath $installerPath -Description "Visual C++ Redistributable")) {
        Write-StepEnd "Instalacion de Microsoft Visual C++ 2019/2022" $false
        return $false
    }

    try {
        Write-Progress "Ejecutando instalador de Visual C++..."
        $process = Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/norestart" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Host "Visual C++ Redistributable instalado exitosamente" -ForegroundColor $Script:Colors.Success
            Remove-Item $installerPath -ErrorAction SilentlyContinue
            Write-StepEnd "Instalacion de Microsoft Visual C++ 2019/2022" $true
            return $true
        } else {
            Write-Log "Instalador Visual C++ termino con codigo: $($process.ExitCode)" "ERROR"
            Write-StepEnd "Instalacion de Microsoft Visual C++ 2019/2022" $false
            return $false
        }
    } catch {
        Write-Log "Error ejecutando instalador Visual C++: $($_.Exception.Message)" "ERROR"
        Write-StepEnd "Instalacion de Microsoft Visual C++ 2019/2022" $false
        return $false
    }
}

function Install-VirtualBox {
    [CmdletBinding()]
    param()

    Write-StepBegin "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)"

    if (Test-VirtualBoxInstalled) {
        Write-Host "VirtualBox $($Script:Messages.AlreadyInstalled)" -ForegroundColor $Script:Colors.Success
        Write-StepEnd "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)" $true
        return $true
    }

    $installerPath = Join-Path $Script:Config.TempPath "VirtualBox-Installer.exe"

    if (-not (Invoke-FileDownload -Url $Script:Config.VirtualBox.DownloadUrl -OutputPath $installerPath -Description "VirtualBox $($Script:Config.VirtualBox.Version)")) {
        Write-StepEnd "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)" $false
        return $false
    }

    try {
        Write-Progress "Ejecutando instalador de VirtualBox..."
        $process = Start-Process -FilePath $installerPath -ArgumentList "--silent" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Host "VirtualBox instalado exitosamente" -ForegroundColor $Script:Colors.Success
            Remove-Item $installerPath -ErrorAction SilentlyContinue

            Start-Sleep -Seconds 2

            if (Test-VirtualBoxInstalled) {
                Write-StepEnd "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)" $true
                return $true
            } else {
                Write-Log "VirtualBox se instalo pero no se puede verificar" "WARN"
                Write-StepEnd "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)" $false
                return $false
            }
        } else {
            Write-Log "Instalador VirtualBox termino con codigo: $($process.ExitCode)" "ERROR"
            Write-StepEnd "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)" $false
            return $false
        }
    } catch {
        Write-Log "Error ejecutando instalador VirtualBox: $($_.Exception.Message)" "ERROR"
        Write-StepEnd "Instalacion de VirtualBox $($Script:Config.VirtualBox.Version)" $false
        return $false
    }
}

function Install-ExtensionPack {
    [CmdletBinding()]
    param()

    Write-StepBegin "Instalacion de VirtualBox Extension Pack"

    if (Test-ExtensionPackInstalled) {
        Write-Host "VirtualBox Extension Pack $($Script:Messages.AlreadyInstalled)" -ForegroundColor $Script:Colors.Success
        Write-StepEnd "Instalacion de VirtualBox Extension Pack" $true
        return $true
    }

    $vboxPath = Join-Path $Script:Config.VirtualBox.InstallPath $Script:Config.VirtualBox.ExecutableName
    if (-not (Test-Path $vboxPath)) {
        Write-Log "VBoxManage no disponible. Instale VirtualBox primero." "ERROR"
        Write-StepEnd "Instalacion de VirtualBox Extension Pack" $false
        return $false
    }

    $extPackPath = Join-Path $Script:Config.TempPath "Oracle_VirtualBox_Extension_Pack.vbox-extpack"

    if (-not (Invoke-FileDownload -Url $Script:Config.VirtualBox.ExtensionPackUrl -OutputPath $extPackPath -Description "VirtualBox Extension Pack")) {
        Write-StepEnd "Instalacion de VirtualBox Extension Pack" $false
        return $false
    }

    try {
        Write-Progress "Instalando Extension Pack..."
        $process = Start-Process -FilePath $vboxPath -ArgumentList "extpack", "install", "--replace", $extPackPath -Wait -PassThru -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Write-Host "Extension Pack instalado exitosamente" -ForegroundColor $Script:Colors.Success
            Remove-Item $extPackPath -ErrorAction SilentlyContinue

            if (Test-ExtensionPackInstalled) {
                Write-StepEnd "Instalacion de VirtualBox Extension Pack" $true
                return $true
            } else {
                Write-Log "Extension Pack se instalo pero no se puede verificar" "WARN"
                Write-StepEnd "Instalacion de VirtualBox Extension Pack" $false
                return $false
            }
        } else {
            Write-Log "Instalacion Extension Pack termino con codigo: $($process.ExitCode)" "ERROR"
            Write-StepEnd "Instalacion de VirtualBox Extension Pack" $false
            return $false
        }
    } catch {
        Write-Log "Error instalando Extension Pack: $($_.Exception.Message)" "ERROR"
        Write-StepEnd "Instalacion de VirtualBox Extension Pack" $false
        return $false
    }
}
#endregion

#region Configuration Functions
function Add-VBoxManageToPath {
    [CmdletBinding()]
    param()

    Write-StepBegin "Configuracion de PATH para VBoxManage"

    $vboxDir = $Script:Config.VirtualBox.InstallPath

    if (-not (Test-Path $vboxDir)) {
        Write-Log "Directorio de VirtualBox no encontrado: $vboxDir" "ERROR"
        Write-StepEnd "Configuracion de PATH para VBoxManage" $false
        return $false
    }

    if (Test-PathInEnvironment $vboxDir) {
        Write-Host $Script:Messages.PathExists -ForegroundColor $Script:Colors.Success
        Write-StepEnd "Configuracion de PATH para VBoxManage" $true
        return $true
    }

    try {
        Write-Progress "Agregando VirtualBox al PATH del sistema"
        $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $newPath = "$currentPath;$vboxDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)

        Write-Host $Script:Messages.PathAdded -ForegroundColor $Script:Colors.Success
        Write-StepEnd "Configuracion de PATH para VBoxManage" $true
        return $true
    } catch {
        Write-Log "Error configurando PATH: $($_.Exception.Message)" "ERROR"
        Write-Host $Script:Messages.PathFailed -ForegroundColor $Script:Colors.Error
        Write-StepEnd "Configuracion de PATH para VBoxManage" $false
        return $false
    }
}

function Update-CurrentEnvironment {
    [CmdletBinding()]
    param()

    Write-Progress "Actualizando variables de entorno en sesion actual"

    try {
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:PATH = $machinePath + ";" + $userPath

        Write-Log "Variables de entorno actualizadas en sesion actual" "SUCCESS"
        return $true
    } catch {
        Write-Log "Error actualizando variables de entorno: $($_.Exception.Message)" "WARN"
        return $false
    }
}
#endregion

#region Verification Functions
function Test-VBoxManageCommand {
    [CmdletBinding()]
    param()

    Write-Progress "Verificando comando VBoxManage"

    try {
        $vboxVersion = & VBoxManage --version 2>$null
        if ($vboxVersion -and $LASTEXITCODE -eq 0) {
            Write-Host "VBoxManage esta funcionando correctamente" -ForegroundColor $Script:Colors.Success
            Write-Host "Version: $vboxVersion" -ForegroundColor $Script:Colors.Primary
            return $true
        }
    } catch {
        Write-Log "Error verificando VBoxManage: $($_.Exception.Message)" "WARN"
    }

    Write-Log "VBoxManage no esta disponible en la sesion actual" "WARN"
    return $false
}

function Invoke-CompleteVerification {
    [CmdletBinding()]
    param()

    Write-StepBegin "Verificacion completa del sistema"

    Write-Host "Estado de la instalacion:" -ForegroundColor $Script:Colors.Info
    Write-Host ""

    $vcppStatus = Test-VisualCppInstalled
    $vcppColor = if ($vcppStatus) { $Script:Colors.Success } else { $Script:Colors.Error }
    $vcppText = if ($vcppStatus) { "Instalado" } else { "No encontrado" }
    Write-Host "Microsoft Visual C++ 2015-2022: $vcppText" -ForegroundColor $vcppColor

    $vboxStatus = Test-VirtualBoxInstalled
    $vboxColor = if ($vboxStatus) { $Script:Colors.Success } else { $Script:Colors.Error }
    $vboxText = if ($vboxStatus) { "Instalado" } else { "No encontrado" }
    Write-Host "VirtualBox: $vboxText" -ForegroundColor $vboxColor

    $extPackStatus = Test-ExtensionPackInstalled
    $extPackColor = if ($extPackStatus) { $Script:Colors.Success } else { $Script:Colors.Error }
    $extPackText = if ($extPackStatus) { "Instalado" } else { "No encontrado" }
    Write-Host "Extension Pack: $extPackText" -ForegroundColor $extPackColor

    $pathStatus = Test-PathInEnvironment $Script:Config.VirtualBox.InstallPath
    $pathColor = if ($pathStatus) { $Script:Colors.Success } else { $Script:Colors.Error }
    $pathText = if ($pathStatus) { "Configurado" } else { "No configurado" }
    Write-Host "PATH configurado: $pathText" -ForegroundColor $pathColor

    Write-Host ""

    Update-CurrentEnvironment | Out-Null
    $cmdStatus = Test-VBoxManageCommand

    $allComponentsOk = $vcppStatus -and $vboxStatus -and $extPackStatus -and $pathStatus

    if ($allComponentsOk -and $cmdStatus) {
        Write-Host "VERIFICACION EXITOSA: Todos los componentes instalados y funcionando" -ForegroundColor $Script:Colors.Success
        Write-StepEnd "Verificacion completa del sistema" $true
    } elseif ($allComponentsOk) {
        Write-Host "VERIFICACION PARCIAL: Componentes instalados, VBoxManage disponible tras reiniciar terminal" -ForegroundColor $Script:Colors.Warning
        Write-StepEnd "Verificacion completa del sistema" $true
    } else {
        Write-Host "VERIFICACION FALLIDA: Algunos componentes no estan instalados correctamente" -ForegroundColor $Script:Colors.Error
        Write-StepEnd "Verificacion completa del sistema" $false
    }

    return $allComponentsOk
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
        Separator = "=" * 50
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

    Write-Progress "Consultando estado de Visual C++"
    $vcppStatus = Test-VisualCppInstalled

    Write-Progress "Consultando estado de VirtualBox"
    $vboxStatus = Test-VirtualBoxInstalled

    Write-Progress "Consultando estado de Extension Pack"
    $extPackStatus = Test-ExtensionPackInstalled

    Write-Progress "Verificando configuracion de PATH"
    $pathStatus = Test-PathInEnvironment $Script:Config.VirtualBox.InstallPath

    $report = @{
        VisualCppInstalled = $vcppStatus
        VirtualBoxInstalled = $vboxStatus
        ExtensionPackInstalled = $extPackStatus
        PathConfigured = $pathStatus
        IsOperational = $vboxStatus -and $pathStatus
        AllComponentsOk = $vcppStatus -and $vboxStatus -and $extPackStatus -and $pathStatus
    }

    Write-Log "Reporte generado - VC++: $vcppStatus, VBox: $vboxStatus, ExtPack: $extPackStatus, Path: $pathStatus" "INFO"
    Write-StepEnd "Generacion de reporte de estado" $true

    return $report
}
#endregion

#region IO Operations - Menu Display
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

    $vcppColor = if ($Status.VisualCppInstalled) { $Script:Colors.Success } else { $Script:Colors.Error }
    $vcppText = if ($Status.VisualCppInstalled) { "Instalado" } else { "No encontrado" }
    Write-Host "Microsoft Visual C++ 2015-2022: $vcppText" -ForegroundColor $vcppColor

    $vboxColor = if ($Status.VirtualBoxInstalled) { $Script:Colors.Success } else { $Script:Colors.Error }
    $vboxText = if ($Status.VirtualBoxInstalled) { "Instalado" } else { "No encontrado" }
    Write-Host "VirtualBox: $vboxText" -ForegroundColor $vboxColor

    $extPackColor = if ($Status.ExtensionPackInstalled) { $Script:Colors.Success } else { $Script:Colors.Error }
    $extPackText = if ($Status.ExtensionPackInstalled) { "Instalado" } else { "No encontrado" }
    Write-Host "Extension Pack: $extPackText" -ForegroundColor $extPackColor

    $pathColor = if ($Status.PathConfigured) { $Script:Colors.Success } else { $Script:Colors.Error }
    $pathText = if ($Status.PathConfigured) { "Configurado" } else { "No configurado" }
    Write-Host "PATH configurado: $pathText" -ForegroundColor $pathColor

    Write-Host ""

    Write-Progress "Verificando funcionamiento de VBoxManage"
    Update-CurrentEnvironment | Out-Null
    $cmdStatus = Test-VBoxManageCommand

    if ($Status.AllComponentsOk -and $cmdStatus) {
        Write-Host "ESTADO GENERAL: Sistema completamente operativo" -ForegroundColor $Script:Colors.Success
    } elseif ($Status.AllComponentsOk) {
        Write-Host "ESTADO GENERAL: Componentes instalados, reinicie terminal para usar VBoxManage" -ForegroundColor $Script:Colors.Warning
    } else {
        Write-Host "ESTADO GENERAL: Instalacion incompleta" -ForegroundColor $Script:Colors.Error
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
#endregion

#region Business Logic
function Invoke-CompleteInstallation {
    [CmdletBinding()]
    param()

    Write-StepBegin "Proceso completo de instalacion"
    Write-Host "Ejecutando instalacion completa de VirtualBox..." -ForegroundColor $Script:Colors.Accent

    $vcppSuccess = Install-VisualCppRedistributable
    if (-not $vcppSuccess) {
        Write-Log "Fallo critico: No se pudo instalar Visual C++ Redistributable" "ERROR"
        Write-StepEnd "Proceso completo de instalacion" $false
        return $false
    }

    $vboxSuccess = Install-VirtualBox
    if (-not $vboxSuccess) {
        Write-Log "Fallo critico: No se pudo instalar VirtualBox" "ERROR"
        Write-StepEnd "Proceso completo de instalacion" $false
        return $false
    }

    $extPackSuccess = Install-ExtensionPack
    if (-not $extPackSuccess) {
        Write-Log "Advertencia: Extension Pack no se pudo instalar" "WARN"
    }

    Write-Host ""
    Write-Host "Instalacion completada!" -ForegroundColor $Script:Colors.Success
    Write-StepEnd "Proceso completo de instalacion" $true
    return $true
}

function Invoke-CompleteConfiguration {
    [CmdletBinding()]
    param()

    Write-StepBegin "Configuracion completa del sistema"

    if (-not (Test-VirtualBoxInstalled)) {
        Write-Log "VirtualBox no esta instalado. Ejecute la instalacion primero." "ERROR"
        Write-StepEnd "Configuracion completa del sistema" $false
        return $false
    }

    $pathSuccess = Add-VBoxManageToPath
    if (-not $pathSuccess) {
        Write-StepEnd "Configuracion completa del sistema" $false
        return $false
    }

    Write-Host ""
    Write-Host "Configuracion completada!" -ForegroundColor $Script:Colors.Success
    Write-StepEnd "Configuracion completa del sistema" $true
    return $true
}

function Invoke-CompleteProcess {
    [CmdletBinding()]
    param()

    Write-StepBegin "Proceso completo: Instalacion y Configuracion"
    Write-Host "Ejecutando proceso completo..." -ForegroundColor $Script:Colors.Accent

    $installSuccess = Invoke-CompleteInstallation
    if (-not $installSuccess) {
        Write-StepEnd "Proceso completo: Instalacion y Configuracion" $false
        return $false
    }

    $configSuccess = Invoke-CompleteConfiguration
    if (-not $configSuccess) {
        Write-StepEnd "Proceso completo: Instalacion y Configuracion" $false
        return $false
    }

    Write-Host ""
    Write-Host "PROCESO COMPLETO FINALIZADO EXITOSAMENTE!" -ForegroundColor $Script:Colors.Success
    Write-Host "VirtualBox esta listo para usar." -ForegroundColor $Script:Colors.Success
    Write-StepEnd "Proceso completo: Instalacion y Configuracion" $true
    return $true
}
#endregion

#region Menu Systems
function Show-MainMenu {
    [CmdletBinding()]
    param()

    $header = New-MenuHeader "INSTALADOR VIRTUALBOX v7.1.8"
    $options = @(
        New-MenuOption "1" "Instalar componentes" $Script:Colors.Success
        New-MenuOption "2" "Configurar sistema" $Script:Colors.Warning
        New-MenuOption "3" "Verificar instalacion" $Script:Colors.Info
        New-MenuOption "4" "Proceso completo (Instalar + Configurar)" $Script:Colors.Accent
        New-MenuOption "5" "Salir" $Script:Colors.Error
    )

    Write-MenuHeader $header
    Write-MenuOptions $options
}

function Show-InstallMenu {
    [CmdletBinding()]
    param()

    $header = New-MenuHeader "INSTALACION DE COMPONENTES" $Script:Colors.Success
    $options = @(
        New-MenuOption "1" "Instalar Microsoft Visual C++ 2015-2022" $Script:Colors.Success
        New-MenuOption "2" "Instalar VirtualBox $($Script:Config.VirtualBox.Version)" $Script:Colors.Success
        New-MenuOption "3" "Instalar VirtualBox Extension Pack" $Script:Colors.Success
        New-MenuOption "4" "Instalar todos los componentes" $Script:Colors.Accent
        New-MenuOption "5" "Volver al menu principal" $Script:Colors.Error
    )

    Write-MenuHeader $header
    Write-MenuOptions $options
}

function Show-ConfigureMenu {
    [CmdletBinding()]
    param()

    $header = New-MenuHeader "CONFIGURACION DEL SISTEMA" $Script:Colors.Warning
    $options = @(
        New-MenuOption "1" "Configurar PATH para VBoxManage" $Script:Colors.Warning
        New-MenuOption "2" "Verificar y reparar PATH existente" $Script:Colors.Info
        New-MenuOption "3" "Actualizar variables de entorno de sesion" $Script:Colors.Info
        New-MenuOption "4" "Volver al menu principal" $Script:Colors.Error
    )

    Write-MenuHeader $header
    Write-MenuOptions $options
}

function Show-VerifyMenu {
    [CmdletBinding()]
    param()

    $header = New-MenuHeader "VERIFICACION DE INSTALACION" $Script:Colors.Info
    $options = @(
        New-MenuOption "1" "Reporte completo del sistema" $Script:Colors.Info
        New-MenuOption "2" "Verificar solo Visual C++" $Script:Colors.Secondary
        New-MenuOption "3" "Verificar solo VirtualBox" $Script:Colors.Secondary
        New-MenuOption "4" "Verificar solo Extension Pack" $Script:Colors.Secondary
        New-MenuOption "5" "Probar funcionamiento de VBoxManage" $Script:Colors.Accent
        New-MenuOption "6" "Volver al menu principal" $Script:Colors.Error
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
            do {
                Show-InstallMenu
                $installChoice = Read-Host
                $continue = Invoke-InstallMenuChoice $installChoice
            } while ($continue)
        }

        "2" {
            do {
                Show-ConfigureMenu
                $configChoice = Read-Host
                $continue = Invoke-ConfigureMenuChoice $configChoice
            } while ($continue)
        }

        "3" {
            do {
                Show-VerifyMenu
                $verifyChoice = Read-Host
                $continue = Invoke-VerifyMenuChoice $verifyChoice
            } while ($continue)
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

function Invoke-InstallMenuChoice {
    [CmdletBinding()]
    param([string]$Choice)

    Write-Log "Usuario selecciono opcion instalacion: $Choice" "INFO"

    switch ($Choice) {
        "1" {
            Write-Host ""
            Install-VisualCppRedistributable | Out-Null
            Wait-UserInput
            return $true
        }

        "2" {
            Write-Host ""
            Install-VirtualBox | Out-Null
            Wait-UserInput
            return $true
        }

        "3" {
            Write-Host ""
            Install-ExtensionPack | Out-Null
            Wait-UserInput
            return $true
        }

        "4" {
            Write-Host ""
            Invoke-CompleteInstallation | Out-Null
            Wait-UserInput
            return $true
        }

        "5" {
            Write-Log "Usuario regresa al menu principal desde instalacion" "INFO"
            return $false
        }

        default {
            Write-Log "Opcion instalacion invalida seleccionada: $Choice" "WARN"
            Write-Host "Opcion invalida. Presiona cualquier tecla para continuar..." -ForegroundColor $Script:Colors.Error
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $true
        }
    }
}

function Invoke-ConfigureMenuChoice {
    [CmdletBinding()]
    param([string]$Choice)

    Write-Log "Usuario selecciono opcion configuracion: $Choice" "INFO"

    switch ($Choice) {
        "1" {
            Write-Host ""
            Add-VBoxManageToPath | Out-Null
            Wait-UserInput
            return $true
        }

        "2" {
            Write-Host ""
            Write-StepBegin "Verificacion y reparacion de PATH"

            if (Test-PathInEnvironment $Script:Config.VirtualBox.InstallPath) {
                Write-Host "PATH ya esta configurado correctamente" -ForegroundColor $Script:Colors.Success
                Update-CurrentEnvironment | Out-Null
                Test-VBoxManageCommand | Out-Null
            } else {
                Write-Host "PATH no configurado, procediendo a configurar..." -ForegroundColor $Script:Colors.Warning
                Add-VBoxManageToPath | Out-Null
            }

            Write-StepEnd "Verificacion y reparacion de PATH" $true
            Wait-UserInput
            return $true
        }

        "3" {
            Write-Host ""
            Write-StepBegin "Actualizacion de variables de entorno"

            if (Update-CurrentEnvironment) {
                Write-Host "Variables de entorno actualizadas en sesion actual" -ForegroundColor $Script:Colors.Success
                Test-VBoxManageCommand | Out-Null
            }

            Write-StepEnd "Actualizacion de variables de entorno" $true
            Wait-UserInput
            return $true
        }

        "4" {
            Write-Log "Usuario regresa al menu principal desde configuracion" "INFO"
            return $false
        }

        default {
            Write-Log "Opcion configuracion invalida seleccionada: $Choice" "WARN"
            Write-Host "Opcion invalida. Presiona cualquier tecla para continuar..." -ForegroundColor $Script:Colors.Error
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $true
        }
    }
}

function Invoke-VerifyMenuChoice {
    [CmdletBinding()]
    param([string]$Choice)

    Write-Log "Usuario selecciono opcion verificacion: $Choice" "INFO"

    switch ($Choice) {
        "1" {
            Write-Host ""
            $status = New-StatusReport
            Write-StatusReport $status
            Wait-UserInput
            return $true
        }

        "2" {
            Write-Host ""
            Write-StepBegin "Verificacion de Microsoft Visual C++"

            if (Test-VisualCppInstalled) {
                Write-Host "Microsoft Visual C++ 2015-2022 esta instalado correctamente" -ForegroundColor $Script:Colors.Success
            } else {
                Write-Host "Microsoft Visual C++ 2015-2022 no esta instalado" -ForegroundColor $Script:Colors.Error
                Write-Host "ACCION REQUERIDA: Ejecutar instalacion desde el menu principal" -ForegroundColor $Script:Colors.Warning
            }

            Write-StepEnd "Verificacion de Microsoft Visual C++" $true
            Wait-UserInput
            return $true
        }

        "3" {
            Write-Host ""
            Write-StepBegin "Verificacion de VirtualBox"

            if (Test-VirtualBoxInstalled) {
                $vboxPath = Join-Path $Script:Config.VirtualBox.InstallPath $Script:Config.VirtualBox.ExecutableName
                $version = & $vboxPath --version 2>$null
                Write-Host "VirtualBox esta instalado correctamente" -ForegroundColor $Script:Colors.Success
                Write-Host "Version: $version" -ForegroundColor $Script:Colors.Primary
                Write-Host "Ubicacion: $($Script:Config.VirtualBox.InstallPath)" -ForegroundColor $Script:Colors.Secondary
            } else {
                Write-Host "VirtualBox no esta instalado" -ForegroundColor $Script:Colors.Error
                Write-Host "ACCION REQUERIDA: Ejecutar instalacion desde el menu principal" -ForegroundColor $Script:Colors.Warning
            }

            Write-StepEnd "Verificacion de VirtualBox" $true
            Wait-UserInput
            return $true
        }

        "4" {
            Write-Host ""
            Write-StepBegin "Verificacion de Extension Pack"

            if (Test-ExtensionPackInstalled) {
                Write-Host "VirtualBox Extension Pack esta instalado correctamente" -ForegroundColor $Script:Colors.Success

                # Mostrar detalles del Extension Pack
                $vboxPath = Join-Path $Script:Config.VirtualBox.InstallPath $Script:Config.VirtualBox.ExecutableName
                try {
                    $extPackInfo = & $vboxPath list extpacks 2>$null
                    Write-Host "Detalles:" -ForegroundColor $Script:Colors.Info
                    Write-Host $extPackInfo -ForegroundColor $Script:Colors.Secondary
                } catch {
                    Write-Host "Extension Pack instalado pero no se pueden obtener detalles" -ForegroundColor $Script:Colors.Warning
                }
            } else {
                Write-Host "VirtualBox Extension Pack no esta instalado" -ForegroundColor $Script:Colors.Error
                Write-Host "ACCION REQUERIDA: Ejecutar instalacion desde el menu principal" -ForegroundColor $Script:Colors.Warning
            }

            Write-StepEnd "Verificacion de Extension Pack" $true
            Wait-UserInput
            return $true
        }

        "5" {
            Write-Host ""
            Write-StepBegin "Prueba de funcionamiento de VBoxManage"

            Update-CurrentEnvironment | Out-Null

            if (Test-VBoxManageCommand) {
                Write-Host ""
                Write-Host "Ejecutando comando de prueba adicional..." -ForegroundColor $Script:Colors.Info
                try {
                    Write-Host "Listado de VMs registradas:" -ForegroundColor $Script:Colors.Info
                    & VBoxManage list vms 2>$null
                    Write-Host ""
                    Write-Host "VBoxManage esta completamente funcional" -ForegroundColor $Script:Colors.Success
                } catch {
                    Write-Host "VBoxManage responde pero hay problemas con comandos avanzados" -ForegroundColor $Script:Colors.Warning
                }
            } else {
                Write-Host "VBoxManage no esta disponible" -ForegroundColor $Script:Colors.Error
                Write-Host "ACCION REQUERIDA: Verificar instalacion y configuracion de PATH" -ForegroundColor $Script:Colors.Warning
            }

            Write-StepEnd "Prueba de funcionamiento de VBoxManage" $true
            Wait-UserInput
            return $true
        }

        "6" {
            Write-Log "Usuario regresa al menu principal desde verificacion" "INFO"
            return $false
        }

        default {
            Write-Log "Opcion verificacion invalida seleccionada: $Choice" "WARN"
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

    # Inicializar sistema de logging
    if (-not (Initialize-LogDirectory)) {
        Write-Host "WARNING: No se pudo inicializar el sistema de logging" -ForegroundColor $Script:Colors.Warning
        Write-Host "El script continuara sin guardar logs en archivo" -ForegroundColor $Script:Colors.Warning
    } else {
        $logPath = Join-Path $Script:Config.Logging.LogDirectory $Script:Config.Logging.LogFileName
        Write-Host "Log del proceso guardandose en: $logPath" -ForegroundColor $Script:Colors.Info
    }

    Write-Log "=== INICIANDO INSTALADOR VIRTUALBOX ===" "INFO"
    Write-Log "Script ejecutado desde: $PSScriptRoot" "INFO"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
    Write-Log "Sistema Operativo: $([System.Environment]::OSVersion.VersionString)" "INFO"
    Write-Log "Usuario: $env:USERNAME en $env:USERDOMAIN" "INFO"

    Invoke-ExecutionPolicyCheck
    Invoke-AdminCheck

    Write-Log "Verificaciones preliminares completadas exitosamente" "SUCCESS"

    if ($All) {
        Write-Log "Modo automatico: Ejecutando proceso completo" "INFO"
        Invoke-CompleteProcess | Out-Null
    } elseif ($Install) {
        Write-Log "Modo automatico: Ejecutando instalacion completa" "INFO"
        Invoke-CompleteInstallation | Out-Null
    } elseif ($Configure) {
        Write-Log "Modo automatico: Ejecutando configuracion" "INFO"
        Invoke-CompleteConfiguration | Out-Null
    } elseif ($Verify) {
        Write-Log "Modo automatico: Ejecutando verificacion" "INFO"
        Invoke-CompleteVerification | Out-Null
    } else {
        Write-Log "Iniciando modo interactivo" "INFO"
        do {
            Show-MainMenu
            $choice = Read-Host
            Invoke-MainMenuChoice $choice
        } while ($true)
    }

    Wait-UserInput
}

# Entry Point - Verificaciones inmediatas
Write-Log "Script iniciado desde: $PSScriptRoot" "INFO"
Write-Log "Archivo de script: $MyInvocation.MyCommand.Name" "INFO"

if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Log "ADVERTENCIA: PowerShell version antigua detectada" "WARN"
    Write-Host "WARNING: PowerShell $($PSVersionTable.PSVersion) detectado" -ForegroundColor Yellow
    Write-Host "Se recomienda PowerShell 5.1 o superior para mejor compatibilidad" -ForegroundColor Yellow
    Write-Host ""
}

Start-Application
#endregion