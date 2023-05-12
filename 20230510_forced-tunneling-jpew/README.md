# Build a forced tunneling architecture with Azure Route Server, extending across both the Japan East and Japan West regions

Azure Route Server を使った強制トンネリングの環境を作成する。
この repos の 20230509 の方と違い、東日本 region と西日本 region にまたがる構成になっています。

# 構成のポイント

- 20230509 の方は東日本 region だけの構成でしたが、こちらでは西日本 region にも同様の構成を作成しています
- 加えて、`clout-init` を利用することで NVA として利用する Ubuntu Server 20.04 の設定変更は起動時に自動で行われるようにしています
- また、強制トンネリングをふたつの region でたすき掛けになるように構成してあり、定常状態では東日本 region の NVA からインターネットに出ていき、障害発生時には西日本 region の NVA から出ていくようになっています
  - これは、ExpressRoute circuit と ExpressRoute Gateway との間の connection というリソースにある `routingWeight` という property を使い、メインとしたい connection にはより大きな値 (100) とすることで実現しています
  - 定常状態ではクラウド想定の VNet #1 と クラウド想定の VNet #3 の両方がオンプレミス想定の VNet #2 から出ていき、障害時には両方とも オンプレミス想定の VNet #4 から出ていく、という設計です

内容が冗長になるので、詳細な説明は Zenn の記事の方を見ていただければと思います。

# 結果

定常状態では例えばこの IP アドレスからインターネットに出ていっています。

```powershell
> curl.exe https://ifconfig.me
20.78.x.x
```

その状態で、強制トンネリングしているオンプレミス想定の VNet #2 と ExpressRoute circuit の間の connection を削除します。
十数秒の段時間がありますが、通信が安定後は別の IP アドレスが送信元となりインターネットに出ていっていることが確認できました。

```powershell
> curl.exe https://ifconfig.me
104.215.x.x
```

# 参考

- ExpressRoute 検証環境をシュッと作る

  https://zenn.dev/skmkzyk/articles/crisp-expressroute

- Azure Route Server と FRRouting の間で BGP ピアを張る

  https://zenn.dev/skmkzyk/articles/azure-route-server-frrouting

- ARS と NVA を使った強制トンネリング環境を作る

  https://zenn.dev/skmkzyk/articles/forced-tunneling-with-ars-and-nva
