# 📐 Implementación Técnica — AuditoriaWin11.ps1

## Descripción General

`AuditoriaWin11.ps1` es un script de PowerShell estructurado en **9 bloques funcionales** secuenciales. Su diseño sigue el principio de **mínimo privilegio de escritura**: verifica el estado del sistema exclusivamente mediante llamadas de lectura a CIM/WMI, cmdlets nativos de Windows y el Registro, sin alterar ninguna configuración.

---

## Arquitectura del Script

```
┌─────────────────────────────────────────────────┐
│             AuditoriaWin11.ps1                  │
│                                                 │
│  [1] Verificación de Privilegios                │
│       └─ Aborta si no es Administrador          │
│                                                 │
│  [2] Interactividad: Datos de la Auditoría      │
│       └─ Captura nombre del auditor             │
│                                                 │
│  [3–9] Módulos de Auditoría (Solo Lectura)      │
│       ├─ [3] Sistema Operativo                  │
│       ├─ [4] Firewall                           │
│       ├─ [5] Windows Defender                   │
│       ├─ [6] BitLocker                          │
│       ├─ [7] UAC                                │
│       ├─ [8] Usuarios Locales                   │
│       └─ [9] Política de Contraseñas            │
│                                                 │
│  [Fin] Resumen + Exportación CSV (opcional)     │
└─────────────────────────────────────────────────┘
```

---

## Detalle de Cada Bloque

---

### Bloque 1 — Verificación de Privilegios

```powershell
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

**Objetivo:** Garantizar que el script se ejecute con permisos de Administrador.

**Mecanismo:**
- Instancia un objeto `WindowsPrincipal` con la identidad del usuario actual.
- Consulta si pertenece al rol `Administrator` usando `IsInRole()`.
- Si no es administrador, muestra una advertencia y termina con `Exit` para evitar errores parciales más adelante (BitLocker y Registro requieren privilegios elevados).

**Criterio de fallo:** Si `$isAdmin` es `$false`, el script aborta inmediatamente.

---

### Bloque 2 — Captura de Metadatos de la Auditoría

```powershell
$auditor      = Read-Host "1. Ingrese el nombre del auditor"
$computerName = $env:COMPUTERNAME
$date         = Get-Date -Format "yyyy-MM-dd HH:mm"
```

**Objetivo:** Personalizar el reporte con datos contextuales.

**Datos recopilados:**
| Variable        | Fuente                     | Uso                         |
|-----------------|----------------------------|-----------------------------|
| `$auditor`      | Entrada del usuario        | Metadato en pantalla        |
| `$computerName` | Variable de entorno del SO | Nombre del archivo CSV      |
| `$date`         | `Get-Date`                 | Metadato de fecha/hora      |

---

### Bloque 3 — Auditoría del Sistema Operativo

```powershell
$osInfo = Get-CimInstance Win32_OperatingSystem
$reporte += Registrar-Resultado "SISTEMA" "Versión OS" "INFO" $osInfo.Caption
```

**Cmdlet usado:** `Get-CimInstance Win32_OperatingSystem`

**Propiedad extraída:** `.Caption` — devuelve la descripción completa del SO, por ejemplo: `Microsoft Windows 11 Pro`.

**Estado asignado:** `INFO` (informativo, no evalúa pase/fallo).

---

### Bloque 4 — Auditoría del Firewall

```powershell
$firewalls = Get-NetFirewallProfile
foreach ($fw in $firewalls) {
    $status = if ($fw.Enabled -eq $true) { "PASS" } else { "FAIL" }
    $reporte += Registrar-Resultado "FIREWALL" "Perfil $($fw.Name)" $status "Habilitado: $($fw.Enabled)"
}
```

**Cmdlet usado:** `Get-NetFirewallProfile`

**Perfiles verificados:** `Domain`, `Private`, `Public`

**Lógica de evaluación:**

| Condición           | Estado |
|---------------------|--------|
| `Enabled = True`    | PASS   |
| `Enabled = False`   | FAIL   |

**Por qué es importante:** Windows 11 expone 3 perfiles de firewall independientes. Un solo perfil desactivado puede representar un vector de ataque en redes específicas.

---

### Bloque 5 — Auditoría de Windows Defender

```powershell
try {
    $defender  = Get-MpComputerStatus
    $avStatus  = if ($defender.AntivirusEnabled -eq $true -and
                     $defender.RealTimeProtectionEnabled -eq $true) { "PASS" } else { "FAIL" }
} catch {
    # Estado WARN si el cmdlet falla (posible AV de terceros)
}
```

**Cmdlet usado:** `Get-MpComputerStatus` (módulo `Defender`)

**Propiedades evaluadas:**

| Propiedad                    | Condición esperada |
|------------------------------|--------------------|
| `AntivirusEnabled`           | `$true`            |
| `RealTimeProtectionEnabled`  | `$true`            |

**Manejo de errores:** Se usa `try/catch` porque el cmdlet puede no estar disponible si el equipo usa un antivirus de terceros que reemplaza a Defender. En ese caso, el estado se registra como `WARN`.

---

### Bloque 6 — Auditoría de BitLocker

```powershell
try {
    $bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    $blStatus  = if ($bitlocker.ProtectionStatus -eq "On") { "PASS" } else { "FAIL" }
} catch {
    # Estado WARN si no se puede verificar (TPM no habilitado, etc.)
}
```

**Cmdlet usado:** `Get-BitLockerVolume` (módulo `BitLocker`)

**Propiedad evaluada:** `ProtectionStatus`

| Valor de `ProtectionStatus` | Estado |
|-----------------------------|--------|
| `On`                        | PASS   |
| `Off`                       | FAIL   |
| Error / No disponible       | WARN   |

**Nota técnica:** Este cmdlet requiere privilegios de Administrador y que el módulo BitLocker esté disponible. En sistemas sin TPM o en ediciones Home de Windows, puede lanzar una excepción que es capturada por `try/catch`.

---

### Bloque 7 — Auditoría de UAC (User Account Control)

```powershell
$uacPath  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uacValue = Get-ItemProperty -Path $uacPath -Name "EnableLUA" -ErrorAction SilentlyContinue

