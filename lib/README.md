# Bicep module library

Bicep は module 化がとても便利なのでさまざまなものを作成しています。
具体的な利用方法については、利用している側のフォルダを見たほうが早いかとは思います。

ざっくりリソース プロバイダで分類しておきます。
Azure Firewall はフィルタがかかっていない状態で作成される、などほんとにシンプルなデプロイにしてしまっているので注意してください。
カスタマイズの必要がある場合には `main.bicep` 側に内容をコピーしてしまい、編集しながら使います。

- Microsoft.Network

  ExpressRoute Gateway や VPN Gateway などが簡単に作れること、またそれを使って Connection が簡単に作成できることを目指しています。
  Bastion や Azure Firewall など検証用途では必要になるものについて、最低限の記述量で作成できるようにしてあります。
  VNet については module にしても複雑になることが多くなってしまったため、直接 `main.bicep` 側に書いていることが多いです。

- Micrososft.Compute

  Windows Server 2019 と Ubuntu Server 20.04 がありますが、SKU は Standard_B2ms で作成され、OS disk は Standard SSD を利用しているなど、私自身の好みによって固定されているため、本番環境には適していないことも多いかと思います。
