# bicep-templates

さまざまな込み入った環境を検証するにあたり、Bicep ファイルで IaC (Infrastructure as Code) の形で置いておくことでなるべく再現性を高めているものです。
一部の設定は OS の内部の設定があり、こちらについては完全に自動化はできておらず手動のものがあります。

# Disclaimer (免責事項)

これは私個人として公開しているものであり、何も責任を負うことはできませんのでご承知おきください。
また、**機能要件** 的な技術的な可否に重きを置いており、**非機能要件** 的な可用性や運用負荷についてはあまり考慮できていないことがあります。
必要に応じてインスタンスの数を増やしたり、負荷分散の仕組みを使いながら本番構成を検討いただければと思います。

なお、feedback は twitter ([@_skmkzyk](https://twitter.com/_skmkzyk)) などでどうぞ。

# parameter.json

各フォルダには本来 parameter.json があるのですが、こちらは環境固有の情報を多く含んでいるため Git に含めておりません。
サンプルが ![parameter-sample.json](./parameter-sample.json) にあるので見てみてください。
デプロイにあたり参照するリソース名やそのリソース グループの名前を入れる感じです。
ExpressRoute circuit については諸事情により承認キーを使う形にしています。
