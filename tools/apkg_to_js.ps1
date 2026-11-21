# Chuyển bộ thẻ Anki (.apkg) thành file bộ đề data/<MÃ>.js
# Cách dùng (PowerShell, không cần cài gì thêm — dùng winsqlite3.dll có sẵn trong Windows):
#   powershell -ExecutionPolicy Bypass -File tools\apkg_to_js.ps1 <file.apkg> <MÃ_MÔN>
# Yêu cầu note có các field: Question, Options (<li><span class="label">A.</span>...</li>), Answer ("B. ...").
# Field Information (nếu có) — lấy phần <div class="core"> làm ghi chú.
param(
  [Parameter(Mandatory)][string]$Apkg,
  [Parameter(Mandatory)][string]$Code,
  [string]$Out
)
$ErrorActionPreference = 'Stop'
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\data\$Code.js" }

Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public static class AnkiSql {
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_open_v2(byte[] f, out IntPtr db, int flags, IntPtr v);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int n, out IntPtr st, IntPtr t);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_step(IntPtr st);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_column_count(IntPtr st);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern IntPtr sqlite3_column_text(IntPtr st, int i);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_column_bytes(IntPtr st, int i);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_finalize(IntPtr st);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern int sqlite3_close(IntPtr db);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.StdCall)] static extern IntPtr sqlite3_errmsg(IntPtr db);
  static byte[] Z(string s){ return Encoding.UTF8.GetBytes(s + "\0"); }
  public static List<string[]> Run(string f, string sql){
    IntPtr db, st; var rows = new List<string[]>();
    if (sqlite3_open_v2(Z(f), out db, 1, IntPtr.Zero) != 0) throw new Exception("Không mở được " + f);
    if (sqlite3_prepare_v2(db, Z(sql), -1, out st, IntPtr.Zero) != 0) throw new Exception(Marshal.PtrToStringAnsi(sqlite3_errmsg(db)));
    while (sqlite3_step(st) == 100) {
      int n = sqlite3_column_count(st); var r = new string[n];
      for (int i = 0; i < n; i++) { IntPtr p = sqlite3_column_text(st, i); int len = sqlite3_column_bytes(st, i); var b = new byte[len]; if (len > 0) Marshal.Copy(p, b, 0, len); r[i] = Encoding.UTF8.GetString(b); }
      rows.Add(r);
    }
    sqlite3_finalize(st); sqlite3_close(db); return rows;
  }
}
"@

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("apkg_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
try {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Apkg))
  $entry = $zip.Entries | Where-Object { $_.Name -eq 'collection.anki21' } | Select-Object -First 1
  if (-not $entry) { $entry = $zip.Entries | Where-Object { $_.Name -eq 'collection.anki2' } | Select-Object -First 1 }
  if (-not $entry) { throw 'Không thấy collection.anki2 trong file .apkg (định dạng .anki21b mới chưa hỗ trợ).' }
  $db = Join-Path $tmp 'col.db'
  [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $db)
  $zip.Dispose()

  $models = [AnkiSql]::Run($db, 'select models from col')[0][0] | ConvertFrom-Json
  $fieldsOf = @{}
  foreach ($p in $models.PSObject.Properties) { $fieldsOf[[string]$p.Name] = @($p.Value.flds | Sort-Object ord | ForEach-Object name) }

  function Clean([string]$h) {
    $h = $h -replace '(?i)<br\s*/?>', "`n" -replace '<[^>]+>', ''
    $h = [Net.WebUtility]::HtmlDecode($h)
    ($h -replace '[ \t ]+', ' ' -replace '\s*\n\s*', "`n").Trim()
  }

  $rows = [AnkiSql]::Run($db, 'select mid, flds from notes order by id')
  $items = @(); $skip = 0
  foreach ($r in $rows) {
    $names = $fieldsOf[[string]$r[0]]
    $vals = $r[1].Split([char]0x1f)
    $f = @{}; for ($i = 0; $i -lt $names.Count; $i++) { $f[$names[$i]] = $vals[$i] }
    $opts = @([regex]::Matches($f['Options'], '(?s)<li>(.*?)</li>') | ForEach-Object { Clean ($_.Groups[1].Value -replace '<span class="label">[A-Z]\.</span>', '') })
    $m = [regex]::Match((Clean $f['Answer']), '^([A-Z])\.')
    if (-not $f['Question'] -or $opts.Count -lt 2 -or -not $m.Success) { $skip++; continue }
    $ans = $m.Groups[1].Value.ToLower()
    $note = ''
    if ($f['Information']) { $c = [regex]::Match($f['Information'], '(?s)<div class="core">(.*?)</div>'); if ($c.Success) { $note = Clean $c.Groups[1].Value } }
    $items += , @(0, (Clean $f['Question']), $opts, $ans, $note)
  }
  for ($i = 0; $i -lt $items.Count; $i++) { $items[$i][0] = $i + 1 }

  $json = ConvertTo-Json -InputObject $items -Depth 5 -Compress
  New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
  [IO.File]::WriteAllText($Out, "(window.BANKS = window.BANKS || {})['$Code'] = $json;`n", (New-Object Text.UTF8Encoding $false))
  "Đã ghi $($items.Count) câu vào $Out (bỏ qua $skip)."
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
