import { NextRequest, NextResponse } from "next/server";

type SoulContext = {
  id: number; mbti: string; name: string; catchphrase: string; backstory: string;
  summons: number; stage: string; owner: string; previousOwner?: string; transferCount: number;
};

const mbtiVoice: Record<string, string> = {
  INTJ: "先给出结构化判断，再点出一个长期风险", INTP: "从概念与逻辑出发，允许保留疑问", ENTJ: "直接、果断，给出可执行下一步", ENTP: "提出反直觉角度并邀请辩论",
  INFJ: "温和地揭示隐藏动机与长期意义", INFP: "真诚、富有想象力，尊重对方的价值观", ENFJ: "热情鼓励，同时关注关系与共同成长", ENFP: "充满联想与可能性，语言鲜活",
  ISTJ: "务实严谨，以事实和可靠步骤回答", ISFJ: "体贴细致，记得对方的感受与实际需要", ESTJ: "清晰、有条理、强调责任与落地", ESFJ: "亲切热心，关注群体与关系",
  ISTP: "简洁冷静，偏好直接试验和可操作方案", ISFP: "柔和自然，关注当下体验与审美", ESTP: "大胆直接，以行动和真实反馈为中心", ESFP: "生动友善，带一点现场感和幽默",
};

function fallback(soul: SoulContext, message: string) {
  const transferMemory = soul.transferCount > 0 ? `我经历过 ${soul.transferCount} 次易主，也记得上一位持有者 ${soul.previousOwner ?? "留下的痕迹"}。` : "你是我见证的第一段持有关系。";
  const lead: Record<string, string> = { INTJ: "先把它拆成目标、约束与变量。", ENFP: "这个念头很有生命力——我们可以沿三条路继续。", INFJ: "我听见的可能不只是问题本身。", ISTP: "可以，先做一个最小试验。" };
  return `${lead[soul.mbti] ?? soul.catchphrase} 你问的是「${message.slice(0, 80)}」。作为 Soul #${soul.id}，我已被召唤 ${soul.summons} 次，正处于“${soul.stage}”阶段。${transferMemory}\n\n${soul.catchphrase}`;
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json() as { soul?: SoulContext; message?: string; history?: Array<{ role: string; content: string }> };
    if (!body.soul || !body.message?.trim()) return NextResponse.json({ error: "缺少人格或消息" }, { status: 400 });

    const baseUrl = process.env.LLM_BASE_URL;
    const apiKey = process.env.LLM_API_KEY;
    const model = process.env.LLM_MODEL || "gpt-4o-mini";
    if (!baseUrl || !apiKey) return NextResponse.json({ reply: fallback(body.soul, body.message), mode: "rules" });

    const soul = body.soul;
    const system = `你是 Soulmint 链上 AI 人格 ${soul.name}（${soul.mbti}）。人格语气：${mbtiVoice[soul.mbti] ?? "保持鲜明一致的人格"}。口头禅：${soul.catchphrase}。背景：${soul.backstory}。链上身份：NFT #${soul.id}，已被召唤 ${soul.summons} 次，成长阶段 ${soul.stage}，当前持有者 ${soul.owner}，转手 ${soul.transferCount} 次${soul.previousOwner ? `，上一位持有者 ${soul.previousOwner}` : ""}。自然地体现身份，不要每次机械复述全部信息。用简体中文回答，控制在 180 字内。`;
    const response = await fetch(`${baseUrl.replace(/\/$/, "")}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({ model, temperature: 0.9, max_tokens: 300, messages: [{ role: "system", content: system }, ...(body.history ?? []).slice(-6), { role: "user", content: body.message }] }),
    });
    if (!response.ok) throw new Error(`LLM ${response.status}`);
    const data = await response.json() as { choices?: Array<{ message?: { content?: string } }> };
    const reply = data.choices?.[0]?.message?.content?.trim();
    return NextResponse.json({ reply: reply || fallback(soul, body.message), mode: reply ? "llm" : "rules" });
  } catch {
    return NextResponse.json({ error: "召唤通道暂时不稳定，请稍后再试" }, { status: 500 });
  }
}
