# Azure Files Private Endpoint

Azure Files に対して Private Endpoint を有効化する。

# 構成のポイント

特になし、やるだけ！

# 結果

インターネット越しだと設定変更くらいはできるけど、Files の中身は見れない。

# 参考

- Microsoft.Storage storageAccounts/fileServices/shares

  Azure Files が storageAccounts/fileServices/shares っていうちょっと深いところにある (fileServices ってなにやってんのかわからんけど) を初めて知った。

  https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts/fileservices/shares

- Linter rule - no hardcoded environment URL

  privatelink.file.core.windows.net とかをハードコードすると怒られる。
  次に書いてある `environment()` っていう関数使えば怒られないようになる

  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-no-hardcoded-environment-urls

- Deployment functions for Bicep

  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-deployment#environment
