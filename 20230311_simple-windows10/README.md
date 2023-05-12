# Just simple deployment Windows 10

何も特徴的なことはない、ただ Windows 10 をデプロイするだけ。

# 構成のポイント

- Bastion を利用する
- 某社内ルールにのっとって NSG が自動で設定される
- Bicep の `for` 構文をはさんだので、複数の VM を一気にデプロイできる

# 結果

以下のコマンドで Bastion 経由での接続ができます。

```powershell
Connect-MyAzBastionRdp -VMName vm-hub00 -ResourceGroupName simple-ws2019 -BastionName bast-hub00
```

なお、`Connect-MyAzBastionRdp` は自作の PowerShell function です。
中身は参考の Zenn をご参照ください。

# 参考

- PowerShell だけで (Azure CLI を使わずに) Bastion を Native Client で RDP する

  https://zenn.dev/skmkzyk/articles/bastion-rdp-powershell-only
