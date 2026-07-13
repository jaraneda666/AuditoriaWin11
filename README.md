# 🛡️ AuditoriaWin11 — Script de Auditoría de Seguridad para Windows 11

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![Windows 11](https://img.shields.io/badge/OS-Windows%2011-0078D4?logo=windows)](https://www.microsoft.com/windows/windows-11)
[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)
[![Solo Lectura](https://img.shields.io/badge/Modo-Solo%20Lectura-green)](#)

---

## 📋 Descripción

**AuditoriaWin11.ps1** es un script de PowerShell diseñado para realizar una **auditoría de seguridad básica** sobre estaciones de trabajo con Windows 11, operando en modo **solo lectura** (no realiza ningún cambio en el sistema). Está orientado a analistas de seguridad, administradores de sistemas y auditores que necesitan obtener un diagnóstico rápido del estado de seguridad de un equipo.

El script verifica las siguientes áreas críticas de seguridad:

| Área                    | Descripción                                                        |
|-------------------------|--------------------------------------------------------------------|
| 🖥️ Sistema Operativo    | Versión y edición de Windows instalada                             |
| 🔥 Firewall             | Estado de todos los perfiles de Firewall (Domain, Private, Public) |
| 🛡️ Windows Defender     | Estado del antivirus y la protección en tiempo real                |
| 🔒 BitLocker            | Estado del cifrado del disco C:                                    |
| 👤 UAC                  | Estado del Control de Cuentas de Usuario                           |
| 👥 Usuarios Locales     | Verificación de la cuenta "Invitado" (debería estar desactivada)   |
| 🔑 Política de Contraseñas | Longitud mínima configurada para las contraseñas locales        |

Al finalizar, presenta un **resumen ejecutivo** con el total de pruebas, aprobadas (PASS) y fallidas (FAIL), y ofrece la opción de **exportar el informe a un archivo CSV**.

---

## ⚙️ Requisitos

| Requisito       | Detalle                                                                 |
|-----------------|-------------------------------------------------------------------------|
| Sistema Operativo | Windows 11 (compatible con Windows 10 en la mayoría de verificaciones) |
| PowerShell      | Versión 5.1 o superior (incluida por defecto en Windows 11)             |
| Privilegios     | ⚠️ **Administrador** — requerido para leer BitLocker y el Registro      |

---

## 🚀 Uso

### Paso 1 — Obtener el script

```powershell
git clone https://github.com/tu-usuario/AuditoriaWin11.git
cd AuditoriaWin11
```

O descarga directamente el archivo `AuditoriaWin11.ps1`.

### Paso 2 — Abrir PowerShell como Administrador

Clic derecho en el menú Inicio → **Windows PowerShell (Administrador)** o **Terminal (Administrador)**.

### Paso 3 — Habilitar la ejecución (si es necesario)

En algunos entornos puede ser necesario ajustar la política de ejecución de forma temporal:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

> ⚠️ Esto aplica solo a la sesión actual y no modifica la política global del sistema.

### Paso 4 — Ejecutar el script

```powershell
.\AuditoriaWin11.ps1
```

### Paso 5 — Seguir los pasos interactivos

1. El script solicita el **nombre del auditor**.
2. Muestra en tiempo real el resultado de cada verificación con código de color:
   - 🟢 **PASS** — Configuración correcta y segura.
   - 🔴 **FAIL** — Configuración que representa un riesgo de seguridad.
   - 🟡 **WARN** — No se pudo verificar o requiere atención adicional.
3. Al finalizar, pregunta si se desea **exportar el reporte a CSV** en el Escritorio.

---

## 📊 Ejemplo de Salida en Consola

```
=============================================
   AUDITOR DE SEGURIDAD WINDOWS 11 (READ-ONLY)
=============================================

1. Ingrese el nombre del auditor: Juan Pérez

Iniciando auditoría para el equipo: DESKTOP-ABC123
Auditor: Juan Pérez
Fecha: 2025-07-13 19:15
---------------------------------------------
[SISTEMA]      Versión OS                    : INFO
    -> Microsoft Windows 11 Pro

[FIREWALL]     Perfil Domain                 : PASS
    -> Habilitado: True
[FIREWALL]     Perfil Private                : PASS
    -> Habilitado: True
[FIREWALL]     Perfil Public                 : PASS
    -> Habilitado: True

[DEFENDER]     Protección en Tiempo Real     : PASS
    -> Antivirus activo

[ENCRIPTACION] BitLocker (Disco C:)          : FAIL
    -> Estado: Off

[SEGURIDAD]    UAC (Control de Cuentas)      : PASS
    -> Está habilitado

[USUARIOS]     Cuenta Invitado Desactivada   : PASS
    -> Estado actual: Enabled = False

[PASSWORD]     Longitud Mínima               : WARN
    -> Configurado en: 0 caracteres

=============================================
   RESUMEN DE AUDITORÍA
=============================================
Total Pruebas : 8
Aprobadas (PASS): 6
Fallidas (FAIL):  1

¿Desea exportar el reporte a un archivo CSV en el escritorio? (S/N): S
Reporte guardado en: C:\Users\JuanPerez\Desktop\Auditoria_Win11_DESKTOP-ABC123.csv
```

---

## 📄 Formato del Reporte CSV

El archivo exportado (`Auditoria_Win11_<NOMBRE_EQUIPO>.csv`) contiene las siguientes columnas:

| Columna   | Descripción                                              |
|-----------|----------------------------------------------------------|
| `Area`    | Categoría de la prueba (FIREWALL, DEFENDER, etc.)        |
| `Prueba`  | Nombre descriptivo de la verificación realizada          |
| `Estado`  | Resultado: `PASS`, `FAIL` o `WARN`                       |
| `Detalle` | Información adicional sobre el resultado obtenido        |

El archivo se guarda en el **Escritorio** del usuario con el nombre:
```
Auditoria_Win11_<NOMBRE_DEL_EQUIPO>.csv
```

---

## 🔐 Seguridad y Privacidad

- Opera **estrictamente en modo lectura** — no modifica ninguna configuración del sistema.
- No envía datos por red ni se conecta a servicios externos.
- El reporte CSV se guarda únicamente en el Escritorio local del usuario que lo ejecuta.
- No almacena contraseñas ni información sensible de autenticación.

---

## 🗂️ Estructura del Repositorio

```
AuditoriaWin11/
├── AuditoriaWin11.ps1    # Script principal de auditoría
├── README.md             # Descripción y guía de uso
└── implementacion.md     # Detalle técnico de la implementación
```

---

## 📌 Casos de Uso

- Auditorías de cumplimiento básico en endpoints corporativos.
- Revisión de postura de seguridad antes de incorporar un equipo a la red corporativa.
- Verificaciones periódicas en equipos de usuarios con privilegios elevados.
- Formación y práctica en seguridad defensiva (Blue Team).
- Punto de partida para scripts de auditoría más avanzados.

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas:

1. Haz un fork del repositorio.
2. Crea una rama: `git checkout -b feature/nueva-verificacion`
3. Realiza tus cambios y haz commit: `git commit -m 'feat: agrega verificación de X'`
4. Envía un Pull Request describiendo el cambio propuesto.

---

## 📝 Licencia

Este proyecto está bajo la Licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

> **⚠️ Aviso:** Este script es una herramienta de diagnóstico rápido con fines educativos y de apoyo. Para auditorías de seguridad formales y completas, se recomienda complementarlo con herramientas especializadas como **Microsoft Security Compliance Toolkit**, **CIS-CAT Pro** o soluciones **SIEM/EDR** corporativas.
