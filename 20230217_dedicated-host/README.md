# Azure Dedicated Host with Azure NetApp Files

Azure Dedicated Host と Azure NetApp Files を組み合わせた検証が必要だった。
Bicep でもろもろの構成を試す。
お金がかかるものが多いので Dedicated Host と Azure NetApp Files の箇所は一応コメントアウトしてある。

# 構成のポイント

やるだけ、あんまり難しいポイントはなし！
Azure NetApps Files の構成は Microsoft.NetApp/netAppAccounts/capacityPools/volumes という感じ。
お金は capacityPools の部分でかかってくるので注意する。

Dedicated Host に対して、変更がなかったとしても、なぜか 2 倍の quota を要求してくる気がする。
2 回目以降の deploy で、Dedicated Host に対して変更がない場合には、`existing` キーワードの方に切り替えた方が quota の追加申請がいらない。

# 結果

今回は [Microsoft/Ethr](https://github.com/Microsoft/Ethr) と [axboe/fio](https://github.com/axboe/fio) を使って検証してた。
`ethr` の方は `-t l` が latency の検証に適してる。
`fio` はなんかオプションがとっても難しい。

# 参考

- Azure NetApp Files のパフォーマンス ベンチマークのテスト レコメンデーション

  fio に関しては Microsoft 公式でこうつかったらどうかね、というのが出てるので参考にする

  https://learn.microsoft.com/ja-jp/azure/azure-netapp-files/azure-netapp-files-performance-metrics-volumes#fio

- ディスクのベンチマークの実行

  なんかもういっこあった、こっちは `.ini` ファイルを書く感じ

  https://learn.microsoft.com/ja-jp/azure/virtual-machines/disks-benchmarks

- Sample FIO Commands for Block Volume Performance Tests on Linux-based Instances

  Oracle のページにも `fio` のサンプルがあるので参考にした

  https://docs.oracle.com/en-us/iaas/Content/Block/References/samplefiocommandslinux.htm

- クラウドでのネットワーク レイテンシの測定

  https://cloud.google.com/blog/ja/products/networking/using-netperf-and-ping-to-measure-network-latency

- fio 3.33 documentation

  最終的に当たるべきは公式 docs ですよね

  https://fio.readthedocs.io/en/latest/fio_doc.html

- Linux または Windows VM の NFS ボリュームをマウントする

  マウントの仕方のうち、`mount` コマンドの例は Azure Portal で出てくるけど、永続的な `/etc/fstab` の書き方については出てこないのでこちらを参考に

  https://learn.microsoft.com/ja-jp/azure/azure-netapp-files/azure-netapp-files-mount-unmount-volumes-for-virtual-machines
