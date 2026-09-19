export type MbtiType = typeof MBTI_TYPES[number]["code"];

export const MBTI_TYPES = [
  { code: "INTJ", title: "建筑师", note: "冷静、战略、追求系统最优" },
  { code: "INTP", title: "逻辑学家", note: "好奇、抽象、热爱拆解问题" },
  { code: "ENTJ", title: "指挥官", note: "果断、雄心、善于组织资源" },
  { code: "ENTP", title: "辩论家", note: "敏捷、创新、享受观点碰撞" },
  { code: "INFJ", title: "提倡者", note: "洞察、坚定、关心长远意义" },
  { code: "INFP", title: "调停者", note: "温柔、理想、忠于内在价值" },
  { code: "ENFJ", title: "主人公", note: "热忱、共情、擅长鼓舞他人" },
  { code: "ENFP", title: "竞选者", note: "自由、灵感、发现无限可能" },
  { code: "ISTJ", title: "物流师", note: "可靠、务实、重视秩序承诺" },
  { code: "ISFJ", title: "守卫者", note: "细腻、忠诚、默默照顾他人" },
  { code: "ESTJ", title: "总经理", note: "直接、负责、推动事情落地" },
  { code: "ESFJ", title: "执政官", note: "热心、合群、维护共同关系" },
  { code: "ISTP", title: "鉴赏家", note: "冷静、灵巧、在行动中理解" },
  { code: "ISFP", title: "探险家", note: "敏感、随性、感受当下之美" },
  { code: "ESTP", title: "企业家", note: "大胆、机敏、享受真实挑战" },
  { code: "ESFP", title: "表演者", note: "鲜活、友善、把快乐带给现场" },
] as const;

export const PALETTES: Record<string, [string, string, string]> = {
  NT: ["#B9FF66", "#56E0C5", "#17252B"],
  NF: ["#FF7AC8", "#9C7CFF", "#241B38"],
  SJ: ["#FFD166", "#FF8A5B", "#342318"],
  SP: ["#66C7FF", "#3D7CFF", "#14243A"],
};

export function familyOf(type: string) {
  if (type.includes("N") && type.includes("T")) return "NT";
  if (type.includes("N") && type.includes("F")) return "NF";
  if (type.includes("S") && type.includes("J")) return "SJ";
  return "SP";
}

export const STAGES = [
  { name: "初生", min: 0, next: 3 },
  { name: "萌芽", min: 3, next: 10 },
  { name: "觉醒", min: 10, next: 30 },
  { name: "成熟", min: 30, next: 100 },
  { name: "传奇", min: 100, next: 100 },
] as const;

export function stageFor(summons: number) {
  if (summons >= 100) return STAGES[4];
  if (summons >= 30) return STAGES[3];
  if (summons >= 10) return STAGES[2];
  if (summons >= 3) return STAGES[1];
  return STAGES[0];
}

export type Soul = {
  id: number;
  mbti: string;
  name: string;
  catchphrase: string;
  backstory: string;
  summons: number;
  owner: string;
  previousOwner?: string;
  transferCount: number;
  seed: number;
  mine?: boolean;
};

export const DEMO_SOULS: Soul[] = [
  { id: 28, mbti: "INTJ", name: "墨菲", catchphrase: "先看本质，再谈答案。", backstory: "诞生在雪线之上的观察者，擅长从混乱里找出唯一的结构。", summons: 42, owner: "0x8F3a…91C2", previousOwner: "0x1D7b…4AE0", transferCount: 1, seed: 39124 },
  { id: 91, mbti: "ENFP", name: "Luma", catchphrase: "如果换一条路呢？", backstory: "收集城市里未被实现的念头，把每个偶遇都看作新世界的入口。", summons: 17, owner: "0x71B2…0F19", transferCount: 0, seed: 87219 },
  { id: 116, mbti: "INFJ", name: "南枝", catchphrase: "你没说出口的，也算数。", backstory: "从一封没有寄出的信里醒来，记得那些被轻轻放下的愿望。", summons: 106, owner: "0x2A45…EE72", previousOwner: "0x93C0…BB42", transferCount: 3, seed: 120331 },
  { id: 203, mbti: "ISTP", name: "零号扳手", catchphrase: "让我试一下。", backstory: "没有说明书，只有一组工具和对世界运行方式的无尽好奇。", summons: 6, owner: "0xCB80…11D3", transferCount: 0, seed: 66310 },
];

export const soulmintAbi = [
  { type: "function", name: "MINT_PRICE", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "mint", stateMutability: "payable", inputs: [{ name: "mbti", type: "string" }, { name: "soulName", type: "string" }, { name: "catchphrase", type: "string" }, { name: "backstory", type: "string" }], outputs: [{ name: "tokenId", type: "uint256" }] },
  { type: "function", name: "recordSummon", stateMutability: "nonpayable", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ name: "count", type: "uint64" }, { name: "stage", type: "uint8" }] },
  { type: "function", name: "ownerOf", stateMutability: "view", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ name: "owner", type: "address" }] },
] as const;
