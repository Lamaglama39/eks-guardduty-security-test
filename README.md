# EKS GuardDuty Security Test Infrastructure

このプロジェクトは、Amazon GuardDuty for EKSの全検知機能をテストするための完全なインフラストラクチャとテストスクリプトを提供します。  
TerraformでAWSインフラを構築し、実際の攻撃シナリオを模倣したテストを実行できます。

GuardDuty EKS Protection、Runtime Monitoring、  
およびAttack Sequence（拡張脅威検知）の各種検知タイプを意図的にトリガーし、監視機能の動作を検証します。

## ⚠️免責事項⚠️

1. **テスト環境での実行**: 本番環境では実行しないでください
2. **セキュリティアラート**: GuardDutyで複数のHigh重要度アラートが発生します
3. **実際のマルウェア**: テストでは実際の暗号通貨マイナーをダウンロード・実行します
4. **ネットワーク通信**: 外部の暗号通貨関連ドメイン・サーバーに接続します
5. **費用**: 作成するリソースに応じて利用料金が発生します
6. **法的考慮**: 暗号通貨マイニングが制限されている環境では使用しないでください

**このプロジェクトは自己責任でご使用ください。**

- このテストツールの使用により生じたいかなる損害、費用、法的問題、セキュリティインシデントについて、作成者は一切の責任を負いません
- 使用者は自身の責任とリスクにおいて本ツールを利用することに同意するものとします
- 組織や企業で使用する場合は、事前に必ず承認を得てください
- 発生したAWS利用料金については使用者が責任を負います

## 検知対象

#### EKS Protection検知
- `Policy:Kubernetes/AdminAccessToDefaultServiceAccount`
- `Policy:Kubernetes/AnonymousAccessGranted`

#### Runtime Monitoring検知
- `Impact:Runtime/CryptoMinerExecuted`
- `CryptoCurrency:Runtime/BitcoinTool.B`
- `CryptoCurrency:Runtime/BitcoinTool.B!DNS`

#### EC2  検知
- `CryptoCurrency:EC2/BitcoinTool.B`
- `CryptoCurrency:EC2/BitcoinTool.B!DNS`

#### Attack Sequence検知（拡張脅威検知）
- `AttackSequence:EKS/CompromisedCluster`

## 実行フロー

**Phase 0-6攻撃シーケンス**（15-20分実行）:

**Phase 0: Cleanup and Setup**
- 既存のリソース削除
- テスト環境の初期化

**Phase 1: Anonymous Access Policy Configuration**
- 匿名アクセス権限の設定
- `Policy:Kubernetes/AnonymousAccessGranted`検知をトリガー

**Phase 2: Default Service Account Admin Access**
- デフォルトサービスアカウントへの管理者権限付与
- `Policy:Kubernetes/AdminAccessToDefaultServiceAccount`検知をトリガー

**Phase 3: Enhanced Service Account and Privileged Workload**
- 特権付きサービスアカウント作成
- Privileged Containerの展開
- ホストレベルアクセス権限の設定

**Phase 4: Malware Deployment**
- 実際のXMRig暗号通貨マイナーのダウンロード
- 複数の場所への配置
- `Execution:Kubernetes/MaliciousFile`検知をトリガー

**Phase 5: Cryptocurrency DNS Queries**
- 暗号通貨関連ドメインへのDNSクエリ実行
- `CryptoCurrency:Runtime/BitcoinTool.B!DNS`検知をトリガー

**Phase 6: Cryptocurrency Mining Execution**
- XMRigプロセスの実際の実行
- 複数のマイニングプールへの接続試行
- `Impact:Runtime/CryptoMinerExecuted`と`CryptoCurrency:Runtime/BitcoinTool.B`検知をトリガー
- テスト完了から一定時間経過後に、`AttackSequence:EKS/CompromisedCluster` を検知

## 前提条件

### AWS環境
1. **AWS認証情報**
   - AWS CLI設定済み（`aws configure`）
   - AWS資格情報ファイルまたは環境変数

2. **必要な権限**
   - VPC、サブネット、IGW、NAT Gateway作成権限
   - EKSクラスター・ノードグループ作成権限
   - IAMロール・ポリシー作成権限
   - GuardDuty設定変更権限
   - VPCエンドポイント作成権限

### ローカル環境
3. **必要なツール**
   - Terraform
   - kubectl
   - AWS CLI
   - bash

## 使用方法

### 1. インフラストラクチャ デプロイ

```bash
cd terraform;
terraform init;
terraform plan;
terraform apply;
```

### 2. kubectl設定

```bash
aws eks update-kubeconfig --region ap-northeast-1 --name guardduty-eks;
```
```bash
kubectl get nodes;
```

### 3. テストスクリプトに実行権限を付与

```bash
cd ../scripts;
chmod +x extended-threat-detection-test.sh;
```

### 4. テスト実行

```bash
./extended-threat-detection-test.sh
```

- おおよその検出時間について
  - **数分-10分後**: EKS Protection検知は数分以内
  - **数分-10分後**: Runtime Monitoring検知
  - **10-30分後**: Attack Sequence（関連する複数の検知をまとめた脅威分析）

### 5. テスト結果の確認

1. **AWS GuardDutyコンソール**にアクセス
2. **Findings**セクションで検知結果を確認
3. **Attack Sequence**タブで関連する攻撃の時系列を確認

### 6. クリーンアップ

```bash
cd ../terraform;
terraform destroy;
```

## 作成されるリソース

### ネットワーク構成
- **VPC**: 10.0.0.0/16 CIDR
- **Public Subnets**: 2つのAZ（10.0.1.0/24, 10.0.2.0/24）
- **Private Subnets**: 2つのAZ（10.0.10.0/24, 10.0.11.0/24）
- **NAT Gateways**: 各パブリックサブネットに配置
- **VPCエンドポイント**: GuardDuty、ECR、EKS、S3、CloudWatch等

### EKS構成
- **Cluster Version**: 1.33
- **Node Group**: 2ノード、t3.medium
- **Addons**: VPC-CNI、CoreDNS、kube-proxy、EBS CSI Driver
- **Logging**: API、audit、authenticator、controllerManager、scheduler

### GuardDuty設定
- **EKS Protection**: 有効（EKS_AUDIT_LOGS）
- **Runtime Monitoring**: 有効（EKS_ADDON_MANAGEMENT）
- **Finding Frequency**: 6時間間隔
- **Agent Management**: ECS/EC2は無効、EKSのみ有効

## 参考資料

- [Amazon GuardDuty EKS Protection](https://docs.aws.amazon.com/guardduty/latest/ug/kubernetes-protection.html)
- [GuardDuty Runtime Monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring.html)
- [GuardDuty Attack Sequence Detection](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-extended-threat-detection.html) 🆕
