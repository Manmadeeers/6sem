Import-Module SqlServer -ErrorAction Stop

$Server   = 'localhost,1433'
$Database = 'Warehouse'
$OutFile  = 'C:\Users\Manmade\Desktop\6sem\IADB\Code\Lab_11\MSSQL\export.csv'

$SqlUser = 'sa' 
$SqlPass = Read-Host 'SQL password'

$query = @"
SELECT *
FROM dbo.fn_products_stocks_by_period('2026-01-01','2026-12-31');
"@

$rows = Invoke-Sqlcmd `
  -ServerInstance $Server `
  -Database $Database `
  -Query $query `
  -Username $SqlUser `
  -Password $SqlPass `
  -TrustServerCertificate `
  -ErrorAction Stop

if ($rows) {
  $rows | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
} else {
  Write-Warning "Query returned 0 rows."
}