if ($uacValue.EnableLUA -eq 1) { "PASS" } else { "FAIL" }
```

**Fuente de datos:** Registro de Windows — `HKLM:\...\Policies\System`

**Clave evaluada:** `EnableLUA` (DWORD)

| Valor de `EnableLUA` | Significado                  | Estado |
|----------------------|------------------------------|--------|
| `1`                  | UAC habilitado               | PASS   |
| `0` o ausente        | UAC deshabilitado (alto riesgo) | FAIL |

**Por qué usar el Registro:** El Registro es la fuente autoritativa del estado de UAC. Leer esta clave requiere acceso de Administrador al hive `HKLM`.

---

### Bloque 8 — Auditoría de Usuarios Locales (Cuenta Invitado)

```powershell
$guestAccount = Get-LocalUser -Name "Invitado" -ErrorAction SilentlyContinue
if ($guestAccount) {
    $guestStatus = if ($guestAccount.Enabled -eq $false) { "PASS" } else { "FAIL" }
}
```

**Cmdlet usado:** `Get-LocalUser`

**Lógica de evaluación:**

| Condición                      | Estado |
|--------------------------------|--------|
| Cuenta no existe               | (sin resultado — no aplica) |
| `Enabled = False`              | PASS   |
| `Enabled = True`               | FAIL   |

**Nota:** El script busca la cuenta con el nombre localizado `"Invitado"` (español). En sistemas en inglés, el nombre sería `"Guest"`. Este es un punto de mejora potencial mediante la búsqueda por SID en lugar de por nombre.

---

### Bloque 9 — Política de Contraseñas Locales

```powershell
$netAccounts    = net accounts
$longitudMinima = ($netAccounts | Select-String "Longitud mínima").ToString() -replace "[^0-9]", ""

