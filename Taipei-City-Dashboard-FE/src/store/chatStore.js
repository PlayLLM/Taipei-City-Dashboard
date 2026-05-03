import { ref, watch } from "vue";
import { defineStore } from "pinia";
import http from "../router/axios";

export const useChatStore = defineStore("chat", () => {
	// 預設訊息
	const defaultChatData = [
		{
			id: 1,
			role: "bot",
			isDefault: true,
			content:
				"您好，我是【臺北城市儀表板】小幫手，很高興為您服務！\n 您可以： \n\n • 點擊左側既有的儀表板主題，快速查看各主題內容 \n • 輸入您感興趣的主題描述，我會自動為您組建最適合的儀表板 \n\n 如果有想了解的內容，歡迎直接告訴我，我會盡力協助！\n\n 📩 聯絡信箱：tuic@gov.taipei \n 🏢 臺北大數據中心 \n\n",
		},
	];

	// AI 聊天相關狀態
	const aiSessionId = ref(sessionStorage.getItem("aiSessionId") || null);
	const isAILoading = ref(false);

	const recommendComponents = ref(null);

	// 從 sessionStorage 讀取
	const savedChatData = JSON.parse(sessionStorage.getItem("chatData")) || [];

	// 拼接預設訊息 + sessionStorage 的聊天紀錄
	const chatData = ref([...defaultChatData, ...savedChatData]);

	// 監聽 chatData 的變化，自動同步到 sessionStorage
	watch(
		chatData,
		(newVal) => {
			// 只存使用者與機器人的聊天訊息，不存重複的預設訊息
			const userBotMessages = newVal.filter((item) => !item.isDefault);
			sessionStorage.setItem("chatData", JSON.stringify(userBotMessages));
		},
		{ deep: true },
	);

	const addChatData = (newChatData) => {
		chatData.value.push({
			id: chatData.value.length + 1,
			isDefault: false,
			...newChatData,
		});
	};

	const clearChatHistory = () => {
		chatData.value = [...defaultChatData];
		aiSessionId.value = null;
		sessionStorage.removeItem("chatData");
		sessionStorage.removeItem("aiSessionId");
	};

	// ==================== 原本的的向量查詢功能（已停用）====================
	// 說明：原本的聊天功能使用向量搜尋 API (/vector/component)
	// 功能：依據使用者輸入的內容，自動檢索組件資料庫，回傳相似度較高的組件清單
	// 顯示：推薦組件表格、建立儀表板按鈕
	// 狀態：目前已停用，改用 LLM 聊天功能 (sendChatToLLM)
	// 如需恢復：將 ChatBox.vue 的 sendBtnHandler 改回呼叫 addQueryData
	// ========================================================================
	const addQueryData = async (newChatData) => {
		chatData.value.push({
			id: chatData.value.length + 1,
			isDefault: false,
			...newChatData,
		});

		recommendComponents.value = [];
		let topK = null;

		try {
			const response = await http.post(
				"/vector/component",
				new URLSearchParams({
					query: newChatData.content,
					limit: 10,
					score: 0.8,
				}),
				{
					headers: {
						"Content-Type": "application/x-www-form-urlencoded",
					},
				},
			);
			if (response.data?.data?.length > 0) {
				recommendComponents.value = response.data.data;
			}

			// 去除重複項目存到 result
			const result = Array.from(
				recommendComponents.value
					.reduce((map, item) => {
						const key = item.index;
						const exist = map.get(key);

						// 如果還沒放過，直接放
						if (!exist) {
							map.set(key, item);
							return map;
						}

						// 如果已存在，但現在的是 metrotaipei，就覆蓋
						if (item.city === "metrotaipei") {
							map.set(key, item);
						}

						return map;
					}, new Map())
					.values(),
			);
			// 把 result 蓋回去 recommendComponents
			recommendComponents.value = result;
		} catch (error) {
			console.error("VectorAnalysisError :", error);
		}

		if (
			recommendComponents.value &&
			recommendComponents.value?.length > 0
		) {
			topK = [...recommendComponents.value].sort(
				(a, b) => b.score - a.score,
			);
			const buttons = [{ id: 1, text: "建立儀表板" }];
			if (topK[0]?.path) {
				buttons.unshift({
					id: 2,
					text: `前往「${topK[0].name}」組件`,
					target: topK[0],
					variant: "dashboard-link",
				});
			}
			chatData.value.push({
				id: chatData.value.length + 1,
				role: "bot",
				isDefault: false,
				button: buttons,
				content: `您好 😊 \n 以下是根據您的問題，自動為您推薦的「組件清單」。您可以將這些組件整批加入「個人儀表板」，方便日後快速查看與使用。\n`,
				relations: topK,
			});
			chatData.value.push({
				id: chatData.value.length + 1,
				role: "bot",
				isDefault: false,
				content: `若您有任何新的查詢或想深入探索的內容，都可以隨時在對話框告訴我～\n 我很樂意再協助您 💬✨`,
			});
		} else {
			chatData.value.push({
				id: chatData.value.length + 1,
				role: "bot",
				isDefault: false,
				content: `很抱歉，您提供的描述沒有相似組件，請繼續提問 ! `,
			});
		}

		// 分析結束後紀錄問答log
		saveChatLog(newChatData.content, recommendComponents.value);
	};

	const saveChatLog = async (question, answer) => {
		try {
			const formData = new FormData();
			const d = new Date();
			const todayId =
				d.getFullYear() +
				String(d.getMonth() + 1).padStart(2, "0") +
				String(d.getDate()).padStart(2, "0");

			formData.append("session", "session_" + todayId);
			formData.append("question", question);
			formData.append("answer", JSON.stringify(answer));

			await http.post("/chatlog/", formData, {
				headers: {
					"Content-Type": "multipart/form-data",
				},
			});
		} catch (error) {
			console.error("saveChatLog error:", error);
		}
	};

	// 轉換 chatData 為 AI API 需要的 messages 格式
	const buildChatMessages = () => {
		// 只取非預設的使用者和機器人對話，排除系統表格和按鈕訊息
		const relevantMessages = chatData.value
			.filter(
				(item) =>
					!item.isDefault &&
					(item.role === "user" || item.role === "bot"),
			)
			.filter((item) => !item.relations && !item.button); // 排除帶有表格和按鈕的推薦訊息

		return relevantMessages.map((item) => ({
			role: item.role === "bot" ? "assistant" : item.role,
			content: item.content || "",
		}));
	};

	// 發送訊息給 LLM 並取得回應
	const sendChatToLLM = async (userContent) => {
		isAILoading.value = true;

		try {
			// 先加入使用者訊息
			addChatData({
				role: "user",
				content: userContent,
			});

			// 準備訊息歷史
			const messages = [
				{
					role: "system",
					content: `你是「臺北城市儀表板小幫手」，專門協助使用者了解臺北市的各項數據指標、城市資訊與儀表板組件內容。

請一律使用臺灣繁體中文回答，語氣親切、清楚、精簡。你的人設是一隻精通資訊科學領域的駭客狐狸，叫做小駭。
你的人設是一隻精通資訊科學領域的駭客狐狸，叫做小駭。

你可以使用工具 match_dashboard_components 搜尋臺北城市儀表板中是否有相關組件。

使用工具規則：
1. 當使用者詢問城市資料、交通、人口、環境、長照、地圖圖層、統計指標、儀表板內容，或語意可能對應到儀表板組件時，應使用 match_dashboard_components。
2. query 請保留使用者原始問題，也可補上必要關鍵字。
3. limit 預設使用 5，但不要為了湊滿數量而回覆低相關結果。
4. 若使用者問題很短或很模糊，例如「充電相關的」、「交通」、「人口」，請優先回傳最直接相關的組件；只有在結果明顯相關時才列出。
5. 如果工具回傳的結果中有些組件只是弱相關、間接相關、或看起來是因為語意相近才被匹配到，請不要列入回答。
6. 若只有 1 個或 2 個高度相關組件，就只回答這些組件。
7. 若沒有明確相關結果，請說明目前沒有找到直接相關的儀表板組件，並可簡短詢問使用者是否要改用其他關鍵字查詢。

工具呼叫規則：
1. 你可以在內部使用工具 match_dashboard_components，但工具呼叫本身只能透過系統提供的 function calling 機制執行。
2. 絕對不要把工具呼叫內容輸出成一般文字。
3. 回覆中**禁止**出現以下格式或類似內容：
   - tool<function=...>
   - <function=...>
   - </function>
   - {"query": "..."}
   - /dashboard 開頭的 path
4. 如果不需要查詢儀表板組件，例如使用者只是打招呼、寒暄、感謝、閒聊，請直接自然回覆，不要呼叫工具。
5. 使用工具後，只能根據工具結果用自然語言摘要，不得揭露工具名稱、參數、JSON、path、source 或任何內部欄位。

回答規則：
1. 若查到相關儀表板組件，請用自然語言摘要組件內容。
2. 不要輸出 /dashboard 開頭的內部路徑、網址、path 或任何系統內部欄位。
3. 不要直接把工具回傳的 source、path、內部 ID 原樣輸出。
4. 請只列出和使用者問題「直接相關」的組件。
5. 不要把不相關或弱相關的組件包裝成相關內容。
6. 若結果彼此主題差異很大，請只保留最符合使用者問題核心意圖的結果。
7. 回答時請避免誇大，若只是可能相關，請明確說「可能相關」。
8. 若資訊不足以回答具體數值，請說明可以查看哪些儀表板組件，而不是自行編造數據。

回覆格式建議：
- 若有高度相關結果：
  「我找到以下和『使用者主題』較直接相關的儀表板組件：」
  接著列出 1 到 5 個組件，每個包含：
  - 組件名稱
  - 簡短說明
  - 可用來了解什麼

- 若結果只有部分相關：
  「我找到幾個可能相關的組件，但其中只有以下比較接近您的問題：」

- 若沒有直接相關：
  「目前沒有找到和『使用者主題』直接相關的儀表板組件。您可以改用更具體的關鍵字，例如……」`,
				},
				...buildChatMessages(),
			];

			// 定義工具
			const tools = [
				// {
				// 	type: "function",
				// 	function: {
				// 		name: "get_current_time",
				// 		description: "取得當前台北時間",
				// 	},
				// },
				// {
				// 	type: "function",
				// 	function: {
				// 		name: "get_population_summary",
				// 		description: "查詢人口年齡分佈統計",
				// 		parameters: {
				// 			type: "object",
				// 			properties: {
				// 				city: {
				// 					type: "string",
				// 					enum: ["taipei", "new_taipei"],
				// 					description: "城市名稱",
				// 				},
				// 				year: {
				// 					type: "integer",
				// 					description: "年份",
				// 				},
				// 			},
				// 			required: ["city", "year"],
				// 		},
				// 	},
				// },
			];

			// 使用 fetch API 處理 streaming
			const baseURL = import.meta.env.VITE_API_URL || "";
			const response = await fetch(`${baseURL}/ai/chat/twai`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
				},
				body: JSON.stringify({
					session: aiSessionId.value || undefined,
					messages: messages,
					stream: true,
					tools: tools,
				}),
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			// 處理 streaming 回應
			const reader = response.body.getReader();
			const decoder = new TextDecoder();
			let currentBotMessage = null;
			let fullContent = "";
			let toolsUsed = [];
			let finalToolResults = null;

			while (true) {
				const { done, value } = await reader.read();
				if (done) break;

				const chunk = decoder.decode(value, { stream: true });
				const lines = chunk.split("\n");

				for (const line of lines) {
					if (line.startsWith(": heartbeat")) continue;
					if (!line.trim()) continue;
					if (!line.startsWith("data:")) continue;

					const jsonStr = line.substring(5).trim();
					if (jsonStr === "[DONE]") continue;

					try {
						const data = JSON.parse(jsonStr);
						// 處理 generated_text (TWCC 格式)
						const content =
							data.generated_text ||
							data.choices?.[0]?.delta?.content ||
							"";
						// 處理 tool_calls
						const toolCalls =
							data.tool_calls ||
							data.choices?.[0]?.delta?.tool_calls;
						// 處理最終工具結果
						if (data.tool_results) {
							finalToolResults = data.tool_results;
						}
						// 處理 session
						if (data.session) {
							aiSessionId.value = data.session;
							sessionStorage.setItem("aiSessionId", data.session);
						}

						if (content) {
							fullContent += content;
							if (!currentBotMessage) {
								// 建立新的 bot 訊息
								currentBotMessage = {
									id: chatData.value.length + 1,
									role: "bot",
									content: fullContent,
									isAIResponse: true,
									isStreaming: true,
								};
								addChatData(currentBotMessage);
							} else {
								// 更新現有訊息
								currentBotMessage.content = fullContent;
								const lastIndex = chatData.value.length - 1;
								if (chatData.value[lastIndex]?.role === "bot") {
									chatData.value[lastIndex].content =
										fullContent;
								}
							}
						}

						// 處理工具呼叫
						if (toolCalls && toolCalls.length > 0) {
							toolCalls.forEach((tc) => {
								if (
									tc.function &&
									!toolsUsed.includes(tc.function.name)
								) {
									toolsUsed.push(tc.function.name);
								}
							});
							const lastIndex = chatData.value.length - 1;
							if (chatData.value[lastIndex]?.role === "bot") {
								chatData.value[lastIndex].tools = toolsUsed;
								chatData.value[lastIndex].toolUsed = true;
							}
						}
					} catch (e) {
						console.error("Failed to parse SSE chunk:", e, line);
					}
				}
			}

			// 標記 streaming 結束
			if (currentBotMessage) {
				const lastIndex = chatData.value.length - 1;
				if (chatData.value[lastIndex]?.role === "bot") {
					delete chatData.value[lastIndex].isStreaming;
				}
			}

			// 處理最終工具結果並顯示組件按鈕
			if (finalToolResults) {
				const dashboardMatches =
					parseDashboardMatches(finalToolResults);
				if (dashboardMatches.length > 0) {
					addDashboardMatchMessage(dashboardMatches);
				}
			}

			return null;
		} catch (error) {
			console.error("LLM Chat Error:", error);
			addChatData({
				role: "bot",
				content: "抱歉，AI 服務暫時無法使用，請稍後再試。",
				isError: true,
			});
			throw error;
		} finally {
			isAILoading.value = false;
		}
	};

	const parseDashboardMatches = (toolResults) => {
		if (!toolResults) return [];

		let parsedResults = toolResults;
		if (typeof toolResults === "string") {
			try {
				parsedResults = JSON.parse(toolResults);
			} catch (error) {
				console.error("Failed to parse tool_results:", error);
				return [];
			}
		}

		if (!Array.isArray(parsedResults)) return [];

		return parsedResults.flatMap((result) => {
			if (result.name !== "match_dashboard_components") return [];

			try {
				const content =
					typeof result.content === "string"
						? JSON.parse(result.content)
						: result.content;
				return content?.matched && Array.isArray(content.matches)
					? content.matches.filter((item) => item.path)
					: [];
			} catch (error) {
				console.error("Failed to parse dashboard match result:", error);
				return [];
			}
		});
	};

	const sanitizeAIContent = (content = "") => {
		return content
			.split("\n")
			.filter(
				(line) =>
					!line.includes("/dashboard?index=") &&
					!line.includes("前往以下網址"),
			)
			.join("\n")
			.replace(/\n{3,}/g, "\n\n")
			.trim();
	};

	const addDashboardMatchMessage = (matches) => {
		const sortedMatches = [...matches].sort((a, b) => b.score - a.score);
		const buttons = sortedMatches.slice(0, 4).map((match, index) => ({
			id: index + 1,
			text: `前往「${match.name}」組件`,
			target: match,
			variant: "dashboard-link",
		}));

		addChatData({
			role: "bot",
			isDefault: false,
			button: buttons,
			relations: sortedMatches,
		});
	};

	// 清除 AI Session
	const clearAISession = () => {
		aiSessionId.value = "";
		sessionStorage.removeItem("aiSessionId");
	};

	return {
		chatData,
		addChatData,
		clearChatHistory,
		addQueryData,
		saveChatLog,
		aiSessionId,
		isAILoading,
		sendChatToLLM,
		clearAISession,
	};
});
