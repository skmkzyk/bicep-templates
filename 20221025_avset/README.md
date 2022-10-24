# Create vm in Availability Set

可用性セット (Availability Set) の中に Azure VM を作成してみるテスト

# 構成のポイント

ポイント、というほどでもないんですが、Microsoft.Compute/availabilitySets の `sku` には 2 種類あって、デフォルトだと `'Classic'` でこれは非管理ディスク (Unmanaged disk) を使う Azure VM 向けとなっています。
そのため、明示的に `sku` として `'Alligned'` を選択する必要があります。

# 参考

https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/availabilitysets?#availabilitysets
