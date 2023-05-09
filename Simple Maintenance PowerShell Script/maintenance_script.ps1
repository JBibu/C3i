# Variables
$separator = " "

# Función de ejecución de .vbs
function Invoke-VBSScript {
    Write-Host "Ejecutando GLPI_Agent.vbs..."
    Write-Host $separator
    # Start the script process
    $process = Start-Process -FilePath "$PSScriptRoot\GLPI_Agent.vbs" -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Write-Output "GLPI_Agent.vbs ejecutado correctamente."}
    else {
        Write-Output "Error al ejecutar GLPI_Agent.vbs. Código de salida: $($process.ExitCode)"
    }
    Write-Host $separator
}

# Función de limpieza de archivos temporales
#TODO ESTO LO HE HECHO YO - ARREGLALO
function Clear-JunkFiles {
    Write-Host "Limpiando archivos temporales..."
    Write-Host $separator
    # Limpia los archivos temporales del usuario actual y del sistema
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Archivos temporales eliminados."
    Write-Host $separator
}

# Función para optimizar discos
function Optimize-Disks {
    Write-Host "Optimizando discos..."
    Write-Host $separator
    # Optimiza los todos los discos internos del sistema
    Get-CimInstance -Class Win32_LogicalDisk | 
        Where-Object {$_.DriveType -eq 3} | ForEach-Object -Process {
            $driveLetter = $_.DeviceID -replace ":", ""
            Optimize-Volume -DriveLetter $driveLetter -ReTrim -ErrorAction SilentlyContinue
        }
    Write-Output "Discos optimizados."
    Write-Host $separator
}

# Función para mostrar el estado de los discos y SMART
function Show-DiskAndSMARTStatus {
    Write-Host "Comprobando estado de los discos y SMART..."
    Write-Host $separator
    # Estado de los discos
    $diskStatus = Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem,
        @{Label="Size (GB)"; Expression={"{0:N2}" -f ($_.Size/1GB)}},
        @{Label="Used Space (GB)"; Expression={"{0:N2}" -f ((Get-PSDrive -PSProvider "FileSystem" -Name $_.DriveLetter).Used/1GB)}},
        @{Label="Free Space (GB)"; Expression={"{0:N2}" -f ((Get-PSDrive -PSProvider "FileSystem" -Name $_.DriveLetter).Free/1GB)}},
        @{Label="DeviceId"; Expression={(Get-Partition -DriveLetter $_.DriveLetter).DiskNumber}}
    # Estado de SMART de los discos
    $smartStatus = Get-PhysicalDisk | Select-Object MediaType, DeviceId, HealthStatus, OperationalStatus,
        @{Label="Size (GB)"; Expression={"{0:N2}" -f ($_.Size/1GB)}},
        BusType, Model
    # Muestra el estado de los discos y SMART
    $diskStatus | Format-Table -AutoSize
    $smartStatus | Format-Table -AutoSize
    Write-Host $separator
}

