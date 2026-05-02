# 後端元件搜尋 Rerank 規劃

## 目標

後端元件搜尋先用 Qdrant 拉出較大的候選集合，再用 TWCC Rerank API 依使用者查詢重新排序，最後維持原本 API 的 `limit` 作為回傳筆數。

## 流程

1. `GetComponentByQueryVector` 產生查詢向量。
2. 使用內部 `retrieval_top_k` 查詢 Qdrant，候選數量大於或等於 API 傳入的 `limit`。
3. 將候選元件補齊 `source`、`short_desc`、`long_desc`、`use_case` 與 dashboard target。
4. 將元件名稱、城市、描述與使用情境組成 rerank document。
5. 若 `TWCC_RERANK_MODEL` 是 chat model，使用 TWCC conversation API 做 LLM-as-reranker；否則先呼叫 TWCC `/models/rerank`，失敗時再退到 conversation rerank。
6. 用回傳的 `index` 對應回原候選元件。
7. 回傳 rerank 後的前 `limit` 筆；若 rerank 仍失敗，退回 Qdrant 原排序。

## 設定

- `TWCC_RERANK_ENABLED`：是否啟用 rerank，預設啟用。
- `TWCC_RERANK_MODEL`：TWCC rerank 模型名稱，預設沿用 `TWCC_MODEL`。
- `TWCC_RERANK_TOP_K`：Qdrant 初步檢索候選數量，預設 30。
- `TWCC_RERANK_TIMEOUT`：rerank API timeout 秒數，預設沿用 `TWCC_TIMEOUT`。

## 分數

回傳保留原本 `score` 欄位作為最終排序分數。啟用 rerank 時，`score` 會是 TWCC rerank score；同時新增 `vector_score` 保存原始 Qdrant 分數，`rerank_score` 保存 TWCC 分數，方便除錯與前端呈現。
