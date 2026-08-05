# Product

## Register

product

## Platform

macOS

## Users

ローカル開発中に、どのサービスがどのTCPポートをLISTENしているかを短時間で確認したいmacOSのソフトウェア開発者。Terminalへ移動せず、ネイティブプロセスとDocker Composeサービスを同じ一覧で確認・操作する。

## Product Purpose

Mac上のLISTENポート、所有プロセス、推定サービス、Dockerの公開ポートを一つのメニューバーパネルに統合する。通常は数秒で状況を把握でき、問題時には詳細確認や安全な停止操作へ進めることを成功条件とする。

## Positioning

ローカル開発サービスの所在を、プロセスとコンテナの違いをまたいで一目で把握できるmacOSネイティブ港湾案内板。

## Brand Personality

静か、精密、信頼できる。港の比喩はコピーと少数のSF Symbolsに留め、Apple純正の開発者向けユーティリティに近い操作感を優先する。

## Anti-references

派手なブランドロゴ、常時アニメーション、色でしか意味が伝わらない状態表示、巨大なカード、Webダッシュボード風の過剰な装飾、ターミナル出力をそのまま見せる画面。

## Design Principles

- 3秒以内にポート番号、サービス名、所有主体を走査できる。
- Docker障害をポート監視全体の障害へ波及させない。
- 危険操作は日常操作から分離し、対象を直前に再検証する。
- macOS標準のMaterial、タイポグラフィ、操作部品を優先する。
- 推測と確定情報を混同せず、曖昧なDocker対応は候補として示す。

## Accessibility & Inclusion

Dynamic Type、キーボード操作、VoiceOverラベル、Reduce Motion、light/dark modeへ対応する。状態は色に加えてアイコンとテキストでも表現する。
