# Just simple deployment Windows Server 2019

何も特徴的なことはない、ただ Windows Server 2019 をデプロイするだけ。

# 構成のポイント

- Bastion を利用する
- 某社内ルールにのっとって NSG が自動で設定される

# 結果

以下のコマンドで Bastion 経由での接続ができます。

```powershell
Connect-MyAzBastionRdp -VMName vm-hub00 -ResourceGroupName simple-ws2019 -BastionName bast-hub00
```

なお、`Connect-MyAzBastionRdp` は自作の PowerShell function です。
中身は参考の Zenn をご参照ください。

# 参考

- マルチモニタをオフにして Bastion で RDP を使う

  https://zenn.dev/skmkzyk/articles/bastion-without-multimon