if ([int]$longitudMinima -ge 8)     { $passStatus = "PASS" }
elseif ([int]$longitudMinima -gt 0) { $passStatus = "WARN" }
else                                { $passStatus = "FAIL" }
```

**Herramienta usada:** Comando nativo `net accounts`

**Por qué `net accounts` y no un cmdlet de PowerShell:** En equipos fuera de dominio (workgroup), `net accounts` es más confiable que `Get-ADDefaultDomainPasswordPolicy` (que requiere RSAT y un dominio). El script parsea la salida de texto y extrae solo los dígitos con `-replace "[^0-9]", ""`.

**Umbral de evaluación:**

| Longitud mínima configurada | Estado |
|-----------------------------|--------|
| ≥ 8 caracteres              | PASS   |
| Entre 1 y 7 caracteres      | WARN   |
| 0 (sin política)            | FAIL   |

---

### Función Auxiliar — `Registrar-Resultado`

```powershell
function Registrar-Resultado {
    param ([string]$Area, [string]$Prueba, [string]$Estado, [string]$Detalle)

    $color = "Green"
    if ($Estado -eq "FAIL") { $color = "Red" }
    if ($Estado -eq "WARN") { $color = "Yellow" }

    Write-Host "[$Area] $Prueba : " -NoNewline
    Write-Host "$Estado" -ForegroundColor $color
    if ($Detalle) { Write-Host "    -> $Detalle" -ForegroundColor Gray }

    return [PSCustomObject]@{
        Area    = $Area
        Prueba  = $Prueba
        Estado  = $Estado
        Detalle = $Detalle
    }
}
```

**Propósito:** Centralizar la presentación y el registro de resultados.

**Patrón de diseño:** Actúa como un **logger dual**:
1. **Salida de consola** con colores semánticos (verde/rojo/amarillo).
2. **Retorno de objeto** `PSCustomObject` que se acumula en `$reporte` (array) para la exportación posterior.

---

## Mecanismo de Exportación CSV

```powershell
$reporte | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
```

- **`Export-Csv`**: Serializa el array de `PSCustomObject` a formato CSV.
- **`-NoTypeInformation`**: Omite la primera línea con metadata de tipo de PowerShell.
- **`-Encoding UTF8`**: Garantiza compatibilidad con caracteres especiales (tildes, ñ, etc.).
- El nombre del archivo incluye el hostname del equipo: `Auditoria_Win11_<COMPUTERNAME>.csv`.

---

## Diagrama de Flujo de Ejecución

```
Inicio
  │
  ├─► ¿Es Administrador? ──No──► Advertencia + Exit
  │         │Sí
  │         ▼
  ├─► Capturar: Auditor, Hostname, Fecha
  │         │
  │         ▼
  ├─► [3] OS Info ──────────────────────────► $reporte[]
  ├─► [4] Firewall (3 perfiles) ────────────► $reporte[]
  ├─► [5] Defender (try/catch) ─────────────► $reporte[]
  ├─► [6] BitLocker (try/catch) ────────────► $reporte[]
  ├─► [7] UAC (Registro) ───────────────────► $reporte[]
  ├─► [8] Usuario Invitado ─────────────────► $reporte[]
  └─► [9] Política de Contraseñas ──────────► $reporte[]
              │
              ▼
        Mostrar Resumen (PASS/FAIL/WARN)
              │
              ▼
        ¿Exportar CSV? ──Sí──► Guardar en Escritorio
              │No
              ▼
            Fin
```

---

## Dependencias y Módulos de PowerShell

| Módulo / Herramienta    | Cmdlet / Comando           | Requiere Admin | Disponible en Win 11 |
|-------------------------|----------------------------|:--------------:|:--------------------:|
| `NetSecurity`           | `Get-NetFirewallProfile`   | No             | ✅ Sí                |
| `Defender`              | `Get-MpComputerStatus`     | No             | ✅ Sí (si activo)    |
| `BitLocker`             | `Get-BitLockerVolume`      | ✅ Sí          | ✅ Sí (Pro/Enterprise) |
| `Microsoft.PowerShell.LocalAccounts` | `Get-LocalUser` | No      | ✅ Sí                |
| `CimCmdlets`            | `Get-CimInstance`          | No             | ✅ Sí                |
| `Microsoft.PowerShell.Management` | `Get-ItemProperty` | ✅ Sí   | ✅ Sí                |
| Sistema (CLI)           | `net accounts`             | No             | ✅ Sí                |

---

## Consideraciones de Seguridad del Propio Script

- El script no modifica el sistema en ningún punto.
- No realiza operaciones de red.
- El único artefacto que genera es el CSV local (opcional y bajo consentimiento explícito del usuario).
- Puede ejecutarse de forma segura en entornos de producción.

---

## Posibles Mejoras Futuras

| Mejora                                        | Descripción                                                           |
|-----------------------------------------------|-----------------------------------------------------------------------|
| Soporte multiidioma                           | Buscar cuenta Guest por SID (S-1-5-32-546) en lugar de por nombre    |
| Verificación de actualizaciones pendientes    | Usar `Get-WindowsUpdate` o WUA COM API                                |
| Verificación de servicios críticos            | Comprobar que servicios de seguridad críticos están en ejecución      |
| Exportación a HTML                            | Generar un reporte visual con tabla coloreada                         |
| Integración con GPO                           | Leer políticas de grupo aplicadas via `gpresult /R`                   |
| Modo silencioso / no-interactivo              | Añadir parámetros `-Auditor` y `-Export` para automatización          |
| Verificación de RDP                           | Comprobar si el Escritorio Remoto está habilitado y con NLA           |

---

> **Versión del documento:** 1.0  
> **Última actualización:** Julio 2025
