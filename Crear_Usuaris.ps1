<#
.SYNOPSIS
    Crear_Usuaris.ps1 — Crea els usuaris d'Active Directory d'una seu
    a partir del fitxer Usuaris.csv.

.DESCRIPTION
    REQUISITS:
      - Executar en un Windows Server amb el rol AD DS instal·lat.
      - Executar com a Administrador del domini.
      - Mòdul ActiveDirectory disponible (RSAT).

    QUÈ FA:
      1. Llig el CSV (sense modificar-lo).
      2. Filtra els usuaris de la seu indicada.
      3. Crea l'OU de la seu i una sub-OU per departament.
      4. Crea un grup de seguretat per departament.
      5. Crea el grup "Caps_Departament".
      6. Genera un login únic (SamAccountName) per a cada usuari:
         - Inicials del nom + primer cognom, tot normalitzat.
         - Si col·lisiona: +1a lletra del 2n cognom → número incremental.
      7. Crea l'usuari en la OU corresponent i l'afig al grup del dept.
      8. Afig els caps (descrip="Jefe") al grup de caps.
      9. Genera un LOG i un CSV de resum.

.PARAMETER Seu
    Nom de la seu (Alcoi, Vigo, Barcelona, Madrid).

.PARAMETER FitxerCSV
    Ruta al CSV (per defecte: .\usuaris.csv).

.PARAMETER SimulacioMode
    Mostra què faria sense fer cap canvi real a l'AD.

.EXAMPLE
    .\Crear_Usuaris.ps1 -Seu "Alcoi"
    .\Crear_Usuaris.ps1 -Seu "Alcoi" -FitxerCSV "C:\dades\usuaris.csv"
    .\Crear_Usuaris.ps1 -Seu "Alcoi" -SimulacioMode
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true,
     HelpMessage="Seu a processar: Alcoi, Vigo, Barcelona o Madrid")]
    [ValidateSet("Alcoi","Vigo","Barcelona","Madrid")]
    [string]$Seu,

    [Parameter(Mandatory=$false)]
    [string]$FitxerCSV = ".\usuaris.csv",

    [switch]$SimulacioMode
)

# ══════════════════════════════════════════════════════════════════════════════
#  IMPORTAR MÒDUL AD
# ══════════════════════════════════════════════════════════════════════════════
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Error "No s'ha pogut carregar el mòdul ActiveDirectory. Instal·la RSAT."
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  CONFIGURACIÓ AUTOMÀTICA DEL DOMINI
# ══════════════════════════════════════════════════════════════════════════════
$InfoDomini   = Get-ADDomain
$DominiDN     = $InfoDomini.DistinguishedName     # DC=empresa,DC=local
$NomDomini    = $InfoDomini.DNSRoot               # empresa.local
$DataExecucio = Get-Date -Format "yyyyMMdd_HHmmss"
$FitxerLog    = ".\Log_Usuaris_${Seu}_${DataExecucio}.txt"

# ══════════════════════════════════════════════════════════════════════════════
#  FUNCIONS AUXILIARS
# ══════════════════════════════════════════════════════════════════════════════

# ── LOG: escriu a fitxer i a consola amb color ───────────────────────────────
function Escriure-Log {
    param(
        [string]$Missatge,
        [string]$Tipus = "INFO"
    )
    $linia = "[$(Get-Date -Format 'HH:mm:ss')] [$Tipus] $Missatge"
    switch ($Tipus) {
        "OK"    { Write-Host $linia -ForegroundColor Green  }
        "AVIS"  { Write-Host $linia -ForegroundColor Yellow }
        "ERROR" { Write-Host $linia -ForegroundColor Red    }
        "SIM"   { Write-Host $linia -ForegroundColor Cyan   }
        default { Write-Host $linia                         }
    }
    Add-Content -Path $FitxerLog -Value $linia -Encoding UTF8
}

