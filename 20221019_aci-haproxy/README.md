# ACI で haproxy を動かして reverse proxy にする

ちょうどいいブログ記事が流れていたので、Azure Container Instance に慣れるついでの焼き直しです。
まだ Bicep ファイルがこなれていないのですがおいおい変えます。

# Azure Container Registry を作る

今回の deployment はどうしても順序があるので、まずは Azure Container Registry を作るための `main.bicep` を先に deploy します。

# Dockerfile を作る

同じ folder においてあるので見てください。

# haproxy.cfg を作る

同じ folder においてあるので見てください。

# WSL で docket image 作って pull する

以下 WSL 上での実行です。

まずは Azure Container Registry に login する必要があります。
さまざまなやり方がありますが、ここでは諸事情で id/password でログインします。
パスワードが平文で保存されているので気を付けてね、という message がでますので、気にしておいてください。

```shell
# az acr login -n acrxxxxxxxxxxxx -u acrxxxxxxxxxxxx
Password:
Login Succeeded
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store
```

`Dockerfile` および `haproxy.cfg` がある directory に移動し、`docker build` と `docker push` をたたきます。
これにより docker image が作成され、かつ Azure Container Registry に push されます。

```shell
# docker build . -t acrxxxxxxxxxxxx.azurecr.io/haproxysample1:v1
Sending build context to Docker daemon  13.82kB
Step 1/2 : FROM haproxy:2.3
 ---> 7ecd3fda00f4
Step 2/2 : COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
 ---> f88c5b5e2df1
Successfully built f88c5b5e2df1
Successfully tagged acrxxxxxxxxxxxx.azurecr.io/haproxysample1:v1

# docker push acrxxxxxxxxxxxx.azurecr.io/haproxysample1:v1
The push refers to repository [acrxxxxxxxxxxxx.azurecr.io/haproxysample1]
9695413ad4f1: Pushed
95d92b3c450e: Pushed
432ae7833e27: Pushed
85ff335ffae2: Pushed
87b571ab9f2c: Pushed
43b3c4e3001c: Pushed
v1: digest: sha256:4af038f9f6c3a54c1a2d4d6bff70aee136e8a0cd9253a34b03b362f1a764be37 size: 1569
```

# その他 resource を作成する

これで Azure Container Registry に docker image が push されましたので、これをもとに他のリソースを作成します。
VNet、Frontend/Backend の VM、Azure Container Instance などです。
こちらは `main02.bicep` を使って deploy します。

# 結果

Bastion から frontend の VM に入り、Azure Container Instance に割り当てられた Private IP に対して `curl http://<private-ip>/` と叩けば、バックエンドの Nginx のメッセージが出るはずです。

# 参考

- リバースプロキシとしてAzure Container InstancesにHaproxyを導入してみる

https://level69.net/archives/28979
