# Just simple deployment Ubuntu Server 20.04

何も特徴的なことはない、ただ Ubuntu Server 20.04 をデプロイするだけ。

# 構成のポイント

- Bastion を利用する
- 某社内ルールにのっとって NSG が自動で設定される

# 結果

以下のコマンドで Bastion 経由での接続ができます。

```
az network bastion ssh --name "bast-hub00" `
  --resource-group "simple-ubuntu" `
    --target-resource-id "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxx/providers/Microsoft.Compute/virtualMachines/vm-hub00" `
    --auth-type "ssh-key" `
    --username "ikko" `
    --ssh-key "C:\Users\xxxxxxxx\.ssh\id_rsa"
```
