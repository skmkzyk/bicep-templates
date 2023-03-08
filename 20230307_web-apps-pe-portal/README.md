# Create Web Apps with Private Endpoint (via Azure Portal)

Web Apps を作成して、その後 Azure Portal から **Private** Endpoint を作成する。
その際に **Public** Endpoint が無効化されないようにする。

# 構成のポイント

なんとなくで node.js のあぷりが起動してきます。
main.bicep を実行した状態では、App Service plan と Web Apps、VNet、Private DNS Zone などは作られますが、Private Endpoint は作成されていない状態になります。
つまり Private Endpoint を作る 5 秒前、という感じです。

Web Apps の property の一つに `publicNetworkAccess` というのがあり、これを `Enabled` にした状態で、Azure Portal から **Private** Endpoint を作成しても、**Public** Endpoint が無効化されないことを確認しています。
逆に言うと、普通に Web Apps を作成しただけでは `publicNetworkAccess` が `null` になっており、この状態で **Private** Endpoint を作成すると **Public** Endpoint が無効化されます。
Web Apps に対する **Private** Endpoint を有効化すると **Public** Endpoint が無効化される、というのが一種の制約だったのですが、いつからかその制約がなくなったようです。

その設定変更について、ARM template や Bicep で実行するのは簡単なのですが、そうではない方法ということでここでは Azure PowerShell や Azure CLI を利用します。

```
$Resource = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName <group-name> -ResourceName <app-name>
$Resource.Properties.publicNetworkAccess = 'Enabled'
$Resource | Set-AzResource -Force
```

```
az resource update --resource-group <group-name> --name <app-name> --set properties.publicNetworkAccess='Enabled' --resource-type 'Microsoft.Web/sites'
```

このいずれかのコマンド実行により、Web Apps の `publicNetworkAccess` property のみが変更できます。
この設定変更の後に、Azure Portal から Private Endpoint を作成しても、インターネット経由のアクセスは無効化されません。

# 参考

Azure Resource の property の一部を変更するのは ARM template か Bicep のみかと思っていたのですが、汎用的な手段があったのを初めて知りました。

- Set-AzResource

  Azure PowerShell で property の一部を変更する時とかにどうぞ

  https://learn.microsoft.com/en-us/powershell/module/az.resources/set-azresource

- az resource update

  Azure CLI で property の一部を変更する時とかにどうぞ

  https://learn.microsoft.com/ja-jp/cli/azure/resource#az-resource-update

- Create Web Apps with Private Endpoint

  まぁ普通に全部 Bicep で済ませるのであればこちら

  https://github.com/skmkzyk/bicep-templates/tree/main/20230301_web-apps-pe
