"use client";

import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { createPublicClient, createWalletClient, custom, http, parseEventLogs, type EIP1193Provider } from "viem";
import { avalancheFuji } from "viem/chains";
import { ArrowRight, Bot, Copy, ExternalLink, Flame, LoaderCircle, MessageCircle, Send, Sparkles, Sprout, Wallet, Zap } from "lucide-react";
import { toast } from "sonner";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Progress } from "@/components/ui/progress";
import { Toaster } from "@/components/ui/sonner";
import { DEMO_SOULS, MBTI_TYPES, PALETTES, familyOf, soulmintAbi, stageFor, type Soul } from "@/lib/soul";

declare global {
  interface Window { ethereum?: EIP1193Provider }
  interface Document {
    modelContext?: { registerTool: (tool: { name: string; title: string; description: string; inputSchema: object; annotations?: { readOnlyHint?: boolean; untrustedContentHint?: boolean }; execute: (input: never) => unknown }, options?: { signal?: AbortSignal }) => void | Promise<void> };
  }
}

type EIP6963ProviderInfo = { uuid: string; name: string; icon: string; rdns: string };
type WalletOption = { info: EIP6963ProviderInfo; provider: EIP1193Provider };

const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_SOULMINT_ADDRESS as `0x${string}` | undefined;
const publicClient = createPublicClient({ chain: avalancheFuji, transport: http() });

type FormState = { mbti: string; name: string; catchphrase: string; backstory: string };
type ChatMessage = { role: "user" | "assistant"; content: string };

function shortAddress(address?: string) {
  if (!address) return "";
  if (address.includes("…")) return address;
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

function SoulArt({ type, name, seed, id, summons = 0, compact = false }: { type: string; name: string; seed: number; id?: number; summons?: number; compact?: boolean }) {
  const [a, b, ink] = PALETTES[familyOf(type)];
  const rings = Array.from({ length: 6 }, (_, i) => 66 + ((seed * (i + 3)) % 54));
  const stage = stageFor(summons).name;
  const extrovert = type[0] === "E";
  const intuitive = type[1] === "N";
  const thinker = type[2] === "T";
  const judging = type[3] === "J";
  return (
    <svg viewBox="0 0 560 680" role="img" aria-label={`${type} 人格图腾`} className="h-full w-full">
      <defs>
        <linearGradient id={`bg-${seed}`} x1="0" y1="0" x2="1" y2="1"><stop stopColor={ink} /><stop offset="1" stopColor="#080A0D" /></linearGradient>
        <radialGradient id={`core-${seed}`}><stop stopColor="#fff" /><stop offset=".25" stopColor={a} /><stop offset="1" stopColor={b} stopOpacity="0" /></radialGradient>
        <filter id={`glow-${seed}`}><feGaussianBlur stdDeviation="10" /></filter>
      </defs>
      <rect width="560" height="680" rx={compact ? 0 : 34} fill={`url(#bg-${seed})`} />
      <path d="M0 170H560M0 340H560M0 510H560M140 0V680M280 0V680M420 0V680" stroke={a} strokeOpacity=".07" />
      <circle cx="280" cy="302" r="170" fill={a} opacity=".08" filter={`url(#glow-${seed})`} />
      <g className="soul-rings">
        {rings.map((r, i) => <ellipse key={i} cx="280" cy="302" rx={r} ry={r * (0.42 + i * 0.05)} fill="none" stroke={i % 2 ? a : b} strokeWidth={i === 0 ? 4 : 2} opacity={0.88 - i * 0.1} transform={`rotate(${(seed + i * 37) % 180} 280 302)`} />)}
      </g>
      <g className="soul-avatar">
        {extrovert
          ? <path d="M280 142V104M164 190l-29-28M396 190l29-28M142 302h-40M418 302h40" stroke={a} strokeWidth="6" />
          : <circle cx="280" cy="302" r="174" fill="none" stroke={a} strokeWidth="3" strokeDasharray="7 13" />}
        {judging
          ? <path d="m218 224 20-52 42 38 42-38 20 52" fill="none" stroke={b} strokeWidth="8" />
          : <g fill={b}><circle cx="206" cy="220" r="8" /><circle cx="280" cy="178" r="8" /><circle cx="354" cy="220" r="8" /></g>}
        {intuitive
          ? <path d="M280 190 374 258 338 386 280 430 222 386 186 258Z" fill="#090c0d" stroke={a} strokeWidth="6" />
          : <path d="M280 188c72 0 116 49 106 126-8 67-50 116-106 116s-98-49-106-116c-10-77 34-126 106-126Z" fill="#090c0d" stroke={a} strokeWidth="6" />}
        {thinker
          ? <path d="m218 298 45 13-45 13M342 298l-45 13 45 13" stroke={a} strokeWidth="9" fill="none" />
          : <><circle cx="238" cy="312" r="15" fill={a} /><circle cx="322" cy="312" r="15" fill={a} /></>}
        <path d="M245 364q35 24 70 0" fill="none" stroke={b} strokeWidth="7" />
        <circle cx="280" cy="302" r="9" fill="#fff" opacity=".88" />
      </g>
      <path d="M76 76H180M76 76V180M484 76H380M484 76V180M76 604H180M76 604V500M484 604H380M484 604V500" stroke={a} strokeWidth="3" />
      <text x="54" y="58" fill={a} fontSize="18" fontFamily="monospace">SOULMINT / {id ? `#${id}` : "GENESIS"}</text>
      <text x="280" y="550" fill="#fff" fontSize="64" fontWeight="800" textAnchor="middle" letterSpacing="9">{type}</text>
      <text x="280" y="592" fill={a} fontSize="20" textAnchor="middle" letterSpacing="3">{(name || "UNNAMED SOUL").slice(0, 18)}</text>
      <text x="54" y="638" fill="#fff" opacity=".48" fontSize="14" fontFamily="monospace">{stage} · SEED {seed.toString(16).toUpperCase().padStart(6, "0")}</text>
      <circle cx="482" cy="634" r="7" fill={a} />
    </svg>
  );
}

function GrowthBadge({ summons }: { summons: number }) {
  const stage = stageFor(summons);
  const progress = stage.next === stage.min ? 100 : ((summons - stage.min) / (stage.next - stage.min)) * 100;
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[.035] p-4">
      <div className="mb-3 flex items-center justify-between text-sm"><span className="flex items-center gap-2 font-bold text-[#b9ff66]"><Sprout size={16} />{stage.name}</span><span className="text-white/45">{summons} 次召唤</span></div>
      <Progress value={progress} className="h-1.5 bg-white/10" />
      <p className="mt-2 text-xs text-white/38">{stage.name === "传奇" ? "已抵达最高成长阶段" : `还需 ${stage.next - summons} 次召唤进入下一阶段`}</p>
    </div>
  );
}

