# Just simple deployment CBL Mariner

何も特徴的なことはない、ただ CBL Mariner をデプロイするだけ。

# 構成のポイント

- Bastion を利用する
- 某社内ルールにのっとって NSG が自動で設定される
- lib においてある ubuntu2004.bicep と比べて、`imageReference` の部分が以下のとおり変更になっています
  ```json
  imageReference: {
    publisher: 'MicrosoftCBLMariner'
    offer: 'cbl-mariner'
    sku: 'cbl-mariner-2-gen2'
    version: 'latest'
  }
  ```

# 結果

デプロイ時に未使用 parameter の warning がいっぱい出ますが、Ubuntu Server 20.04 のをそのまま流用しつつ、いろいろな付随する resource を無効化したせいです。
とくに気にしなくても大丈夫です。

以下のコマンドで Bastion 経由での接続ができます。

```
az network bastion ssh --name "bast-hub00" `
  --resource-group "xxxxxxxx" `
    --target-resource-id "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Compute/virtualMachines/vm-mrnr00" `
    --auth-type "ssh-key" `
    --username "ikko" `
    --ssh-key "C:\Users\xxxxxxxx\.ssh\id_rsa"
```

# 参考

- こちらを参考に publisher とかを指定してます

https://microsoft.github.io/CBL-Mariner/announcing-mariner-2.0/
