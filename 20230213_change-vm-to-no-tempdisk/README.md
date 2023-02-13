# Change Azure VM to no Temp Disk SKUs

Azure VM を temp disk を持たない SKU に変更する

# 構成のポイント

- 規定では pagefile の location が D:\pagefile.sys になっているので、これを C: に変更する
- 一時的に Azure VM を削除するため deleteOption が Detach になっているようにする

# 結果

`Get-Help` すればわかると思いますが、以下のような感じでたたけば実行できます。
`-Verbose` オプションを付けるといろいろ詳細な出力が出てきます。

```powershell
Set-VmSizeToNoTempDisk [-ResourceGroupName] <string> [-LocationName] <string> [-VMName] <string> [-VMSize] <string> [<CommonParameters>]
```

# 参考

- ローカル一時ディスクを持たない Azure VM のサイズ

  https://learn.microsoft.com/ja-jp/azure/virtual-machines/azure-vms-no-temp-disk#--------------vm--------------------vm----------------------

- 既存のリソースから Azure VM を作る

  https://zenn.dev/microsoft/articles/create-vm-from-existing-resource

- PowerShell - Working with Format-Table in Verbose, Debug, Output Streams - Evotec

  `Write-Verbose` と `Format-Table` を組み合わせるのにちょっとだけ工夫が必要だった。
  https://evotec.xyz/powershell-working-with-format-table-in-verbose-debug-output-streams/

- Approved Verbs for PowerShell Commands

  最初 `Change-VmSizeToNoTempDisk` にしてたけど動詞として非推奨っぽかったので変えた。
  https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands

- Just simple deployment Windows Server 2019

  Bicep としてはこれとほぼ変わってないはず
  https://github.com/skmkzyk/bicep-templates/tree/main/20221213_simple-ws2019