# Función para mostrar información del sistema
function Show-SystemInfo {
    Write-Host "Recopilando informacion del sistema..."
    Write-Host $separator
    # Información del equipo
    $pcName = (Get-CimInstance -Class Win32_ComputerSystem -Property Name).Name
    Write-Output "Nombre del equipo: $pcName"
    $cpu = (Get-CimInstance -Class Win32_Processor -Property Name).Name
    Write-Output "CPU: $cpu"
    $cpuCores = (Get-CimInstance -Class Win32_Processor -Property NumberOfCores).NumberOfCores
    Write-Output "Nucleos: $cpuCores"
    $logicalCores = (Get-CimInstance -Class Win32_Processor -Property NumberOfLogicalProcessors).NumberOfLogicalProcessors
    Write-Output "Procesadores logicos: $logicalCores"
    $cpuUsage = Get-CimInstance -Class Win32_PerfFormattedData_PerfOS_Processor -Property PercentProcessorTime | Where-Object {$_.Name -notlike "*_Total"} | Measure-Object -Property PercentProcessorTime -Average
    $cpuUsagePercent = "{0:N2}" -f $cpuUsage.Average
    Write-Output "Uso de medio de la CPU: $cpuUsagePercent%"
    $ram = "{0:N2}" -f ((Get-CimInstance -Class Win32_ComputerSystem -Property TotalPhysicalMemory).TotalPhysicalMemory/1GB)
    Write-Output "RAM: $ram GB"
    $ramUsed = "{0:N2}" -f ((Get-Process | Measure-Object -Property WorkingSet -Sum).Sum/1GB)
    Write-Output "RAM en uso: $ramUsed GB"
    $gpu = (Get-CimInstance -Class Win32_VideoController -Property Name).Name -join ", "
    Write-Output "GPU: $gpu"
    # Información de Windows
    $windowsVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    $windowsActivation = (Get-CimInstance -Class SoftwareLicensingService).OA3xOriginalProductKey
    if ($windowsActivation) {
        $windowsStatus = "Activado con una clave de licencia"
        $windowsLicenseKey = $windowsActivation}
    else {
        $windowsActivation = (Get-CimInstance -Class SoftwareLicensingProduct -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f'").OA3xOriginalProductKey
        if ($windowsActivation) {
            $windowsStatus = "Activado con una licencia digital vinculada a una cuenta Microsoft"
            $windowsLicenseKey = "N/A"}
        else {
            $windowsStatus = "No activado"
            $windowsLicenseKey = "N/A"
        }
    }
    Write-Output "Version de Windows: $windowsVersion"
    Write-Output "Estado de activacion de Windows: $windowsStatus"
    Write-Output "Clave de licencia de Windows: $windowsLicenseKey"
    # Información del antivirus
    $antivirus = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct | Select-Object -First 1
    Write-Output "Antivirus: $($antivirus.displayName)"
    Write-Output "Informacion del sistema recopilada."
    Write-Output $separator
}

# Función para mostrar información de la red
function Get-NetworkInfo {
    Write-Host "Recopilando informacion de la red..."
    Write-Host $separator
    # Información de la red
    $ipsAndMacs = Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress, `
        @{Name="MacAddress";Expression={(Get-NetAdapter -InterfaceIndex $_.InterfaceIndex).MacAddress}} 
    Write-Output "Direcciones IP y MAC:"
    $ipsAndMacs | Format-Table -AutoSize
    # Información de los DNS
    $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object ServerAddresses
    Write-Output "Servidores DNS: $($dnsServers.ServerAddresses)"
    # Información de las impresoras
    try {
        $printers = Get-Printer -ErrorAction Stop | Select-Object Name, DriverName, PortName}
    catch {
        Write-Warning "Ha ocurrido un error: $($_.Exception.Message)"
        $printers = @()
    }
    Write-Output "Impresoras instaladas:"
    if ($printers.Count -gt 0) {
    $printers | Format-Table -AutoSize}
    else {
        Write-Warning "No se han encontrado impresoras."
    }
        Write-Host "Informacion de la red recopilada."
        Write-Host $separator
}

# Función para mostrar los usuarios locales
function Get-LocalUsers {
    Write-Host "Recopilando informacion de los usuarios locales..."
    Write-Host $separator
    # Información de los usuarios locales
    $users = Get-LocalUser
    Write-Output "Usuarios locales:"
    $users | Format-Table -AutoSize
    Write-Host "Informacion de los usuarios locales recopilada."
    Write-Host $separator
}

# Función para actualizar el sistema en segundo plano (Hecha con ChatGPT)
function Update-System {
    # Instalar el módulo PSWindowsUpdate si no está instalado
    if (-not(Get-Module -Name PSWindowsUpdate -ErrorAction SilentlyContinue)) {
        Install-Module -Name PSWindowsUpdate -Force}
    # Comprueba si hay actualizaciones disponibles
    Write-Host "Comprobando actualizaciones de Windows..."
    Write-Host $separator
    $updates = Get-WindowsUpdate -Install -AcceptAll -Verbose -IgnoreReboot
    if ($updates.Count -eq 0) {
        Write-Output "No se han encontrado actualizaciones."
        return}
    # Instala las actualizaciones en segundo plano
    Write-Output "Instalando actualizaciones en segundo plano..."
    Write-Host $separator
    $updates | Install-WindowsUpdate -Verbose -IgnoreReboot -Confirm:$false -WarningAction SilentlyContinue
}

# Función para invocar todas las funciones del script
function Invoke-AllFunctions {
    Write-Host "Invocando todas las funciones..."
    Write-Host $separator
    Invoke-VBSScript | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Clear-JunkFiles | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Optimize-Disks | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Show-DiskAndSMARTStatus | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Show-SystemInfo | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Get-NetworkInfo | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Get-LocalUsers | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Update-System | Tee-Object -FilePath $PSScriptRoot\log.txt -Append
    Write-Host "Se han invocado todas las funciones."
    Write-Host $separator
}

# Opciones del menú
$menuOptions = @{
    1 = "Todo."
    2 = "Instalar GLPI Agent."
    3 = "Limpiar archivos temporales."
    4 = "Optimizar discos."
    5 = "Mostrar estado de los discos y SMART."
    6 = "Mostrar informacion del sistema."
    7 = "Mostrar informacion de la red."
    8 = "Mostrar los usuarios locales."
    9 = "Actualizar el sistema."
    10 = "Salir."
}

# Loop del menú
do {
    # Muestra el menú
    Write-Host "Seleciona una opcion:"
    Write-Host $separator
    $menuOptions.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host "$($_.Name): $($_.Value)"
    }
    # Entrada del usuario
    Write-Host $separator
    $userChoice = Read-Host "Selecciona una opcion (1-10)"
    if ([int]::TryParse($userChoice, [ref]$null) -and $userChoice -ge 0 -and $userChoice -le 9) {
        switch ($userChoice) {
            1 { Invoke-AllFunctions }
            2 { Invoke-VBSScript }
            3 { Clear-JunkFiles }
            4 { Optimize-Disks }
            5 { Show-DiskAndSMARTStatus }
            6 { Show-SystemInfo }
            7 { Get-NetworkInfo }
            8 { Get-LocalUsers }
            9 { Update-System }
            10 { exit }
        }
    }
} while ($true)