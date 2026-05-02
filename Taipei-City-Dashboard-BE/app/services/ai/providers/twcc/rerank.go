package twcc

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"

	"github.com/tmc/langchaingo/llms"
)

type RerankResult struct {
	Index int     `json:"index"`
	Score float64 `json:"score"`
}

type rerankRequest struct {
	Model      string           `json:"model"`
	Query      string           `json:"query"`
	Documents  []string         `json:"documents"`
	Parameters rerankParameters `json:"parameters,omitempty"`
}

type rerankParameters struct {
	TopN int `json:"top_n,omitempty"`
}

type rerankResponse struct {
	Results []RerankResult `json:"results"`
	Scores  []float64      `json:"scores"`
}

type conversationRerankDocument struct {
	Index int    `json:"index"`
	Text  string `json:"text"`
}

func (m *TWCC) Rerank(ctx context.Context, query string, documents []string, topN int) ([]RerankResult, error) {
	if query == "" {
		return nil, fmt.Errorf("query is required")
	}
	if len(documents) == 0 {
		return nil, fmt.Errorf("documents are required")
	}
	if topN <= 0 || topN > len(documents) {
		topN = len(documents)
	}

	reqBody := rerankRequest{
		Model:     m.ModelName,
		Query:     query,
		Documents: documents,
		Parameters: rerankParameters{
			TopN: topN,
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal rerank request: %w", err)
	}

	endpoint := fmt.Sprintf("%s/models/rerank", m.BaseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("failed to create rerank request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-KEY", m.APIKey)

	resp, err := m.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send rerank request to TWCC: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read rerank response: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("TWCC rerank API returned error status %d: %s", resp.StatusCode, string(respBody))
	}

	var parsed rerankResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return nil, fmt.Errorf("failed to decode rerank response: %w", err)
	}
	if len(parsed.Results) > 0 {
		return parsed.Results, nil
	}
	if len(parsed.Scores) > 0 {
		results := make([]RerankResult, 0, len(parsed.Scores))
		for i, score := range parsed.Scores {
			results = append(results, RerankResult{Index: i, Score: score})
		}
		sort.SliceStable(results, func(i, j int) bool {
			return results[i].Score > results[j].Score
		})
		if len(results) > topN {
			results = results[:topN]
		}
		return results, nil
	}

	return nil, fmt.Errorf("TWCC rerank response has no results")
}

func (m *TWCC) RerankWithConversation(ctx context.Context, query string, documents []string, topN int) ([]RerankResult, error) {
	if query == "" {
		return nil, fmt.Errorf("query is required")
	}
	if len(documents) == 0 {
		return nil, fmt.Errorf("documents are required")
	}
	if topN <= 0 || topN > len(documents) {
		topN = len(documents)
	}

	indexedDocuments := make([]conversationRerankDocument, 0, len(documents))
	for i, document := range documents {
		indexedDocuments = append(indexedDocuments, conversationRerankDocument{
			Index: i,
			Text:  document,
		})
	}

	docsJSON, err := json.Marshal(indexedDocuments)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal conversation rerank documents: %w", err)
	}

	prompt := fmt.Sprintf(`你是搜尋系統的 reranker。請根據 query 評估每個 document 與使用者需求的相關性。

規則：
- 只回傳 JSON，不要使用 Markdown code fence。
- 回傳格式必須是 {"results":[{"index":0,"score":0.0}]}。
- index 必須使用輸入 document 的 index。
- score 是 0 到 1 的相關性分數，越高越相關。
- 只回傳前 %d 名，依 score 由高到低排序。
- 不要新增不存在的 index。

query:
%s

documents:
%s`, topN, query, string(docsJSON))

	content, err := m.Call(ctx, prompt,
		llms.WithMetadata(map[string]interface{}{
			"temperature":    0.01,
			"max_new_tokens": 512,
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("conversation rerank request failed: %w", err)
	}

	results, err := parseConversationRerankResults(content, topN)
	if err != nil {
		return nil, err
	}

	validResults := make([]RerankResult, 0, len(results))
	seen := make(map[int]bool, len(results))
	for _, result := range results {
		if result.Index < 0 || result.Index >= len(documents) || seen[result.Index] {
			continue
		}
		if result.Score < 0 {
			result.Score = 0
		}
		if result.Score > 1 {
			result.Score = 1
		}
		validResults = append(validResults, result)
		seen[result.Index] = true
	}
	if len(validResults) == 0 {
		return nil, fmt.Errorf("conversation rerank returned no valid results")
	}

	sort.SliceStable(validResults, func(i, j int) bool {
		return validResults[i].Score > validResults[j].Score
	})
	if len(validResults) > topN {
		validResults = validResults[:topN]
	}

	return validResults, nil
}

func parseConversationRerankResults(content string, topN int) ([]RerankResult, error) {
	cleaned := extractJSONObject(content)

	var objectResponse struct {
		Results []RerankResult `json:"results"`
	}
	if err := json.Unmarshal([]byte(cleaned), &objectResponse); err == nil && len(objectResponse.Results) > 0 {
		return objectResponse.Results, nil
	}

	var arrayResponse []RerankResult
	if err := json.Unmarshal([]byte(cleaned), &arrayResponse); err == nil && len(arrayResponse) > 0 {
		return arrayResponse, nil
	}

	return nil, fmt.Errorf("failed to parse conversation rerank JSON: %s", content)
}

func extractJSONObject(content string) string {
	cleaned := strings.TrimSpace(content)
	cleaned = strings.TrimPrefix(cleaned, "```json")
	cleaned = strings.TrimPrefix(cleaned, "```")
	cleaned = strings.TrimSuffix(cleaned, "```")
	cleaned = strings.TrimSpace(cleaned)

	objectStart := strings.Index(cleaned, "{")
	objectEnd := strings.LastIndex(cleaned, "}")
	if objectStart >= 0 && objectEnd > objectStart {
		return cleaned[objectStart : objectEnd+1]
	}

	arrayStart := strings.Index(cleaned, "[")
	arrayEnd := strings.LastIndex(cleaned, "]")
	if arrayStart >= 0 && arrayEnd > arrayStart {
		return cleaned[arrayStart : arrayEnd+1]
	}

	return cleaned
}
