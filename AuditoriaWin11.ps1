<#
.SYNOPSIS
    Script de Auditoría de Seguridad Básica para Windows 11 (Solo Lectura)
.DESCRIPTION
    Este script audita configuraciones críticas de seguridad sin realizar cambios.
    Verifica: Firewall, BitLocker, Windows Defender, UAC y Políticas de Contraseña.
.NOTES
    Requiere ejecutar como Administrador para leer ciertos estados (BitLocker/Registro).
#>

# --- 1. Verificación de Privilegios ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Este script requiere permisos de ADMINISTRADOR para leer el estado de BitLocker y el Registro."
    Write-Warning "Por favor, cierra y vuelve a ejecutar como Administrador."
    Pause
    Exit
}

# --- 2. Interactividad: Datos de la Auditoría ---
Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   AUDITOR DE SEGURIDAD WINDOWS 11 (READ-ONLY)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$auditor = Read-Host "1. Ingrese el nombre del auditor"
$computerName = $env:COMPUTERNAME
$date = Get-Date -Format "yyyy-MM-dd HH:mm"

Write-Host ""
Write-Host "Iniciando auditoría para el equipo: $computerName" -ForegroundColor Yellow
Write-Host "Auditor: $auditor" -ForegroundColor Yellow
Write-Host "Fecha: $date" -ForegroundColor Yellow
Write-Host "---------------------------------------------"
Start-Sleep -Seconds 2

# Lista para guardar resultados
$reporte = @()

# Función auxiliar para registrar y mostrar resultados
function Registrar-Resultado {
    param (
        [string]$Area,
        [string]$Prueba,
        [string]$Estado,
        [string]$Detalle
    )
    
    $color = "Green"
    if ($Estado -eq "FAIL") { $color = "Red" }
    if ($Estado -eq "WARN") { $color = "Yellow" }

    Write-Host "[$Area] $Prueba : " -NoNewline
    Write-Host "$Estado" -ForegroundColor $color
    if ($Detalle) { Write-Host "    -> $Detalle" -ForegroundColor Gray }

    $obj = [PSCustomObject]@{
        Area    = $Area
        Prueba  = $Prueba
        Estado  = $Estado
        Detalle = $Detalle
    }
    return $obj
}

# --- 3. Auditoría de Sistema Operativo ---
# Versión de Windows
$osInfo = Get-CimInstance Win32_OperatingSystem
$reporte += Registrar-Resultado "SISTEMA" "Versión OS" "INFO" $osInfo.Caption

# --- 4. Auditoría de Firewall ---
$firewalls = Get-NetFirewallProfile
foreach ($fw in $firewalls) {
    $status = if ($fw.Enabled -eq $true) { "PASS" } else { "FAIL" }
    $reporte += Registrar-Resultado "FIREWALL" "Perfil $($fw.Name)" $status "Habilitado: $($fw.Enabled)"
}

# --- 5. Auditoría de Antivirus (Windows Defender) ---
try {
    $defender = Get-MpComputerStatus
    $avStatus = if ($defender.AntivirusEnabled -eq $true -and $defender.RealTimeProtectionEnabled -eq $true) { "PASS" } else { "FAIL" }
    $reporte += Registrar-Resultado "DEFENDER" "Protección en Tiempo Real" $avStatus "Antivirus activo"
} catch {
    $reporte += Registrar-Resultado "DEFENDER" "Estado" "WARN" "No se pudo leer el estado de Defender (¿Quizás usa un AV de terceros?)"
}

# --- 6. Auditoría de BitLocker (Cifrado de Disco) ---
try {
    $bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    $blStatus = if ($bitlocker.ProtectionStatus -eq "On") { "PASS" } else { "FAIL" }
    $reporte += Registrar-Resultado "ENCRIPTACION" "BitLocker (Disco C:)" $blStatus "Estado: $($bitlocker.ProtectionStatus)"
} catch {
    $reporte += Registrar-Resultado "ENCRIPTACION" "BitLocker" "WARN" "No se pudo verificar (¿TPM habilitado?)"
}

# --- 7. Auditoría de UAC (User Account Control) ---
# Verifica si el UAC está activo en el registro
$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uacValue = Get-ItemProperty -Path $uacPath -Name "EnableLUA" -ErrorAction SilentlyContinue

if ($uacValue.EnableLUA -eq 1) {
    $reporte += Registrar-Resultado "SEGURIDAD" "UAC (Control de Cuentas)" "PASS" "Está habilitado"
} else {
    $reporte += Registrar-Resultado "SEGURIDAD" "UAC (Control de Cuentas)" "FAIL" "Está deshabilitado (Riesgo Alto)"
}

# --- 8. Auditoría de Usuarios (Cuenta Invitado) ---
$guestAccount = Get-LocalUser -Name "Invitado" -ErrorAction SilentlyContinue
if ($guestAccount) {
    $guestStatus = if ($guestAccount.Enabled -eq $false) { "PASS" } else { "FAIL" }
    $reporte += Registrar-Resultado "USUARIOS" "Cuenta Invitado Desactivada" $guestStatus "Estado actual: Enabled = $($guestAccount.Enabled)"
}

# --- 9. Verificación Rápida de Políticas de Contraseña (Local) ---
# Usamos net accounts porque funciona mejor en máquinas fuera de dominio para lectura rápida
$netAccounts = net accounts
$longitudMinima = ($netAccounts | Select-String "Longitud mínima").ToString() -replace "[^0-9]", ""

if ([int]$longitudMinima -ge 8) {
    $passStatus = "PASS"
} elseif ([int]$longitudMinima -gt 0) {
    $passStatus = "WARN"
} else {
    $passStatus = "FAIL"
}
$reporte += Registrar-Resultado "PASSWORD" "Longitud Mínima" $passStatus "Configurado en: $longitudMinima caracteres"

# --- Fin del Reporte ---
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   RESUMEN DE AUDITORÍA" -ForegroundColor Cyan
Write-Host "============================================="
Write-Host "Total Pruebas: $($reporte.Count)"
Write-Host "Aprobadas (PASS): $(($reporte | Where-Object {$_.Estado -eq 'PASS'}).Count)" -ForegroundColor Green
Write-Host "Fallidas (FAIL):  $(($reporte | Where-Object {$_.Estado -eq 'FAIL'}).Count)" -ForegroundColor Red
Write-Host ""

# Opción interactiva para exportar
$exportar = Read-Host "¿Desea exportar el reporte a un archivo CSV en el escritorio? (S/N)"
if ($exportar -eq "S" -or $exportar -eq "s") {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $outputPath = "$desktopPath\Auditoria_Win11_$computerName.csv"
    $reporte | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Reporte guardado en: $outputPath" -ForegroundColor Green
}

Write-Host "Presione Enter para salir..."
Read-Host