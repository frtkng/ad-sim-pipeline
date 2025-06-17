# E2E‑AI CICT (Continuous Integration & Continuous Training)

---

## 1. 目的

自動運転シミュレータ **CARLA** を中心に、機械学習モデルの学習 ➜ シミュレーション ➜ 評価 ➜ 必要に応じて再学習 (re‑train) までを **完全自動化** する DevOps パイプラインのモックアップを構築します。


| 項目    | 内容                                                                        |
| ----- | ------------------------------------------------------------------------- |
| 主な利用者 | 研究開発者・ML エンジニア・MLOps エンジニア                                                |
| 主眼    | カスタム GPU ノードを持つ Amazon EKS 上で効率的に CARLA を動かしつつ、GitHub Actions で CI/CD を管理 |
| 成果物   | - 学習済みモデル (S3)                                                            |

* 走行ログ・評価結果 (S3)
* IaC (Terraform) によるインフラ再現性 |

---

## 2. 全体構成図

```
┌──────────────┐      push / dispatch        ┌────────────────────┐
│  Developer   │ ───────────────────────────▶ │ GitHub Actions CI  │
└──────────────┘                             │  (train / sim /   │
                                              │   evaluate loop)  │
                                              └────────┬─────────┘
                                                       │kubectl
                                               aws eks│
                                                       ▼
                       ┌────────────────────────────────────────────────┐
                       │                 Amazon EKS                    │
                       │ ┌────────────────────┐  ┌───────────────────┐ │
                       │ │ cpu‑nodes (t3)     │  │ gpu‑nodes (g5)    │ │
                       │ └────────────────────┘  └───────────────────┘ │
                       └──────────────┬────────────────────────────────┘
                                      │
                                      ▼        model / logs
                               ┌────────────┐  S3
                               │  CARLA     │◀──────────┐
                               │  container │            │
                               └────────────┘            │
                                                         │
Infrastructure as Code (Terraform) ───▶ VPC / Subnets / NAT / SG / KMS / DynamoDB‑lock / S3‑state
```

> **補足** : EKS ノードグループは `role=gpu` と `role=cpu` でラベルを分離。CARLA Pod には GPU ノードを優先的にスケジューリングする taint/selector を設定します。

---

## 3. リポジトリ構成

```
.
├── terraform/           # VPC, EKS, S3, KMS … すべて IaC
│   ├── main.tf
│   ├── variables.tf
│   └── …
├── scripts/
│   ├── setup_infra.sh   # <== インフラ初期化ワンショット
│   ├── train.sh         # モデル学習 (GPU)
│   ├── simulate.sh      # CARLA シミュレーション (GPU)
│   └── evaluate.sh      # 評価 & NG 抽出 (CPU)
├── .github/workflows/
│   └── ci-pipeline.yaml # GitHub Actions パイプライン定義
└── README.md            # ← これ
```

---

## 4. 前提ソフトウェア

| Tool      | Version (目安) | 用途                   |
| --------- | ------------ | -------------------- |
| Terraform | ≥ 1.6        | IaC                  |
| AWS CLI   | ≥ 2.x        | スクリプト & Actions      |
| kubectl   | ≥ 1.30       | EKS 操作               |
| gh CLI    | ≥ 2.x        | workflow 再起動 (retry) |

---

## 5. デプロイ手順

1. **AWS 側準備**

   * IAM ロールを作成し、GitHub OIDC を信頼。最小権限 (例: EKS, EC2, S3, KMS, DynamoDB, IAM 軽量) を付与。
   * `AWS_ROLE` を GitHub Secrets に登録。
2. **ローカル環境**

   ```bash
   git clone <this‑repo>
   cd <repo>
   # Terraform backend & key‑pair 作成を含む
   bash scripts/setup_infra.sh           # or ./scripts/setup_infra.sh <aws‑profile>
   ```
3. **GitHub Secrets**
   スクリプト実行後に表示される下記 3 つをリポジトリ Secrets に追加。

   * `MODEL_BUCKET`  (例: e2e-ai-model-store-dev)
   * `CLUSTER_NAME`  (例: e2e-ai-cluster-dev)
   * `AWS_ROLE`      (手動設定済みの IAM ロール ARN)
4. **パイプライン実行**

   * `main` ブランチへ push → 自動トリガー
   * `Actions › E2E‑AI CICT Pipeline › Run workflow` から手動で再学習 (`retrain=true`) やリトライ回数を指定して実行も可。

---

## 6. Terraform 主要変数

| 変数             | デフォルト            | 説明                            |
| -------------- | ---------------- | ----------------------------- |
| `env`          | `dev`            | 環境プレフィックス (dev / stg / prd 等) |
| `ec2_key`      | `e2e-ai-dev-key` | EC2 キーペア名 (スクリプトで自動生成)        |
| `gpu_instance` | `g5.xlarge`      | GPU ノードインスタンスタイプ              |
| `cpu_instance` | `t3.medium`      | CPU ノードインスタンスタイプ              |
| `gpu_desired`  | `1`              | GPU ノード desired size          |
| `cpu_desired`  | `1`              | CPU ノード desired size          |

---

## 7. GitHub Actions — ワークフローフロー

| ジョブ                   | 実行ランナー                          | 概要                                                    | 備考                 |
| --------------------- | ------------------------------- | ----------------------------------------------------- | ------------------ |
| **train**             | GitHub Hosted (`ubuntu‑latest`) | SageMaker などを使わず、EKS GPU ノード上で model 学習               | `scripts/train.sh` |
| **simulate**          | 同上                              | CARLA シミュレーション Pod をデプロイし走行ログ取得                       | 結果を S3 へアップロード     |
| **evaluate\_retrain** | 同上                              | Python スクリプトで評価; NG >0 なら `gh workflow dispatch` で再実行 | 3 回までリトライ          |

> **CARLA Pod のスケジューリング** :
>
> ```yaml
> nodeSelector:
>   role: gpu
> tolerations:
>   - key: node.kubernetes.io/gpu
>     value: "true"
>     effect: NoSchedule
> ```

---

## 8. コスト最適化のヒント

* **最小 1 GPU + 1 CPU** で必要十分な構成。不要時は `desired_size=0` にして `terraform apply` で停止可。
* GPU インスタンスを **Spot** に切り替える場合は `capacity_type = "SPOT"` と `spot_price` 上限を設定。
* **CloudWatch Logs** は長期保存しない場合、 retention を短めに設定。

---

## 9. よくある質問 (FAQ)

| Q                              | A                                                                                             |
| ------------------------------ | --------------------------------------------------------------------------------------------- |
| Cluster 作成が遅い                  | VPC Endpoint なしの場合、AMI 取得で数分、Node Group でさらに 10+ 分かかることがあります。CloudFormation イベントで進捗を確認してください。 |
| `Fleet Request quota exceeded` | GPU や最新世代 G 系を同時に複数 Launch すると EC2 Fleet 制限に当たります。`max_size=1` で回避し、必要なら AWS サポートへ制限緩和申請を。    |
| `acl is deprecated` warning    | `aws_s3_bucket_acl` へリファクタ予定です (機能的問題はありません)。                                                 |

---

## 10. ライセンス

Apache‑2.0

CARLA® は Carla Team の登録商標です。本プロジェクトは非公式の連携例であり、各ライセンスに従ってご利用ください。