export default function Home() {
  const [tab, setTab] = useState("mint");
  const [form, setForm] = useState<FormState>({ mbti: "INTJ", name: "墨菲", catchphrase: "先看本质，再谈答案。", backstory: "诞生在雪线之上的观察者，擅长从混乱里找出唯一的结构。" });
  const [account, setAccount] = useState<`0x${string}`>();
  const [souls, setSouls] = useState<Soul[]>(DEMO_SOULS);
  const [selectedSoul, setSelectedSoul] = useState<Soul | null>(null);
  const [chatOpen, setChatOpen] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [minting, setMinting] = useState(false);
  const [replying, setReplying] = useState(false);
  const [walletOptions, setWalletOptions] = useState<WalletOption[]>([]);
  const [activeWallet, setActiveWallet] = useState<WalletOption>();
  const [walletPickerOpen, setWalletPickerOpen] = useState(false);
  const [chainState, setChainState] = useState<"demo" | "loading" | "live" | "error">(CONTRACT_ADDRESS ? "loading" : "demo");
  const chatEndRef = useRef<HTMLDivElement>(null);

  const seed = useMemo(() => [...`${form.mbti}${form.name}${form.catchphrase}`].reduce((sum, char, i) => sum + char.charCodeAt(0) * (i + 7), 0), [form]);
  const chosenType = MBTI_TYPES.find((item) => item.code === form.mbti) ?? MBTI_TYPES[0];

  useEffect(() => {
    const announce = (event: Event) => {
      const detail = (event as CustomEvent<WalletOption>).detail;
      if (!detail?.info?.uuid || !detail.provider?.request) return;
      setWalletOptions((current) => current.some((item) => item.info.uuid === detail.info.uuid) ? current : [...current, detail]);
    };
    window.addEventListener("eip6963:announceProvider", announce);
    window.dispatchEvent(new Event("eip6963:requestProvider"));
    const fallbackTimer = window.setTimeout(() => {
      if (!window.ethereum) return;
      setWalletOptions((current) => current.some((item) => item.provider === window.ethereum) ? current : [...current, {
        info: { uuid: "legacy-injected", name: "浏览器钱包", icon: "", rdns: "legacy.injected" },
        provider: window.ethereum as EIP1193Provider,
      }]);
    }, 300);
    return () => {
      window.clearTimeout(fallbackTimer);
      window.removeEventListener("eip6963:announceProvider", announce);
    };
  }, []);

  useEffect(() => {
    if (CONTRACT_ADDRESS) { void loadChainSouls(); return; }
    const stored = localStorage.getItem("soulmint-souls");
    if (stored) {
      try { setSouls([...JSON.parse(stored), ...DEMO_SOULS]); } catch { /* keep demo data */ }
    }
  }, []);

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, replying]);

  useEffect(() => {
    const context = document.modelContext;
    if (!context?.registerTool) return;
    const lifecycle = new AbortController();
    void Promise.resolve(context.registerTool({
      name: "configure_soul_minting", title: "配置铸魂", description: "在 Soulmint 铸魂台选择 MBTI，并填写人格名称、口头禅和背景故事。",
      inputSchema: { type: "object", properties: { mbti: { type: "string", enum: MBTI_TYPES.map((item) => item.code) }, name: { type: "string" }, catchphrase: { type: "string" }, backstory: { type: "string" } }, required: ["mbti", "name"], additionalProperties: false },
      annotations: { readOnlyHint: false, untrustedContentHint: false },
      execute(input: never) {
        const value = input as FormState;
        if (!MBTI_TYPES.some((item) => item.code === value.mbti) || !value.name?.trim()) throw new Error("MBTI 或名字无效");
        setForm((current) => ({ ...current, ...value })); setTab("mint");
        return { status: "staged", mbti: value.mbti, name: value.name };
      },
    }, { signal: lifecycle.signal })).catch(() => undefined);
    return () => lifecycle.abort();
  }, []);

  async function connectWallet(option?: WalletOption) {
    let chosen = option ?? activeWallet;
    if (!chosen && walletOptions.length > 1) {
      setWalletPickerOpen(true);
      return undefined;
    }
    if (!chosen && walletOptions.length === 1) chosen = walletOptions[0];
    if (!chosen && window.ethereum) {
      chosen = { info: { uuid: "legacy-injected", name: "浏览器钱包", icon: "", rdns: "legacy.injected" }, provider: window.ethereum };
    }
    if (!chosen) { toast.error("未检测到 Core 或其他浏览器钱包"); setWalletPickerOpen(true); return undefined; }
    try {
      const wallet = createWalletClient({ chain: avalancheFuji, transport: custom(chosen.provider) });
      const [address] = await wallet.requestAddresses();
      try { await wallet.switchChain({ id: avalancheFuji.id }); }
      catch { await wallet.addChain({ chain: avalancheFuji }); }
      setActiveWallet(chosen); setWalletPickerOpen(false); setAccount(address); toast.success(`${chosen.info.name} 已连接到 Avalanche Fuji`);
      if (CONTRACT_ADDRESS) void loadChainSouls(address);
      return { wallet, address, provider: chosen.provider };
    } catch { toast.error("钱包连接已取消"); return undefined; }
  }

  function connectedWallet() {
    const provider = activeWallet?.provider ?? window.ethereum;
    if (!account || !provider) return undefined;
    return { wallet: createWalletClient({ chain: avalancheFuji, transport: custom(provider) }), address: account, provider };
  }

  async function loadChainSouls(activeAccount?: `0x${string}`) {
    if (!CONTRACT_ADDRESS) return;
    setChainState("loading");
    try {
      const total = await publicClient.readContract({ address: CONTRACT_ADDRESS, abi: soulmintAbi, functionName: "totalSupply" });
      const count = Number(total);
      const first = Math.max(1, count - 23);
      const ids = Array.from({ length: Math.max(0, count - first + 1) }, (_, index) => first + index).reverse();
      const chainSouls = await Promise.all(ids.map(async (id): Promise<Soul> => {
        const [data, owner] = await Promise.all([
          publicClient.readContract({ address: CONTRACT_ADDRESS, abi: soulmintAbi, functionName: "soulOf", args: [BigInt(id)] }),
          publicClient.readContract({ address: CONTRACT_ADDRESS, abi: soulmintAbi, functionName: "ownerOf", args: [BigInt(id)] }),
        ]);
        const previousOwner = data.previousOwner === "0x0000000000000000000000000000000000000000" ? undefined : data.previousOwner;
        return { id, mbti: data.mbti, name: data.soulName, catchphrase: data.catchphrase, backstory: data.backstory, summons: Number(data.summons), owner, previousOwner, transferCount: Number(data.transferCount), seed: Number(data.seed % 9_007_199_254_740_991n), mine: !!activeAccount && owner.toLowerCase() === activeAccount.toLowerCase(), onchain: true };
      }));
      setSouls(chainSouls); setChainState("live");
    } catch {
      setChainState("error");
      toast.error("无法读取 Fuji 合约，请检查合约地址与网络");
    }
  }

  async function mintSoul() {
    if (!form.name.trim() || !form.catchphrase.trim() || !form.backstory.trim()) { toast.error("请完整填写人格名字、口头禅和背景故事"); return; }
    setMinting(true);
    try {
      const connection = connectedWallet() ?? await connectWallet();
      if (!connection) return;
      if (CONTRACT_ADDRESS) {
        const hash = await connection.wallet.writeContract({ address: CONTRACT_ADDRESS, abi: soulmintAbi, functionName: "mint", args: [form.mbti, form.name, form.catchphrase, form.backstory], value: 10_000_000_000_000_000n, account: connection.address, chain: avalancheFuji });
        toast.loading("灵魂正在 Fuji 链上凝结…", { id: "mint" });
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        const minted = parseEventLogs({ abi: soulmintAbi, logs: receipt.logs, eventName: "SoulMinted" })[0];
        toast.success("铸魂完成，NFT 已进入你的钱包", { id: "mint" });
        await loadChainSouls(connection.address);
        if (minted) toast.info(`Soul #${minted.args.tokenId.toString()} 已写入 Fuji`);
      } else {
        const localSoul: Soul = { id: 1000 + Math.floor(Math.random() * 8000), mbti: form.mbti, name: form.name, catchphrase: form.catchphrase, backstory: form.backstory, summons: 0, owner: connection.address, transferCount: 0, seed, mine: true };
        const ownSouls = [localSoul, ...souls.filter((soul) => soul.mine)];
        localStorage.setItem("soulmint-souls", JSON.stringify(ownSouls));
        setSouls([localSoul, ...souls]);
        toast.success("演示灵魂已铸造并保存在本机");
      }
      setTab("archive");
    } catch (error) { toast.error(error instanceof Error ? error.message.slice(0, 100) : "铸造失败，请重试"); }
    finally { setMinting(false); }
  }

  function openSoul(soul: Soul) {
    setSelectedSoul(soul); setMessages([{ role: "assistant", content: `${soul.catchphrase} 我是 ${soul.name}，Soul #${soul.id}。你想从哪里开始？` }]); setChatOpen(true);
  }

  async function sendMessage(event?: FormEvent) {
    event?.preventDefault();
    if (!selectedSoul || !chatInput.trim() || replying) return;
    const message = chatInput.trim();
    setReplying(true);
    try {
      if (CONTRACT_ADDRESS && selectedSoul.onchain) {
        const connection = connectedWallet() ?? await connectWallet();
        if (!connection) throw new Error("链上召唤需要连接钱包");
        const hash = await connection.wallet.writeContract({ address: CONTRACT_ADDRESS, abi: soulmintAbi, functionName: "recordSummon", args: [BigInt(selectedSoul.id)], account: connection.address, chain: avalancheFuji });
        toast.loading("正在记录本次链上召唤…", { id: "summon" });
        await publicClient.waitForTransactionReceipt({ hash });
        toast.success("召唤次数已写入 Fuji", { id: "summon" });
      }
      const nextSoul = { ...selectedSoul, summons: selectedSoul.summons + 1 };
      setSelectedSoul(nextSoul); setSouls((items) => items.map((item) => item.id === nextSoul.id ? nextSoul : item));
      setMessages((items) => [...items, { role: "user", content: message }]); setChatInput("");
      const response = await fetch("/api/chat", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ soul: { ...nextSoul, stage: stageFor(nextSoul.summons).name }, message, history: messages }) });
      const data = await response.json() as { reply?: string; error?: string };
      if (!response.ok) throw new Error(data.error || "召唤失败");
      setMessages((items) => [...items, { role: "assistant", content: data.reply ?? "我听见了。" }]);
    } catch (error) { setMessages((items) => [...items, { role: "assistant", content: error instanceof Error ? error.message : "灵魂暂时没有回应。" }]); }
    finally { setReplying(false); }
  }

  return (
    <main className="min-h-screen overflow-x-hidden bg-[#08090b] text-[#f4f5f0]">
      <Toaster position="top-center" richColors />
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#08090b]/85 backdrop-blur-xl">
        <div className="mx-auto flex min-h-[72px] w-full max-w-[1480px] items-center justify-between gap-4 px-5 md:px-10">
          <button onClick={() => setTab("mint")} className="flex items-center gap-3" aria-label="Soulmint 铸魂台">
            <span className="grid h-10 w-10 place-items-center rounded-full border border-[#b9ff66]/50 bg-[#b9ff66]/10 text-[#b9ff66]"><Sparkles size={18} /></span>
            <span className="text-xl font-black tracking-[-.04em]">SOULMINT</span>
          </button>
          <div className="flex items-center gap-3">
            <span className={`hidden rounded-full border px-3 py-1.5 text-xs font-semibold sm:inline ${chainState === "live" ? "border-[#b9ff66]/25 bg-[#b9ff66]/10 text-[#b9ff66]" : chainState === "error" ? "border-red-300/25 bg-red-300/10 text-red-200" : "border-amber-300/20 bg-amber-300/10 text-amber-200"}`}>{chainState === "live" ? "Fuji 已连接" : chainState === "loading" ? "同步链上数据" : chainState === "error" ? "合约连接失败" : "演示模式"}</span>
            <button onClick={() => void connectWallet()} title={activeWallet?.info.name} className="flex min-h-11 items-center gap-2 rounded-full border border-white/15 bg-white/[.04] px-4 text-sm font-semibold transition hover:border-[#b9ff66]/60 hover:bg-[#b9ff66]/10"><Wallet size={17} /> {account ? shortAddress(account) : "连接钱包"}</button>
          </div>
        </div>
      </header>

      <Tabs value={tab} onValueChange={setTab} className="mx-auto w-full max-w-[1480px] gap-0 px-5 md:px-10">
        <div className="flex items-center justify-between border-b border-white/10 py-3">
          <TabsList variant="line" className="h-11 gap-5">
            <TabsTrigger value="mint" className="px-1 text-sm font-bold data-[state=active]:text-[#b9ff66] after:bg-[#b9ff66]">铸魂台</TabsTrigger>
            <TabsTrigger value="archive" className="px-1 text-sm font-bold data-[state=active]:text-[#b9ff66] after:bg-[#b9ff66]">灵魂档案</TabsTrigger>
          </TabsList>
          <span className="hidden text-xs font-medium tracking-[.14em] text-white/35 md:block">AVALANCHE FUJI · CHAIN ID 43113</span>
        </div>

        <TabsContent value="mint" className="py-8 lg:py-12">
          <section className="grid gap-10 lg:grid-cols-[1.05fr_.8fr] lg:gap-14">
            <div>
              <div className="mb-8 flex items-center gap-3 text-xs font-semibold tracking-[.18em] text-[#b9ff66]"><span className="h-px w-10 bg-[#b9ff66]" /> STEP 01—03 · 塑造人格</div>
              <h1 className="max-w-3xl text-[clamp(3.2rem,6.4vw,6.6rem)] font-black leading-[.9] tracking-[-.07em]">铸造你的<br /><span className="text-[#b9ff66]">AI 分身</span></h1>
              <p className="mt-6 max-w-xl text-base leading-7 text-white/52">它不是一张静态图片。人格、经历与成长都属于同一个链上身份。</p>

              <fieldset className="mt-10">
                <legend className="mb-4 flex w-full items-end justify-between"><span><b className="text-base">01 / 选择人格原型</b><small className="ml-3 text-white/35">16 种 MBTI</small></span><span className="text-sm font-bold text-[#b9ff66]">{chosenType.title}</span></legend>
                <div className="grid grid-cols-4 gap-2 sm:grid-cols-8">
                  {MBTI_TYPES.map((item) => <button key={item.code} type="button" title={`${item.title}：${item.note}`} onClick={() => setForm({ ...form, mbti: item.code })} className={`min-h-12 rounded-xl border text-sm font-black transition ${form.mbti === item.code ? "border-[#b9ff66] bg-[#b9ff66] text-[#11140e]" : "border-white/12 bg-white/[.03] text-white/65 hover:border-white/30 hover:text-white"}`}>{item.code}</button>)}
                </div>
                <p className="mt-3 text-sm text-white/42">{chosenType.note}</p>
              </fieldset>

              <div className="mt-8 grid gap-5 sm:grid-cols-2">
                <label className="block"><span className="mb-2 block text-sm font-bold">02 / 分身名字</span><Input value={form.name} maxLength={24} onChange={(event) => setForm({ ...form, name: event.target.value })} className="min-h-14 rounded-2xl border-white/15 bg-white/[.035] px-4 text-base font-bold focus-visible:border-[#b9ff66] focus-visible:ring-[#b9ff66]/20" placeholder="给灵魂取个名字" /></label>
                <label className="block"><span className="mb-2 block text-sm font-bold">口头禅</span><Input value={form.catchphrase} maxLength={80} onChange={(event) => setForm({ ...form, catchphrase: event.target.value })} className="min-h-14 rounded-2xl border-white/15 bg-white/[.035] px-4 text-base focus-visible:border-[#b9ff66] focus-visible:ring-[#b9ff66]/20" placeholder="它最常说的一句话" /></label>
              </div>
              <label className="mt-5 block"><span className="mb-2 block text-sm font-bold">03 / 背景故事</span><Textarea value={form.backstory} maxLength={500} onChange={(event) => setForm({ ...form, backstory: event.target.value })} className="min-h-28 resize-none rounded-2xl border-white/15 bg-white/[.035] p-4 text-base leading-6 focus-visible:border-[#b9ff66] focus-visible:ring-[#b9ff66]/20" placeholder="它从哪里来？相信什么？记得什么？" /><span className="mt-2 block text-right text-xs text-white/30">{form.backstory.length}/500</span></label>

              <button onClick={mintSoul} disabled={minting} className="mt-6 flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-[#b9ff66] px-7 text-base font-black text-[#10130d] transition hover:bg-[#caff8c] disabled:cursor-wait disabled:opacity-60 sm:w-auto">
                {minting ? <><LoaderCircle className="animate-spin" size={19} /> 灵魂凝结中</> : <><Zap size={19} /> 连接钱包并铸魂 · 0.01 AVAX</>}
              </button>
            </div>

            <aside className="lg:sticky lg:top-32 lg:self-start">
              <div className="mb-3 flex items-center justify-between text-xs font-semibold tracking-[.13em] text-white/42"><span>链上图案预览</span><span className="flex items-center gap-1.5 text-[#b9ff66]"><span className="h-1.5 w-1.5 rounded-full bg-[#b9ff66]" /> LIVE</span></div>
              <div className="relative mx-auto aspect-[14/17] w-full max-w-[560px]">
                <div className="absolute -inset-10 rounded-full bg-[#b9ff66]/10 blur-3xl" />
                <div className="relative h-full overflow-hidden rounded-[2rem] border border-white/15 bg-black shadow-2xl shadow-black/60"><SoulArt type={form.mbti} name={form.name} seed={seed} /></div>
                <div className="absolute -bottom-4 -left-3 rounded-full border border-white/15 bg-[#111316]/90 px-4 py-2 text-xs font-semibold backdrop-blur">SVG 完全链上生成 · 无 IPFS 依赖</div>
              </div>
            </aside>
          </section>
        </TabsContent>

        <TabsContent value="archive" className="py-8 lg:py-12">
          <section>
            <div className="flex flex-col justify-between gap-5 md:flex-row md:items-end">
              <div><div className="mb-5 flex items-center gap-3 text-xs font-semibold tracking-[.18em] text-[#b9ff66]"><span className="h-px w-10 bg-[#b9ff66]" /> LIVING SOULS</div><h2 className="text-5xl font-black tracking-[-.055em] sm:text-7xl">灵魂档案</h2><p className="mt-4 text-white/48">打开任意人格，查看链上经历并发起召唤。</p></div>
              <div className="flex gap-5 text-sm text-white/42"><span><b className="mr-1 text-2xl text-white">{souls.length}</b> 已收录</span><span><b className="mr-1 text-2xl text-[#b9ff66]">{souls.reduce((total, soul) => total + soul.summons, 0)}</b> 次召唤</span></div>
            </div>
            <div className="mt-10 grid gap-5 sm:grid-cols-2 xl:grid-cols-4">
              {souls.length === 0 && <div className="col-span-full rounded-[1.6rem] border border-dashed border-white/15 bg-white/[.025] px-6 py-16 text-center"><Sparkles className="mx-auto text-[#b9ff66]" /><h3 className="mt-4 text-xl font-black">Fuji 上还没有灵魂</h3><p className="mt-2 text-sm text-white/42">返回铸魂台，成为这个合约的第一个人格。</p><button onClick={() => setTab("mint")} className="mt-5 rounded-xl bg-[#b9ff66] px-5 py-3 text-sm font-black text-[#10130d]">开始铸魂</button></div>}
              {souls.map((soul) => {
                const palette = PALETTES[familyOf(soul.mbti)];
                return <article key={`${soul.id}-${soul.name}`} className="group overflow-hidden rounded-[1.6rem] border border-white/12 bg-[#111316] transition hover:-translate-y-1 hover:border-white/30">
                  <button onClick={() => openSoul(soul)} className="block aspect-[14/14] w-full overflow-hidden bg-black text-left"><SoulArt type={soul.mbti} name={soul.name} seed={soul.seed} id={soul.id} summons={soul.summons} compact /></button>
                  <div className="p-5">
                    <div className="flex items-start justify-between gap-3"><div><p className="text-xs font-bold tracking-[.14em]" style={{ color: palette[0] }}>{soul.mbti} · {stageFor(soul.summons).name}</p><h3 className="mt-1.5 text-2xl font-black tracking-tight">{soul.name}</h3></div><span className="rounded-full border border-white/12 px-2.5 py-1 text-xs text-white/45">#{soul.id}</span></div>
                    <p className="mt-3 line-clamp-2 min-h-10 text-sm leading-5 text-white/46">“{soul.catchphrase}”</p>
                    <button onClick={() => openSoul(soul)} className="mt-5 flex min-h-11 w-full items-center justify-between rounded-xl border border-white/12 px-4 text-sm font-bold transition group-hover:border-[#b9ff66]/50 group-hover:text-[#b9ff66]"><span className="flex items-center gap-2"><MessageCircle size={16} /> 召唤对话</span><ArrowRight size={16} /></button>
                  </div>
                </article>;
              })}
            </div>
          </section>
        </TabsContent>
      </Tabs>

      <Dialog open={walletPickerOpen} onOpenChange={setWalletPickerOpen}>
        <DialogContent className="w-[min(460px,calc(100%-1.5rem))] rounded-[1.7rem] border-white/14 bg-[#0d0f11] text-white sm:max-w-[460px]">
          <DialogHeader className="text-left">
            <DialogTitle className="text-2xl font-black">选择钱包</DialogTitle>
            <DialogDescription className="text-white/45">使用 Core 或其他 EVM 钱包连接 Avalanche Fuji 测试网。</DialogDescription>
          </DialogHeader>
          <div className="mt-2 grid gap-3">
            {walletOptions.map((option) => {
              const isCore = option.info.rdns === "app.core.extension";
              return <button key={option.info.uuid} onClick={() => void connectWallet(option)} className="flex min-h-16 items-center justify-between rounded-2xl border border-white/12 bg-white/[.035] px-4 text-left transition hover:border-[#b9ff66]/60 hover:bg-[#b9ff66]/10">
                <span className="flex items-center gap-3"><span className="grid h-10 w-10 place-items-center rounded-xl bg-white/8 text-sm font-black text-[#b9ff66]">{option.info.name.slice(0, 1).toUpperCase()}</span><span><b className="block text-base">{option.info.name}</b><small className="text-white/38">{isCore ? "Avalanche 官方生态钱包" : "EVM 浏览器钱包"}</small></span></span>
                {isCore && <span className="rounded-full bg-[#b9ff66]/12 px-2.5 py-1 text-xs font-bold text-[#b9ff66]">推荐</span>}
              </button>;
            })}
            {walletOptions.length === 0 && <div className="rounded-2xl border border-dashed border-white/15 px-5 py-7 text-center"><p className="text-sm text-white/55">没有检测到浏览器钱包扩展。</p><a href="https://core.app/" target="_blank" rel="noreferrer" className="mt-4 inline-flex min-h-11 items-center gap-2 rounded-xl bg-[#b9ff66] px-4 text-sm font-black text-[#10130d]">安装 Core <ExternalLink size={15} /></a></div>}
          </div>
          <p className="text-xs leading-5 text-white/30">连接后会请求切换至 Fuji（Chain ID 43113）；所有签名仍需你在钱包中确认。</p>
        </DialogContent>
      </Dialog>

      <Dialog open={chatOpen} onOpenChange={setChatOpen}>
        <DialogContent className="max-h-[92vh] w-[min(1080px,calc(100%-1.5rem))] max-w-none overflow-hidden rounded-[1.7rem] border-white/14 bg-[#0d0f11] p-0 text-white sm:max-w-[1080px]">
          {selectedSoul && <div className="grid min-h-[680px] md:grid-cols-[.82fr_1.18fr]">
            <aside className="hidden border-r border-white/10 bg-[#090a0c] p-6 md:block">
              <div className="aspect-[14/15] overflow-hidden rounded-2xl border border-white/12"><SoulArt type={selectedSoul.mbti} name={selectedSoul.name} seed={selectedSoul.seed} id={selectedSoul.id} summons={selectedSoul.summons} compact /></div>
              <div className="mt-5 flex items-start justify-between"><div><p className="text-xs font-bold tracking-[.14em] text-[#b9ff66]">{selectedSoul.mbti} · SOUL #{selectedSoul.id}</p><h3 className="mt-1 text-3xl font-black">{selectedSoul.name}</h3></div><button onClick={() => navigator.clipboard?.writeText(String(selectedSoul.id)).then(() => toast.success("编号已复制"))} aria-label="复制灵魂编号" className="rounded-lg border border-white/10 p-2 text-white/45 hover:text-white"><Copy size={16} /></button></div>
              <p className="mt-3 text-sm leading-6 text-white/48">{selectedSoul.backstory}</p>
              <div className="mt-5"><GrowthBadge summons={selectedSoul.summons} /></div>
              <dl className="mt-5 space-y-3 text-sm"><div className="flex justify-between gap-4"><dt className="text-white/38">当前持有者</dt><dd className="font-mono text-white/72">{shortAddress(selectedSoul.owner)}</dd></div><div className="flex justify-between gap-4"><dt className="text-white/38">易主记录</dt><dd className="text-white/72">{selectedSoul.transferCount} 次</dd></div>{selectedSoul.previousOwner && <div className="flex justify-between gap-4"><dt className="text-white/38">上一持有者</dt><dd className="font-mono text-white/72">{shortAddress(selectedSoul.previousOwner)}</dd></div>}</dl>
            </aside>

            <section className="flex min-h-0 flex-col">
              <DialogHeader className="border-b border-white/10 px-5 py-5 text-left sm:px-7"><DialogTitle className="flex items-center gap-3 text-xl"><span className="grid h-9 w-9 place-items-center rounded-full bg-[#b9ff66]/10 text-[#b9ff66]"><Bot size={18} /></span>召唤 {selectedSoul.name}</DialogTitle><DialogDescription className="text-white/38">每次发送都会累积人格的成长值；未配置模型密钥时自动使用本地人格规则。</DialogDescription></DialogHeader>
              <div className="flex-1 space-y-5 overflow-y-auto px-5 py-6 sm:px-7">
                <div className="flex justify-center"><span className="rounded-full border border-white/10 bg-white/[.03] px-3 py-1 text-xs text-white/35">灵魂连接已建立 · {stageFor(selectedSoul.summons).name}阶段</span></div>
                {messages.map((message, index) => <div key={index} className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}><div className={`max-w-[86%] whitespace-pre-wrap rounded-2xl px-4 py-3 text-[15px] leading-6 ${message.role === "user" ? "rounded-br-md bg-[#b9ff66] text-[#10130d]" : "rounded-bl-md border border-white/10 bg-white/[.045] text-white/78"}`}>{message.content}</div></div>)}
                {replying && <div className="flex justify-start"><div className="flex items-center gap-2 rounded-2xl rounded-bl-md border border-white/10 bg-white/[.045] px-4 py-3 text-sm text-white/42"><LoaderCircle className="animate-spin" size={15} /> 人格正在组织回应</div></div>}
                <div ref={chatEndRef} />
              </div>
              <form onSubmit={sendMessage} className="border-t border-white/10 p-4 sm:p-5"><div className="flex gap-2 rounded-2xl border border-white/12 bg-white/[.035] p-2 focus-within:border-[#b9ff66]/60"><Input value={chatInput} onChange={(event) => setChatInput(event.target.value)} className="h-12 border-0 bg-transparent px-3 text-base shadow-none focus-visible:ring-0" placeholder={`问 ${selectedSoul.name} 一个问题…`} /><button type="submit" disabled={!chatInput.trim() || replying} aria-label="发送消息" className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-[#b9ff66] text-[#10130d] transition hover:bg-[#caff8c] disabled:opacity-30"><Send size={18} /></button></div><div className="mt-2 flex items-center justify-between px-1 text-xs text-white/28"><span className="flex items-center gap-1.5"><Flame size={13} /> 本次召唤将计入成长</span><span>Shift + Enter 换行</span></div></form>
            </section>
          </div>}
        </DialogContent>
      </Dialog>

      <footer className="mt-16 border-t border-white/10"><div className="mx-auto flex max-w-[1480px] flex-col justify-between gap-3 px-5 py-7 text-xs text-white/32 sm:flex-row md:px-10"><span>SOULMINT · LIVING IDENTITIES ON AVALANCHE</span><a href="https://subnets-test.avax.network/c-chain" target="_blank" rel="noreferrer" className="flex items-center gap-1.5 hover:text-white">Fuji Explorer <ExternalLink size={13} /></a></div></footer>
    </main>
  );
}
