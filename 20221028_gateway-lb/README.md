# Gateway Load Balancer

今回は Gateway Load Balancer の基本的な構成を試してみます。

# 構成のポイント

VXLAN と bridge の構成については参考のサイトを大いに参考にしています。

- VNet はふたつあります
  - VNet #1: ひとつに Standard Load Balancer + nginx の Azure VM
  - VNet #2: もうひとつに Gateway Load Balancer + VXLAN/bridge を構成した Azure VM
- VNet #1: NAT Gateway を作成します
  - 今試している感じだと Standard Load Balancer に Gateway Load Balancer を関連付けた状態で outbound に出ていかないような気がしているので NAT Gateway をつっくけています
- VNet #1: Public Standard Load Balancer を作る
  - その後ろに nginx をインストールした Azure VM を用意します
  - nginx の構成は cloud-init により自動化されています
  - この Azure VM にアクセスするため Azure Bastion を作成してあります
- VNet #2: Gateway Load Balancer を作る
  - その後ろに Azure VM を作成し、VXLAN と bridge の設定を適当に済ませます
  - 構成自体はせっかくなので clout-init で構成しています
  - この Azure VM にアクセスするため Azure Bastion を作成してあります
  - Standard Load Balancer の Public IP が Zone-Redundant な時に、Gateway Load Balancer の `frontendIPConfigurations` も Zone-Redundant にしないとどうもうまくいかないように見えます
    ```
    frontendIPConfigurations: [
        {
            name: fipc10Name
            zones: [ '1', '2', '3' ]
            properties: {
                privateIPAllocationMethod: 'Dynamic'
                subnet: { id: filter(vnet_hub10.properties.subnets, subnet => subnet.name == 'default')[0].id }
            }
        }
    ]
    ```

# 結果

Standard Load Balancer の Frontend IP configuration に関連づいている Public IP に HTTP でアクセスすると nginx のようこそ画面が出てきます。
それだけでは何も面白くはないですが、Gateway Load Balancer の後ろに配置した Azure VM で `tcpdump` すると中継しているパケットが見られます。

なんか cloud-init が失敗するケースがあるな？と思ったら先述の NAT Gateway を作成するようにしたら安定しました。
Gateway Load Balancer を関連付けていない状態で `outboundRules` していると `apt install` できるんですが、関連付けしてしまうとインターネットへと通信できなくなってしまうように見えます。

# 参考

- いつも参考になりますありがとうございます！！！

https://zenn.dev/openjny/articles/793fa510825a60

- VXLAN の構成についてはこちらが参考になります

https://zenn.dev/skmkzyk/articles/vxlan-cloud-init

- Azure Load Balancer の Bicep resource definition、結局参考にするのはここなのよ

https://learn.microsoft.com/en-us/azure/templates/microsoft.network/loadbalancers
