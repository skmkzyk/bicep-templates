# Just simple deployment squid proxy on Ubuntu Server 20.04

Ubuntu Server 20.04 の Azure VM を立てて、squid を install し、そこらへんからアクセスできる簡単な proxy サーバになるよう squid.conf を書き換える。

# 構成のポイント

- Bastion を利用する
- 某社内ルールにのっとって NSG が自動で設定される
- `cloud-init` を使って自動的に設定がなされるようにする
- Bicep の `loadFileAsBase64()` を使って `cloud-init` 用の yaml を別のファイルとしてに書くことができるようにする

# 結果

squid が install されていて、`/etc/squid/squid.conf` も書き換わっていた。

```
root@vm-hub00:/etc/squid# diff -u squid.conf.org squid.conf
--- squid.conf.org      2022-09-23 12:07:31.000000000 +0000
+++ squid.conf  2022-10-03 09:21:37.419239113 +0000
@@ -1404,7 +1404,7 @@
 # Example rule allowing access from your local networks.
 # Adapt localnet in the ACL section to list your (internal) IP networks
 # from where browsing should be allowed
-#http_access allow localnet
+http_access allow localnet
 http_access allow localhost

 # And finally deny all other access to this proxy
```

# 参考

[File functions for Bicep - `loadFileAsBase64()`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-files#loadfileasbase64)
