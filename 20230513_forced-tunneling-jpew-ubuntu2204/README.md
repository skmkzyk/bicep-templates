# Building a Forced Tunneling Architecture with Azure Route Server across Japan East and Japan West Regions (Change to Ubuntu Server 22.04)

Azure Route Server を使った強制トンネリングの環境を作成する。
この repos の 20230509 の方と違い、東日本 region と西日本 region にまたがる構成になっています。
また、20230510 のとは違い、FRRouting を動作させる Azure VM に Ubuntu Server 22.04 を採用しています。

# 構成のポイント

- 前回の Ubuntu Server 20.04 から Ubuntu Server 22.04 へと変更した
- `apt-key` が deprecated になったので、`gpg` を使うように変更した
- `iptables` から `nftables` へと変更した

# 結果

動作上の変化はなし。

# 参考

- Build a forced tunneling architecture with Azure Route Server

  https://github.com/skmkzyk/bicep-templates/tree/main/20230509_forced-tunneling

- Build a forced tunneling architecture with Azure Route Server, extending across both the Japan East and Japan West regions

  https://github.com/skmkzyk/bicep-templates/tree/main/20230510_forced-tunneling-jpew

- ExpressRoute 検証環境をシュッと作る

  https://zenn.dev/skmkzyk/articles/crisp-expressroute

- Azure Route Server と FRRouting の間で BGP ピアを張る

  https://zenn.dev/skmkzyk/articles/azure-route-server-frrouting

- ARS と FRRouting を使った強制トンネリング環境を作る

  https://zenn.dev/skmkzyk/articles/forced-tunneling-with-ars-and-frrouting
