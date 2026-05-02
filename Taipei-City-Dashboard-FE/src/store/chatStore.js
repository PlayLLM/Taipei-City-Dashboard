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
	const aiSessionId = ref(sessionStorage.getItem("aiSessionId") || "");
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
			chatData.value.push({
				id: chatData.value.length + 1,
				role: "bot",
				isDefault: false,
				button: [{ id: 1, text: "建立儀表板" }],
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
					content:
						"你是臺北城市儀表板小幫手，專門協助使用者了解臺北市的各項數據指標和城市資訊。請用繁體中文親切地回答使用者的問題。",
				},
				...buildChatMessages(),
			];

			// 定義工具
			const tools = [
				{
					type: "function",
					function: {
						name: "get_current_time",
						description: "取得當前台北時間",
					},
				},
				{
					type: "function",
					function: {
						name: "get_population_summary",
						description: "查詢人口年齡分佈統計",
						parameters: {
							type: "object",
							properties: {
								city: {
									type: "string",
									enum: ["taipei", "new_taipei"],
									description: "城市名稱",
								},
								year: {
									type: "integer",
									description: "年份",
								},
							},
							required: ["city", "year"],
						},
					},
				},
			];

			// 呼叫 AI API
			const response = await http.post("/ai/chat/twai", {
				session: aiSessionId.value || undefined,
				messages: messages,
				stream: false,
				tools: tools,
			});

			if (response.data?.status === "success") {
				const { data } = response.data;

				// 儲存 session ID
				if (data.session) {
					aiSessionId.value = data.session;
					sessionStorage.setItem("aiSessionId", data.session);
				}

				// 解析 tools 資訊（如果存在）
				let toolsUsed = [];
				if (data.tools) {
					try {
						toolsUsed =
							typeof data.tools === "string"
								? JSON.parse(data.tools)
								: data.tools;
					} catch (e) {
						console.error("Failed to parse tools:", e);
					}
				}

				// 加入 AI 回應到聊天記錄
				addChatData({
					role: "bot",
					content: data.content || "抱歉，我無法理解您的問題。",
					isAIResponse: true,
					toolUsed: data.tool_used || false,
					tools: toolsUsed,
				});

				return data;
			} else {
				throw new Error(response.data?.message || "AI 服務回應異常");
			}
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

	// 清除 AI Session
	const clearAISession = () => {
		aiSessionId.value = "";
		sessionStorage.removeItem("aiSessionId");
	};

	return {
		chatData,
		addChatData,
		addQueryData,
		saveChatLog,
		aiSessionId,
		isAILoading,
		sendChatToLLM,
		clearAISession,
	};
});
