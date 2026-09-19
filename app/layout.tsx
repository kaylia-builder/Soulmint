import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Soulmint · MBTI AI 分身 NFT",
  description: "在 Avalanche 上铸造会对话、会成长的 MBTI AI 人格 NFT。",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body className="antialiased">{children}</body>
    </html>
  );
}
