param (
    [Parameter(Mandatory=$true)]
    [string]$DemoName
)

$ProjectRoot = "C:\Users\Lenovo\Downloads\riscv-32im"
$SourceBase = "$ProjectRoot\riscv-32im.srcs\sources_1\imports\5-stage-version"
$DemoDir = "$ProjectRoot\demos\$DemoName"

if (!(Test-Path $DemoDir)) {
    Write-Host "Error: Demo '$DemoName' not found in $ProjectRoot\demos\" -ForegroundColor Red
    exit 1
}

Write-Host "Switching to demo: $DemoName..." -ForegroundColor Cyan

# 1. Copy top_fpga.v
if (Test-Path "$DemoDir\top_fpga.v") {
    Copy-Item -Path "$DemoDir\top_fpga.v" -Destination "$SourceBase\top_fpga.v" -Force
    Write-Host "[OK] top_fpga.v updated"
}

# 2. Copy imem_fpga.hex
if (Test-Path "$DemoDir\imem_fpga.hex") {
    Copy-Item -Path "$DemoDir\imem_fpga.hex" -Destination "$SourceBase\imem_fpga.hex" -Force
    Write-Host "[OK] imem_fpga.hex updated"
}

# 3. Copy dmem_fpga.hex (if exists)
if (Test-Path "$DemoDir\dmem_fpga.hex") {
    Copy-Item -Path "$DemoDir\dmem_fpga.hex" -Destination "$SourceBase\dmem_fpga.hex" -Force
    Write-Host "[OK] dmem_fpga.hex updated"
}

Write-Host "Success! You can now run Vivado synthesis/implementation." -ForegroundColor Green
