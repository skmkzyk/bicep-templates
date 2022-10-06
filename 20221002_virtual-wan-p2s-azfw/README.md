# P2S VPN for Azure Virtual WAN with Azure AD Authentication

Azure AD 認証を用いた P2S VPN を Azure Virtual WAN で利用する

# 構成のポイント

- Virtual WAN 関連のリソースを Bicep で作る、いろんなリソースを作る
- Secure hub にして Forced tunneling を有効化することで、P2S VPN で 0.0.0.0/0 が適用され、PC からインターネットに向かう通信も P2S VPN 経由にする
- シンプルにつないだだけだと 0.0.0.0/0 で吸い込めない可能性があり、その場合には規定のインターネット通信側の metric を手動で大きくする

# 結果

VPN 接続前、自宅のインターネット接続に紐づいた IP アドレスが表示される

```
PS C:\Users\xxxxxxxx> curl.exe https://ifconfig.me
217.178.x.x
```

VPN 接続後、Secure Hub に関連付いている Public IP アドレスが表示される

```
PS C:\Users\xxxxxxxx> curl.exe https://ifconfig.me
20.187.x.x
```
