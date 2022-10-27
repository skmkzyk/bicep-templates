# Configure IIS with ARR as alternative for Application Gateway

IIS の ARR を使えば簡単な reverse proxy は構成できますよという話です。

# 構成のポイント

## vm-certbot01

この Azure VM は certbot を動かすために使います。
いくつかのやり方がありますが、ここでは dns-01 を使ったやり方にしています、なんとなく。
コマンドを途中で止め、指定された TXT レコードを登録します。
そのあと、コマンドを再開し、うまくいけば証明書が保存されます。

```
sudo certbot certonly --manual -w /var/www/html -d iis.example.jp --preferred-challenges dns
```

やり方は何でもいいのですが、取得した証明書は Windows Server 側で利用します。

## vm-backiis01、vm-backiis02

バックエンドとなる vm-backiis01 と vm-backiis02 では、IIS の機能を有効化します。
そのうえで、証明書を import、binding から HTTPS を有効化し該当の証明書を関連付けます。
なお、この作業において、Standard LB 配下の Azure VM は規定でインターネットに通信できないという制限から、証明書の関連付けの際には少し画面が固まったように見えます。
問題はありませんので、ゆっくり作業いただければと思います。

## vm-frontiis01

この Azure VM でも証明書の import と binding の有効化をまず済ませます。

次に、ARR を有効化し、reverse proxy の役割を持たせます。
以下の URL から .exe をダウンロードし ARR をインストールします。

https://www.iis.net/downloads/microsoft/application-request-routing

そのうえで、適当に設定しておきます。

なお、このマシンから Standard LB の IP アドレス向けに hosts を書いておきます。
そのうえで、ブラウザから該当の URL にアクセスし、問題なくアクセスできることを確認しておきます。

## vm-client01

このマシンは client 相当です。
宛先を vm-frontiis01 とした hosts を書き、うまくいけば通信ができるはずです。
