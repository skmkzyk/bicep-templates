# Establish peer between FRRouting and ARS by `cloud-init` on Ubuntu Server 22.04

FRRouting と Azure Route Server (ARS) との間の BGP peer を `cloud-init` で自動設定してしまおう、という話。
以前のは Ubuntu Server 20.04 で構成していたのでこれを 22.04 に置き換えたもの。

# 参考

- Establish peer between FRRouting and ARS by `cloud-init`

   https://github.com/skmkzyk/bicep-templates/tree/main/20220816_frrouting-ars-cloud-init/

- Azure Route Server と FRRouting の間で BGP ピアを張る

   https://zenn.dev/skmkzyk/articles/azure-route-server-frrouting