# ── NORMALITZAR: minúscules, sense accents, sense caràcters especials ────────
# Utilitza descomposició Unicode FormD per eliminar diacrítics.
# Tracta a més ñ/Ñ i ç/Ç de forma explícita.
# El resultat només conté [a-z0-9].
function Normalitzar-Text {
    param([string]$Text)

    # 1. Descomposició Unicode: á → a + accent (que després s'elimina)
    $nfd = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $net = ""
    foreach ($c in $nfd.ToCharArray()) {
        $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
        # Descartar NonSpacingMark (accents, dièresis, etc.)
        if ($cat -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            $net += $c
        }
    }

    # 2. Reemplaçaments manuals (ñ i ç no es descomponen amb NFD)
    $net = $net -replace '[ñÑ]', 'n'
    $net = $net -replace '[çÇ]', 'c'

    # 3. Minúscules + només alfanumèric ASCII
    $resultat = ($net.ToLower()) -replace '[^a-z0-9]', ''

    return $resultat
}

# ── CREAR OU: crea l'OU si no existeix ───────────────────────────────────────
function Assegurar-OU {
    param(
        [string]$NomOU,
        [string]$PathPare
    )
    $ouDN = "OU=$NomOU,$PathPare"

    if ([ADSI]::Exists("LDAP://$ouDN")) {
        Escriure-Log "OU ja existeix: $ouDN"
    }
    else {
        if ($SimulacioMode) {
            Escriure-Log "Crearia OU: $ouDN" "SIM"
        }
        else {
            try {
                New-ADOrganizationalUnit -Name $NomOU -Path $PathPare `
                    -ProtectedFromAccidentalDeletion $false
                Escriure-Log "OU creada: $ouDN" "OK"
            }
            catch {
                Escriure-Log "Error creant OU $ouDN : $_" "ERROR"
            }
        }
    }
    return $ouDN
}

# ── CREAR GRUP: crea el grup de seguretat si no existeix ─────────────────────
function Assegurar-Grup {
    param(
        [string]$NomGrup,
        [string]$PathOU,
        [string]$Descripcio = ""
    )
    try {
        Get-ADGroup -Identity $NomGrup -ErrorAction Stop | Out-Null
        Escriure-Log "Grup ja existeix: $NomGrup"
    }
    catch {
        if ($SimulacioMode) {
            Escriure-Log "Crearia grup: $NomGrup → $PathOU" "SIM"
        }
        else {
            try {
                New-ADGroup -Name $NomGrup `
                    -SamAccountName $NomGrup `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $PathOU `
                    -Description $Descripcio
                Escriure-Log "Grup creat: $NomGrup" "OK"
            }
            catch {
                Escriure-Log "Error creant grup $NomGrup : $_" "ERROR"
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  VALIDACIÓ DEL FITXER CSV
# ══════════════════════════════════════════════════════════════════════════════
if (-not (Test-Path $FitxerCSV)) {
    Write-Error "No es troba el fitxer CSV: $FitxerCSV"
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  INICI DEL PROCÉS
# ══════════════════════════════════════════════════════════════════════════════
Escriure-Log "============================================================"
Escriure-Log "  CREACIÓ D'USUARIS ACTIVE DIRECTORY"
Escriure-Log "  Seu:        $Seu"
Escriure-Log "  CSV:        $FitxerCSV"
Escriure-Log "  Domini:     $NomDomini ($DominiDN)"
if ($SimulacioMode) {
    Escriure-Log "  *** MODE SIMULACIÓ — cap canvi real ***" "SIM"
}
Escriure-Log "============================================================"

# ── Llegir i filtrar CSV ─────────────────────────────────────────────────────
$csv = Import-Csv -Path $FitxerCSV -Encoding UTF8
$usuarisSeu = $csv | Where-Object { $_.sede -eq $Seu }

if ($usuarisSeu.Count -eq 0) {
    Escriure-Log "No hi ha usuaris per a la seu '$Seu'." "AVIS"
    exit 0
}
Escriure-Log "Usuaris trobats per a '$Seu': $($usuarisSeu.Count)"

# ══════════════════════════════════════════════════════════════════════════════
#  FASE 1: CREAR ESTRUCTURA D'OUs
# ══════════════════════════════════════════════════════════════════════════════
Escriure-Log ""
Escriure-Log "--- FASE 1: Unitats Organitzatives ---"

$ouSeu = Assegurar-OU -NomOU $Seu -PathPare $DominiDN

$departaments = $usuarisSeu | Select-Object -ExpandProperty dept -Unique | Sort-Object
foreach ($dept in $departaments) {
    Assegurar-OU -NomOU $dept -PathPare $ouSeu | Out-Null
}

# ══════════════════════════════════════════════════════════════════════════════
#  FASE 2: CREAR GRUPS DE SEGURETAT
# ══════════════════════════════════════════════════════════════════════════════
Escriure-Log ""
Escriure-Log "--- FASE 2: Grups de seguretat ---"

foreach ($dept in $departaments) {
    $nomGrup = "GRP_${Seu}_${dept}" -replace '\s+', '_'
    $ouDept  = "OU=$dept,$ouSeu"
    Assegurar-Grup -NomGrup $nomGrup -PathOU $ouDept `
        -Descripcio "Departament $dept - Seu $Seu"
}

# Grup de Caps de Departament (a nivell de seu)
$grupCapsNom = "GRP_${Seu}_Caps_Departament"
Assegurar-Grup -NomGrup $grupCapsNom -PathOU $ouSeu `
    -Descripcio "Caps de departament de la seu $Seu"

# ══════════════════════════════════════════════════════════════════════════════
#  FASE 3: CREAR USUARIS
# ══════════════════════════════════════════════════════════════════════════════
Escriure-Log ""
Escriure-Log "--- FASE 3: Creació d'usuaris ---"

# HashSet per controlar unicitat de logins (persisteix en el scope principal)
$loginsUsats = [System.Collections.Generic.HashSet[string]]::new()

# Comptadors
$comptCreats = 0
$comptOmesos = 0
$comptCaps   = 0

# Array per al resum final
$resum = @()

foreach ($u in $usuarisSeu) {

    # ── Dades de l'usuari ────────────────────────────────────────────────
    $nom     = $u.nom.Trim()
    $cognom1 = $u.cognom1.Trim()
    $cognom2 = $u.cognom2.Trim()
    $dni     = $u.dni.Trim()
    $dept    = $u.dept.Trim()
    $descrip = $u.descrip.Trim()

    # ── Generar login únic ───────────────────────────────────────────────
    # Inicials: 1a lletra de cada paraula del nom (màx. 3 parts)
    $parts = ($nom -split '\s+') | Where-Object { $_ -ne "" }
    $inicials = ""
    $cnt = 0
    foreach ($part in $parts) {
        $pn = Normalitzar-Text $part
        if ($pn.Length -gt 0 -and $cnt -lt 3) {
            $inicials += $pn[0]
            $cnt++
        }
    }
    $c1 = Normalitzar-Text $cognom1
    $c2 = Normalitzar-Text $cognom2

    # Intent 1: inicials + cognom1
    $login = "${inicials}${c1}"
    if ($loginsUsats.Contains($login)) {
        # Intent 2: + 1a lletra del cognom2
        if ($c2.Length -gt 0) {
            $login = "${inicials}${c1}$($c2[0])"
        }
    }
    if ($loginsUsats.Contains($login)) {
        # Intent 3: número incremental
        $base = "${inicials}${c1}"
        $i = 2
        $login = "${base}${i}"
        while ($loginsUsats.Contains($login)) {
            $i++
            $login = "${base}${i}"
        }
    }
    [void]$loginsUsats.Add($login)

    # ── Propietats AD ────────────────────────────────────────────────────
    $nomComplet  = "$nom $cognom1 $cognom2"
    $displayName = "$cognom1 $cognom2, $nom"
    $givenName   = ($nom -split '\s+')[0]    # Primer mot del nom
    $surname     = "$cognom1 $cognom2"
    $upn         = "$login@$NomDomini"
    $ouDest      = "OU=$dept,$ouSeu"
    $nomGrupDept = "GRP_${Seu}_${dept}" -replace '\s+', '_'

    # ── Comprovar si l'usuari ja existeix ────────────────────────────────
    $existeix = $false
    try {
        Get-ADUser -Identity $login -ErrorAction Stop | Out-Null
        $existeix = $true
    }
    catch { <# no existeix, perfecte #> }

    if ($existeix) {
        Escriure-Log "Usuari '$login' ja existeix → s'omet ($nomComplet)" "AVIS"
        $comptOmesos++
        $estat = "Omes"
    }
    else {
        # ── Crear l'usuari ───────────────────────────────────────────────
        $passwd = ConvertTo-SecureString -String $dni -AsPlainText -Force

        if ($SimulacioMode) {
            Escriure-Log ("Crearia: {0,-18} {1,-35} OU={2,-16} Grup={3}" -f `
                $login, $nomComplet, $dept, $nomGrupDept) "SIM"
        }
        else {
            try {
                New-ADUser `
                    -SamAccountName        $login `
                    -UserPrincipalName     $upn `
                    -Name                  $nomComplet `
                    -GivenName             $givenName `
                    -Surname               $surname `
                    -DisplayName           $displayName `
                    -Description           $descrip `
                    -Department            $dept `
                    -Office                $Seu `
                    -Path                  $ouDest `
                    -AccountPassword       $passwd `
                    -ChangePasswordAtLogon $true `
                    -Enabled               $true

                Escriure-Log ("Creat: {0,-18} {1,-35} OU={2,-16} Grup={3}" -f `
                    $login, $nomComplet, $dept, $nomGrupDept) "OK"

                # Afegir al grup del departament
                Add-ADGroupMember -Identity $nomGrupDept -Members $login
                Escriure-Log "  └─ Afegit a $nomGrupDept" "OK"
            }
            catch {
                Escriure-Log "Error creant $login : $_" "ERROR"
            }
        }
        $comptCreats++
        $estat = "Creat"
    }

    # ── Si és cap → afegir al grup de caps ───────────────────────────────
    if ($descrip -eq "Jefe") {
        if ($SimulacioMode) {
            Escriure-Log "  └─ Afegiria '$login' a $grupCapsNom (cap de $dept)" "SIM"
        }
        else {
            try {
                Add-ADGroupMember -Identity $grupCapsNom -Members $login `
                    -ErrorAction Stop
                Escriure-Log "  └─ Afegit a $grupCapsNom (cap de $dept)" "OK"
            }
            catch {
                Escriure-Log "  └─ Ja era membre de $grupCapsNom o error: $_" "AVIS"
            }
        }
        $comptCaps++
    }

    # ── Guardar al resum ─────────────────────────────────────────────────
    $resum += [PSCustomObject]@{
        Login       = $login
        UPN         = $upn
        NomComplet  = $nomComplet
        DNI         = $dni
        Departament = $dept
        OU          = $ouDest
        GrupDept    = $nomGrupDept
        EsCap       = if ($descrip -eq "Jefe") {"Si"} else {"No"}
        Estat       = $estat
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  RESUM FINAL
# ══════════════════════════════════════════════════════════════════════════════
Escriure-Log ""
Escriure-Log "============================================================"
Escriure-Log "  RESUM"
Escriure-Log "============================================================"
Escriure-Log "  Seu:                    $Seu"
Escriure-Log "  Domini:                 $NomDomini"
Escriure-Log "  Total al CSV:           $($usuarisSeu.Count)"
Escriure-Log "  Usuaris creats:         $comptCreats"
Escriure-Log "  Usuaris omesos:         $comptOmesos"
Escriure-Log "  Caps de departament:    $comptCaps"
Escriure-Log "  Departaments (OUs):     $($departaments.Count)"
Escriure-Log "  Log:                    $FitxerLog"
Escriure-Log "============================================================"

# ── Exportar resum a CSV (per a la documentació / memòria) ───────────────────
$fitxerResum = ".\Resum_Usuaris_${Seu}_${DataExecucio}.csv"
$resum | Export-Csv -Path $fitxerResum -NoTypeInformation -Encoding UTF8
Escriure-Log "Resum exportat a: $fitxerResum" "OK"

# ── Taula resum per pantalla ─────────────────────────────────────────────────
Write-Host ""
$resum | Format-Table Login, NomComplet, Departament, GrupDept, EsCap, Estat -AutoSize
